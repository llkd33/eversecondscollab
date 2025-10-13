import 'dart:convert';
import 'dart:developer' as developer;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// 🚫 알림 중복 방지 및 그룹화 서비스
/// 같은 타입의 반복적인 알림을 방지하고 관련 알림들을 그룹화
class NotificationDeduplicationService {
  static final NotificationDeduplicationService _instance = 
      NotificationDeduplicationService._internal();
  factory NotificationDeduplicationService() => _instance;
  NotificationDeduplicationService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  static const String _localCacheKey = 'notification_dedup_cache';
  static const Duration _deduplicationWindow = Duration(minutes: 15);
  static const Duration _groupingWindow = Duration(hours: 1);

  /// 🔍 중복 알림 확인 및 처리
  Future<NotificationAction> checkDuplication({
    required String userId,
    required String notificationType,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? relatedEntityId,
  }) async {
    try {
      // 고유 해시 생성
      final notificationHash = _generateNotificationHash(
        userId: userId,
        notificationType: notificationType,
        title: title,
        body: body,
        relatedEntityId: relatedEntityId,
      );

      // 로컬 캐시 확인
      final localResult = await _checkLocalCache(notificationHash);
      if (localResult != NotificationAction.send) {
        return localResult;
      }

      // 서버 중복 확인
      final serverResult = await _checkServerDuplication(
        userId: userId,
        notificationType: notificationType,
        notificationHash: notificationHash,
        relatedEntityId: relatedEntityId,
      );

      // 로컬 캐시 업데이트
      await _updateLocalCache(notificationHash);

      return serverResult;
    } catch (e) {
      developer.log('중복 확인 실패: $e');
      return NotificationAction.send; // 에러 시 기본적으로 전송
    }
  }

  /// 🎯 그룹화 가능한 알림 확인
  Future<GroupingResult> checkGrouping({
    required String userId,
    required String notificationType,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    try {
      final now = DateTime.now();
      final windowStart = now.subtract(_groupingWindow);

      // 그룹화 가능한 최근 알림 조회
      var query = _supabase
          .from('notification_history')
          .select('*')
          .eq('user_id', userId)
          .eq('notification_type', notificationType)
          .gte('sent_at', windowStart.toIso8601String())
          .eq('status', 'sent')
          .order('sent_at', ascending: false);

      // 관련 엔티티가 있는 경우 필터링
      if (relatedEntityType != null && relatedEntityId != null) {
        query = query
            .eq('related_entity_type', relatedEntityType)
            .eq('related_entity_id', relatedEntityId);
      }

      final recentNotifications = await query.limit(10);

      if (recentNotifications.isEmpty) {
        return GroupingResult(
          action: GroupingAction.sendNew,
          existingNotificationId: null,
          groupCount: 0,
        );
      }

      // 그룹화 로직 적용
      return _determineGroupingAction(recentNotifications, notificationType);
    } catch (e) {
      developer.log('그룹화 확인 실패: $e');
      return GroupingResult(
        action: GroupingAction.sendNew,
        existingNotificationId: null,
        groupCount: 0,
      );
    }
  }

  /// 📱 그룹화된 알림 업데이트
  Future<bool> updateGroupedNotification({
    required String notificationId,
    required String newTitle,
    required String newBody,
    required int groupCount,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = {
        'title': newTitle,
        'body': newBody,
        'data': {
          'group_count': groupCount,
          'last_updated': DateTime.now().toIso8601String(),
          if (additionalData != null) ...additionalData,
        },
        'sent_at': DateTime.now().toIso8601String(), // 최신 시간으로 업데이트
      };

      await _supabase
          .from('notification_history')
          .update(updateData)
          .eq('id', notificationId);

      developer.log('그룹화된 알림 업데이트 완료: $notificationId (그룹 수: $groupCount)');
      return true;
    } catch (e) {
      developer.log('그룹화된 알림 업데이트 실패: $e');
      return false;
    }
  }

  /// 🔐 알림 해시 생성
  String _generateNotificationHash({
    required String userId,
    required String notificationType,
    required String title,
    required String body,
    String? relatedEntityId,
  }) {
    final content = [
      userId,
      notificationType,
      title.toLowerCase().trim(),
      body.toLowerCase().trim(),
      relatedEntityId ?? '',
    ].join('|');

    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 💾 로컬 캐시 확인
  Future<NotificationAction> _checkLocalCache(String hash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_localCacheKey) ?? '{}';
      final cache = Map<String, dynamic>.from(json.decode(cacheJson));

      final cachedTime = cache[hash];
      if (cachedTime != null) {
        final timestamp = DateTime.parse(cachedTime);
        final now = DateTime.now();
        
        if (now.difference(timestamp) < _deduplicationWindow) {
          developer.log('로컬 캐시에서 중복 발견: $hash');
          return NotificationAction.skip;
        }
      }

      return NotificationAction.send;
    } catch (e) {
      developer.log('로컬 캐시 확인 실패: $e');
      return NotificationAction.send;
    }
  }

