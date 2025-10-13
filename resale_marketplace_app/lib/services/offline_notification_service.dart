import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'notification_queue_service.dart';

/// 📱 오프라인 알림 큐잉 서비스
/// 네트워크 연결이 없을 때 알림을 로컬에 저장하고, 연결 복구 시 전송
class OfflineNotificationService {
  static final OfflineNotificationService _instance = 
      OfflineNotificationService._internal();
  factory OfflineNotificationService() => _instance;
  OfflineNotificationService._internal();

  static const String _queueKey = 'offline_notification_queue';
  static const String _lastSyncKey = 'last_notification_sync';
  static const int _maxQueueSize = 100; // 최대 큐 사이즈

  final NotificationQueueService _queueService = NotificationQueueService();
  bool _isProcessing = false;

  /// 🔄 오프라인 알림 큐에 추가
  Future<bool> queueOfflineNotification({
    required String notificationType,
    required String title,
    required String body,
    required List<String> targetUserIds,
    Map<String, dynamic>? data,
    DateTime? scheduledAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey) ?? '[]';
      final queue = List<Map<String, dynamic>>.from(
        json.decode(queueJson)
      );

      // 큐 사이즈 제한
      if (queue.length >= _maxQueueSize) {
        // 오래된 항목부터 제거
        queue.removeRange(0, queue.length - _maxQueueSize + 1);
      }

      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'notification_type': notificationType,
        'title': title,
        'body': body,
        'target_user_ids': targetUserIds,
        'data': data ?? {},
        'scheduled_at': (scheduledAt ?? DateTime.now()).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      };

      queue.add(notification);
      await prefs.setString(_queueKey, json.encode(queue));

      developer.log('오프라인 알림 큐에 추가: ${notification['id']}');
      return true;
    } catch (e) {
      developer.log('오프라인 알림 큐 추가 실패: $e');
      return false;
    }
  }

  /// 📤 오프라인 큐 동기화
  Future<void> syncOfflineQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // 네트워크 연결 확인
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        developer.log('네트워크 연결 없음 - 동기화 스킵');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey) ?? '[]';
      final queue = List<Map<String, dynamic>>.from(
        json.decode(queueJson)
      );

      if (queue.isEmpty) {
        developer.log('오프라인 큐가 비어있음');
        return;
      }

      developer.log('오프라인 큐 동기화 시작: ${queue.length}개 항목');

      final successfulIds = <String>[];
      final now = DateTime.now();

      for (final notification in queue) {
        try {
          final scheduledAt = DateTime.parse(notification['scheduled_at']);
          
          // 스케줄된 시간이 지난 경우만 전송
          if (scheduledAt.isAfter(now)) {
            continue;
          }

          // 온라인 큐에 추가
          final queueId = await _queueService.enqueueNotification(
            notificationType: notification['notification_type'],
            title: notification['title'],
            body: notification['body'],
            targetUserIds: List<String>.from(notification['target_user_ids']),
            data: notification['data'],
            scheduledAt: scheduledAt,
          );

          if (queueId != null) {
            successfulIds.add(notification['id']);
            developer.log('오프라인 알림 동기화 성공: ${notification['id']}');
          } else {
            // 재시도 카운트 증가
            notification['retry_count'] = (notification['retry_count'] ?? 0) + 1;
            
            // 최대 재시도 횟수 초과 시 제거
            if (notification['retry_count'] >= 3) {
              successfulIds.add(notification['id']);
              developer.log('최대 재시도 초과로 제거: ${notification['id']}');
            }
          }
        } catch (e) {
          developer.log('알림 동기화 실패 (${notification['id']}): $e');
          
          // 재시도 카운트 증가
          notification['retry_count'] = (notification['retry_count'] ?? 0) + 1;
          if (notification['retry_count'] >= 3) {
            successfulIds.add(notification['id']);
          }
        }
      }

      // 성공한 항목들 큐에서 제거
      if (successfulIds.isNotEmpty) {
        final remainingQueue = queue.where(
          (notification) => !successfulIds.contains(notification['id'])
        ).toList();

        await prefs.setString(_queueKey, json.encode(remainingQueue));
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        
        developer.log('오프라인 큐 동기화 완료: ${successfulIds.length}개 처리됨');
      }
    } catch (e) {
      developer.log('오프라인 큐 동기화 오류: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// 📊 오프라인 큐 상태 조회
  Future<Map<String, dynamic>> getQueueStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey) ?? '[]';
      final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
      final lastSync = prefs.getString(_lastSyncKey);

      return {
        'queue_size': queue.length,
        'max_queue_size': _maxQueueSize,
        'last_sync': lastSync,
        'is_processing': _isProcessing,
        'oldest_notification': queue.isNotEmpty 
            ? queue.first['created_at'] 
            : null,
      };
    } catch (e) {
      developer.log('오프라인 큐 상태 조회 실패: $e');
      return {
        'queue_size': 0,
        'error': e.toString(),
      };
    }
  }

  /// 🧹 오프라인 큐 정리
  Future<void> clearOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_lastSyncKey);
      developer.log('오프라인 큐 정리 완료');
    } catch (e) {
      developer.log('오프라인 큐 정리 실패: $e');
    }
  }

  /// 🔄 네트워크 상태 모니터링
  void startNetworkMonitoring() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        developer.log('네트워크 연결 복구됨 - 오프라인 큐 동기화 시작');
        syncOfflineQueue();
      }
    });
  }

  /// ⚡ 스마트 알림 전송 (온라인/오프라인 자동 판단)
  Future<bool> sendSmartNotification({
    required String notificationType,
    required String title,
    required String body,
    required List<String> targetUserIds,
    Map<String, dynamic>? data,
    DateTime? scheduledAt,
    bool forceOffline = false,
  }) async {
    try {
      // 강제 오프라인 모드이거나 네트워크 연결이 없는 경우
      if (forceOffline) {
        return await queueOfflineNotification(
          notificationType: notificationType,
          title: title,
          body: body,
          targetUserIds: targetUserIds,
          data: data,
          scheduledAt: scheduledAt,
        );
      }

      // 네트워크 연결 확인
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        return await queueOfflineNotification(
          notificationType: notificationType,
          title: title,
          body: body,
          targetUserIds: targetUserIds,
          data: data,
          scheduledAt: scheduledAt,
        );
      }

      // 온라인 상태에서 즉시 전송
      if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
        return await _queueService.sendImmediateNotification(
          notificationType: notificationType,
          title: title,
          body: body,
          targetUserIds: targetUserIds,
          data: data,
        );
      } else {
        // 스케줄된 알림은 온라인 큐에 추가
        final queueId = await _queueService.enqueueNotification(
          notificationType: notificationType,
          title: title,
          body: body,
          targetUserIds: targetUserIds,
          data: data,
          scheduledAt: scheduledAt,
        );
        return queueId != null;
      }
    } catch (e) {
      developer.log('스마트 알림 전송 실패: $e');
      return false;
    }
  }
}