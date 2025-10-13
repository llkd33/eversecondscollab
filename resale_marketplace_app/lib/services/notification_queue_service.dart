import 'dart:convert';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'notification_preferences_service.dart';
import 'push_notification_service.dart';

/// 🚀 알림 큐잉 및 배치 처리 서비스
/// 대량 알림, 지연 알림, 스케줄링된 알림을 효율적으로 처리
class NotificationQueueService {
  static final NotificationQueueService _instance = 
      NotificationQueueService._internal();
  factory NotificationQueueService() => _instance;
  NotificationQueueService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final NotificationPreferencesService _preferencesService = 
      NotificationPreferencesService();
  final PushNotificationService _pushService = PushNotificationService();

  /// 📝 알림을 큐에 추가 (즉시 또는 스케줄)
  Future<String?> enqueueNotification({
    required String notificationType,
    required String title,
    required String body,
    required List<String> targetUserIds,
    Map<String, dynamic>? data,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    Map<String, dynamic>? targetCriteria,
  }) async {
    try {
      final response = await _supabase.from('notification_queue').insert({
        'notification_type': notificationType,
        'title': title,
        'body': body,
        'data': data ?? {},
        'target_user_ids': targetUserIds,
        'target_criteria': targetCriteria,
        'scheduled_at': (scheduledAt ?? DateTime.now()).toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'status': 'pending',
      }).select('id').single();

      final queueId = response['id'] as String;
      developer.log('알림 큐 추가 성공: $queueId');

      // 즉시 전송인 경우 바로 처리
      if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
        await _processQueueItem(queueId);
      }

      return queueId;
    } catch (e) {
      developer.log('알림 큐 추가 실패: $e');
      return null;
    }
  }

  /// ⚡ 즉시 알림 전송 (큐 없이)
  Future<bool> sendImmediateNotification({
    required String notificationType,
    required String title,
    required String body,
    required List<String> targetUserIds,
    Map<String, dynamic>? data,
  }) async {
    try {
      int successCount = 0;
      int failureCount = 0;

      for (final userId in targetUserIds) {
        // 알림 허용 여부 확인
        final shouldSend = await _preferencesService.shouldSendNotification(
          userId, 
          '${notificationType}_notifications'
        );

        if (!shouldSend) {
          developer.log('알림 스킵 (사용자 설정): $userId');
          continue;
        }

        // FCM 토큰 가져오기
        final tokens = await _getActiveUserTokens(userId);
        if (tokens.isEmpty) {
          developer.log('FCM 토큰 없음: $userId');
          failureCount++;
          continue;
        }

        // 각 토큰으로 알림 전송
        bool userNotified = false;
        for (final token in tokens) {
          try {
            await _sendFCMNotification(
              token: token,
              title: title,
              body: body,
              data: data ?? {},
            );
            userNotified = true;
            break; // 하나의 토큰으로 성공하면 충분
          } catch (e) {
            developer.log('FCM 전송 실패 (토큰: $token): $e');
          }
        }

        if (userNotified) {
          successCount++;
          // 알림 히스토리 저장
          await _saveNotificationHistory(
            userId: userId,
            notificationType: notificationType,
            title: title,
            body: body,
            data: data,
          );
        } else {
          failureCount++;
        }
      }

      developer.log('즉시 알림 전송 완료: 성공 $successCount, 실패 $failureCount');
      return successCount > 0;
    } catch (e) {
      developer.log('즉시 알림 전송 오류: $e');
      return false;
    }
  }

  /// 🔄 대기 중인 알림 큐 처리
  Future<void> processScheduledNotifications() async {
    try {
      final now = DateTime.now();
      
      // 처리할 대기 중인 알림들 조회
      final pendingItems = await _supabase
          .from('notification_queue')
          .select('*')
          .eq('status', 'pending')
          .lte('scheduled_at', now.toIso8601String())
          .or('expires_at.is.null,expires_at.gte.${now.toIso8601String()}')
          .order('scheduled_at');

      developer.log('처리할 대기 알림: ${pendingItems.length}개');

      for (final item in pendingItems) {
        await _processQueueItem(item['id']);
      }
    } catch (e) {
      developer.log('스케줄된 알림 처리 오류: $e');
    }
  }

  /// 📋 큐 아이템 개별 처리
  Future<void> _processQueueItem(String queueId) async {
    try {
      // 큐 아이템 조회
      final queueItem = await _supabase
          .from('notification_queue')
          .select('*')
          .eq('id', queueId)
          .single();

      // 상태를 처리 중으로 변경
      await _supabase
          .from('notification_queue')
          .update({'status': 'processing', 'processed_at': DateTime.now().toIso8601String()})
          .eq('id', queueId);

      final targetUserIds = List<String>.from(queueItem['target_user_ids'] ?? []);
      final targetCriteria = queueItem['target_criteria'] as Map<String, dynamic>?;

      // 동적 수신자 선택이 있는 경우 처리
      if (targetCriteria != null) {
        final dynamicUsers = await _selectUsersByCriteria(targetCriteria);
        targetUserIds.addAll(dynamicUsers);
      }

      // 중복 제거
      final uniqueUserIds = targetUserIds.toSet().toList();

      // 알림 전송
      final success = await sendImmediateNotification(
        notificationType: queueItem['notification_type'],
        title: queueItem['title'],
        body: queueItem['body'],
        targetUserIds: uniqueUserIds,
        data: queueItem['data'],
      );

      // 큐 상태 업데이트
      await _supabase
          .from('notification_queue')
          .update({
            'status': success ? 'completed' : 'failed',
            'sent_count': uniqueUserIds.length,
          })
          .eq('id', queueId);

    } catch (e) {
      developer.log('큐 아이템 처리 실패 ($queueId): $e');
      
      // 실패 상태로 업데이트
      await _supabase
          .from('notification_queue')
          .update({
            'status': 'failed',
            'error_message': e.toString(),
          })
          .eq('id', queueId);
    }
  }

  /// 🎯 조건에 따른 사용자 선택
  Future<List<String>> _selectUsersByCriteria(Map<String, dynamic> criteria) async {
    try {
      var query = _supabase.from('users').select('id');

      // 역할 기반 선택
      if (criteria['roles'] != null) {
        final roles = List<String>.from(criteria['roles']);
        query = query.in_('role', roles);
      }

      // 지역 기반 선택
      if (criteria['regions'] != null) {
        final regions = List<String>.from(criteria['regions']);
        query = query.in_('region', regions);
      }

      // 활성 사용자만
      if (criteria['active_only'] == true) {
        final daysAgo = DateTime.now().subtract(const Duration(days: 30));
        query = query.gte('last_active_at', daysAgo.toIso8601String());
      }

      final results = await query;
      return results.map((user) => user['id'] as String).toList();
    } catch (e) {
      developer.log('사용자 선택 오류: $e');
      return [];
    }
  }

  /// 📱 FCM 알림 전송
  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // TODO: 실제 FCM HTTP API 호출 또는 Supabase Edge Function 호출
    // 현재는 로컬 알림으로 시뮬레이션
    developer.log('FCM 전송: $title -> $token');
  }

  /// 📊 활성 사용자 토큰 조회
  Future<List<String>> _getActiveUserTokens(String userId) async {
    try {
      final response = await _supabase
          .from('user_fcm_tokens')
          .select('fcm_token')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_used_at', ascending: false);

      return response.map((token) => token['fcm_token'] as String).toList();
    } catch (e) {
      developer.log('사용자 토큰 조회 실패: $e');
      return [];
    }
  }

  /// 📝 알림 히스토리 저장
  Future<void> _saveNotificationHistory({
    required String userId,
    required String notificationType,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    try {
      await _supabase.from('notification_history').insert({
        'user_id': userId,
        'notification_type': notificationType,
        'title': title,
        'body': body,
        'data': data ?? {},
        'related_entity_type': relatedEntityType,
        'related_entity_id': relatedEntityId,
        'status': 'sent',
      });
    } catch (e) {
      developer.log('알림 히스토리 저장 실패: $e');
    }
  }

  /// 🧹 오래된 큐 데이터 정리
  Future<void> cleanupExpiredNotifications() async {
    try {
      final now = DateTime.now();
      
      // 만료된 알림 삭제
      await _supabase
          .from('notification_queue')
          .delete()
          .lt('expires_at', now.toIso8601String());

      // 30일 이상 된 완료/실패 큐 삭제
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      await _supabase
          .from('notification_queue')
          .delete()
          .in_('status', ['completed', 'failed'])
          .lt('created_at', thirtyDaysAgo.toIso8601String());

      developer.log('만료된 알림 큐 정리 완료');
    } catch (e) {
      developer.log('알림 큐 정리 실패: $e');
    }
  }

  /// 📈 알림 성능 메트릭 수집
  Future<void> collectMetrics() async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 타입별 알림 통계 수집
      final types = ['chat_message', 'transaction', 'resale', 'system', 'promotion'];

      for (final type in types) {
        final stats = await _supabase
            .from('notification_history')
            .select('status')
            .eq('notification_type', type)
            .gte('sent_at', '${todayStr}T00:00:00Z')
            .lt('sent_at', '${todayStr}T23:59:59Z');

        final metrics = {
          'total_sent': stats.length,
          'total_delivered': stats.where((s) => s['status'] == 'delivered').length,
          'total_read': stats.where((s) => s['status'] == 'read').length,
          'total_failed': stats.where((s) => s['status'] == 'failed').length,
        };

        await _supabase.from('notification_metrics').upsert({
          'metric_date': todayStr,
          'notification_type': type,
          ...metrics,
        });
      }

      developer.log('알림 메트릭 수집 완료');
    } catch (e) {
      developer.log('알림 메트릭 수집 실패: $e');
    }
  }
}

/// 🎨 알림 템플릿 서비스
class NotificationTemplateService {
  static final NotificationTemplateService _instance = 
      NotificationTemplateService._internal();
  factory NotificationTemplateService() => _instance;
  NotificationTemplateService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  /// 📋 템플릿으로 알림 내용 생성
  Future<Map<String, String>?> renderTemplate(
    String templateName, 
    Map<String, dynamic> variables
  ) async {
    try {
      final template = await _supabase
          .from('notification_templates')
          .select('*')
          .eq('name', templateName)
          .eq('is_active', true)
          .maybeSingle();

      if (template == null) return null;

      String title = template['title_template'];
      String body = template['body_template'];

      // 변수 치환
      variables.forEach((key, value) {
        title = title.replaceAll('{{$key}}', value.toString());
        body = body.replaceAll('{{$key}}', value.toString());
      });

      return {
        'title': title,
        'body': body,
        'type': template['notification_type'],
      };
    } catch (e) {
      developer.log('템플릿 렌더링 실패: $e');
      return null;
    }
  }
}