  /// 🗄️ 서버 중복 확인
  Future<NotificationAction> _checkServerDuplication({
    required String userId,
    required String notificationType,
    required String notificationHash,
    String? relatedEntityId,
  }) async {
    try {
      final windowStart = DateTime.now().subtract(_deduplicationWindow);

      // 같은 해시의 최근 알림 조회
      final duplicates = await _supabase
          .from('notification_history')
          .select('id, sent_at')
          .eq('user_id', userId)
          .eq('notification_type', notificationType)
          .gte('sent_at', windowStart.toIso8601String())
          .like('data', '%"hash":"$notificationHash"%')
          .limit(1);

      if (duplicates.isNotEmpty) {
        developer.log('서버에서 중복 발견: $notificationHash');
        return NotificationAction.skip;
      }

      // 관련 엔티티 기반 중복 확인 (채팅방 메시지 등)
      if (relatedEntityId != null && notificationType == 'chat_message') {
        final recentSimilar = await _supabase
            .from('notification_history')
            .select('id')
            .eq('user_id', userId)
            .eq('notification_type', notificationType)
            .eq('related_entity_id', relatedEntityId)
            .gte('sent_at', windowStart.toIso8601String())
            .limit(3);

        if (recentSimilar.length >= 3) {
          developer.log('관련 엔티티 기반 중복 방지: $relatedEntityId');
          return NotificationAction.group;
        }
      }

      return NotificationAction.send;
    } catch (e) {
      developer.log('서버 중복 확인 실패: $e');
      return NotificationAction.send;
    }
  }

  /// 💾 로컬 캐시 업데이트
  Future<void> _updateLocalCache(String hash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_localCacheKey) ?? '{}';
      final cache = Map<String, dynamic>.from(json.decode(cacheJson));

      // 캐시 정리 (오래된 항목 제거)
      final now = DateTime.now();
      cache.removeWhere((key, value) {
        if (value is String) {
          final timestamp = DateTime.tryParse(value);
          if (timestamp != null) {
            return now.difference(timestamp) > _deduplicationWindow;
          }
        }
        return true;
      });

      // 새 항목 추가
      cache[hash] = now.toIso8601String();

      await prefs.setString(_localCacheKey, json.encode(cache));
    } catch (e) {
      developer.log('로컬 캐시 업데이트 실패: $e');
    }
  }

  /// 🎯 그룹화 액션 결정
  GroupingResult _determineGroupingAction(
    List<dynamic> recentNotifications, 
    String notificationType
  ) {
    if (recentNotifications.isEmpty) {
      return GroupingResult(
        action: GroupingAction.sendNew,
        existingNotificationId: null,
        groupCount: 0,
      );
    }

    // 알림 타입별 그룹화 정책
    switch (notificationType) {
      case 'chat_message':
        // 채팅 메시지: 3개 이상 시 그룹화
        if (recentNotifications.length >= 3) {
          return GroupingResult(
            action: GroupingAction.updateExisting,
            existingNotificationId: recentNotifications.first['id'],
            groupCount: recentNotifications.length + 1,
          );
        }
        break;

      case 'transaction':
        // 거래 알림: 같은 거래의 반복 알림 방지
        return GroupingResult(
          action: GroupingAction.skip,
          existingNotificationId: recentNotifications.first['id'],
          groupCount: recentNotifications.length,
        );

      case 'promotion':
        // 프로모션 알림: 1시간 내 1개만
        return GroupingResult(
          action: GroupingAction.skip,
          existingNotificationId: recentNotifications.first['id'],
          groupCount: recentNotifications.length,
        );

      default:
        // 기타: 기본적으로 새로 전송
        break;
    }

    return GroupingResult(
      action: GroupingAction.sendNew,
      existingNotificationId: null,
      groupCount: 0,
    );
  }

  /// 🧹 오래된 중복 방지 데이터 정리
  Future<void> cleanupOldData() async {
    try {
      // 로컬 캐시 정리
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCacheKey);

      developer.log('중복 방지 데이터 정리 완료');
    } catch (e) {
      developer.log('데이터 정리 실패: $e');
    }
  }

  /// 📊 중복 방지 통계 조회
  Future<Map<String, dynamic>> getDeduplicationStats(String userId) async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      
      // 전체 알림 수
      final totalCount = await _supabase
          .from('notification_history')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('user_id', userId)
          .gte('sent_at', oneDayAgo.toIso8601String());

      // 그룹화된 알림 수
      final groupedCount = await _supabase
          .from('notification_history')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('user_id', userId)
          .gte('sent_at', oneDayAgo.toIso8601String())
          .not('data', 'cs', '{"group_count":null}');

      return {
        'user_id': userId,
        'period_hours': 24,
        'total_notifications': totalCount.count ?? 0,
        'grouped_notifications': groupedCount.count ?? 0,
        'reduction_rate': totalCount.count != null && totalCount.count! > 0 
            ? ((groupedCount.count ?? 0) / totalCount.count! * 100) 
            : 0.0,
      };
    } catch (e) {
      developer.log('중복 방지 통계 조회 실패: $e');
      return {
        'error': e.toString(),
        'user_id': userId,
      };
    }
  }
}

/// 알림 액션 유형
enum NotificationAction {
  send,    // 정상 전송
  skip,    // 중복으로 인한 스킵
  group,   // 그룹화 필요
}

/// 그룹화 액션 유형
enum GroupingAction {
  sendNew,         // 새 알림으로 전송
  updateExisting,  // 기존 알림 업데이트
  skip,           // 전송 스킵
}

/// 그룹화 결과
class GroupingResult {
  final GroupingAction action;
  final String? existingNotificationId;
  final int groupCount;

  GroupingResult({
    required this.action,
    required this.existingNotificationId,
    required this.groupCount,
  });
}