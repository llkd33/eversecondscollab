import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'push_notification_service.dart';

enum RealtimeNotificationEventType {
  newNotification,
  notificationRead,
  notificationDeleted,
  badgeCountUpdated,
}

class RealtimeNotificationEvent {
  final RealtimeNotificationEventType type;
  final NotificationPayload? notification;
  final String? notificationId;
  final int? badgeCount;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  RealtimeNotificationEvent({
    required this.type,
    this.notification,
    this.notificationId,
    this.badgeCount,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 실시간 알림 서비스
class RealtimeNotificationService {
  static final RealtimeNotificationService _instance = RealtimeNotificationService._internal();
  factory RealtimeNotificationService() => _instance;
  RealtimeNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final PushNotificationService _pushService = PushNotificationService();
  
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _userChannel;
  
  final StreamController<RealtimeNotificationEvent> _eventController =
      StreamController<RealtimeNotificationEvent>.broadcast();
  
  Stream<RealtimeNotificationEvent> get eventStream => _eventController.stream;
  
  bool _isInitialized = false;
  String? _currentUserId;
  int _currentBadgeCount = 0;

  /// 실시간 알림 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      developer.log('Initializing realtime notification service');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      _currentUserId = user.id;
      
      await _setupNotificationChannel();
      await _setupUserSpecificChannel();
      await _loadInitialBadgeCount();
      
      _isInitialized = true;
      developer.log('Realtime notification service initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize realtime notification service: $e');
      rethrow;
    }
  }

  /// 알림 테이블 변경 채널 설정
  Future<void> _setupNotificationChannel() async {
    _notificationChannel = _supabase.channel('notifications')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: _currentUserId,
        ),
        callback: _handleNotificationChange,
      )
      ..subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          developer.log('Subscribed to notification changes');
        } else if (error != null) {
          developer.log('Notification subscription error: $error');
        }
      });
  }

  /// 사용자별 실시간 채널 설정 (즉시 알림용)
  Future<void> _setupUserSpecificChannel() async {
    if (_currentUserId == null) return;
    
    _userChannel = _supabase.channel('user_notifications_$_currentUserId')
      ..onBroadcast(
        event: 'notification',
        callback: _handleBroadcastNotification,
      )
      ..onBroadcast(
        event: 'badge_update',
        callback: _handleBadgeUpdate,
      )
      ..subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          developer.log('Subscribed to user-specific notifications');
        } else if (error != null) {
          developer.log('User notification subscription error: $error');
        }
      });
  }

  /// 알림 테이블 변경 처리
  void _handleNotificationChange(PostgresChangePayload payload) {
    try {
      final eventType = payload.eventType;
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;
      
      developer.log('Notification change event: $eventType');
      
      switch (eventType) {
        case PostgresChangeEvent.insert:
          if (newRecord != null) {
            _handleNotificationInsert(newRecord);
          }
          break;
        case PostgresChangeEvent.update:
          if (newRecord != null && oldRecord != null) {
            _handleNotificationUpdate(newRecord, oldRecord);
          }
          break;
        case PostgresChangeEvent.delete:
          if (oldRecord != null) {
            _handleNotificationDelete(oldRecord);
          }
          break;
        case PostgresChangeEvent.all:
          break;
      }
    } catch (e) {
      developer.log('Error handling notification change: $e');
    }
  }

  /// 새 알림 처리
  void _handleNotificationInsert(Map<String, dynamic> record) {
    try {
      final notification = _createNotificationPayload(record);
      
      _eventController.add(RealtimeNotificationEvent(
        type: RealtimeNotificationEventType.newNotification,
        notification: notification,
        notificationId: record['id'] as String?,
      ));
      
      // 배지 카운트 증가
      _currentBadgeCount++;
      _updateBadgeCount();
      
      developer.log('New notification received: ${notification.title}');
    } catch (e) {
      developer.log('Error processing notification insert: $e');
    }
  }

  /// 알림 업데이트 처리 (읽음 상태 변경 등)
  void _handleNotificationUpdate(Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord) {
    try {
      final wasRead = oldRecord['is_read'] as bool? ?? false;
      final isRead = newRecord['is_read'] as bool? ?? false;
      
      if (!wasRead && isRead) {
        // 알림이 읽음으로 변경됨
        _eventController.add(RealtimeNotificationEvent(
          type: RealtimeNotificationEventType.notificationRead,
          notificationId: newRecord['id'] as String?,
        ));
        
        // 배지 카운트 감소
        if (_currentBadgeCount > 0) {
          _currentBadgeCount--;
          _updateBadgeCount();
        }
      }
    } catch (e) {
      developer.log('Error processing notification update: $e');
    }
  }

  /// 알림 삭제 처리
  void _handleNotificationDelete(Map<String, dynamic> record) {
    try {
      final wasRead = record['is_read'] as bool? ?? false;
      
      _eventController.add(RealtimeNotificationEvent(
        type: RealtimeNotificationEventType.notificationDeleted,
        notificationId: record['id'] as String?,
      ));
      
      // 읽지 않은 알림이 삭제된 경우 배지 카운트 감소
      if (!wasRead && _currentBadgeCount > 0) {
        _currentBadgeCount--;
        _updateBadgeCount();
      }
    } catch (e) {
      developer.log('Error processing notification delete: $e');
    }
  }

  /// 브로드캐스트 알림 처리 (즉시 알림)
  void _handleBroadcastNotification(Map<String, dynamic> payload) {
    try {
      final notification = NotificationPayload.fromJson(payload);
      
      _eventController.add(RealtimeNotificationEvent(
        type: RealtimeNotificationEventType.newNotification,
        notification: notification,
      ));
      
      // 즉시 로컬 알림 표시
      _pushService.showLocalNotification(
        title: notification.title,
        body: notification.body,
        data: notification.data,
      );
      
      developer.log('Broadcast notification received: ${notification.title}');
    } catch (e) {
      developer.log('Error processing broadcast notification: $e');
    }
  }

  /// 배지 업데이트 처리
  void _handleBadgeUpdate(Map<String, dynamic> payload) {
    try {
      final badgeCount = payload['badge_count'] as int? ?? 0;
      
      _currentBadgeCount = badgeCount;
      
      _eventController.add(RealtimeNotificationEvent(
        type: RealtimeNotificationEventType.badgeCountUpdated,
        badgeCount: badgeCount,
      ));
      
      _updateBadgeCount();
    } catch (e) {
      developer.log('Error processing badge update: $e');
    }
  }

  /// NotificationPayload 생성
  NotificationPayload _createNotificationPayload(Map<String, dynamic> record) {
    return NotificationPayload(
      id: record['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _parseNotificationType(record['type'] as String?),
      title: record['title'] as String? ?? '',
      body: record['body'] as String? ?? '',
      data: (record['data'] as Map<String, dynamic>?) ?? {},
      timestamp: record['created_at'] != null 
          ? DateTime.parse(record['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// 알림 타입 파싱
  NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'chat_message':
        return NotificationType.chatMessage;
      case 'transaction':
        return NotificationType.transaction;
      case 'review':
        return NotificationType.review;
      case 'system':
        return NotificationType.system;
      case 'promotion':
        return NotificationType.promotion;
      default:
        return NotificationType.system;
    }
  }

  /// 초기 배지 카운트 로드
  Future<void> _loadInitialBadgeCount() async {
    try {
      final result = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('is_read', false);
      
      _currentBadgeCount = (result as List).length;
      _updateBadgeCount();
    } catch (e) {
      developer.log('Failed to load initial badge count: $e');
    }
  }

  /// 배지 카운트 업데이트
  void _updateBadgeCount() {
    _pushService.updateBadgeCount(_currentBadgeCount);
    
    _eventController.add(RealtimeNotificationEvent(
      type: RealtimeNotificationEventType.badgeCountUpdated,
      badgeCount: _currentBadgeCount,
    ));
  }

  /// 즉시 알림 전송 (다른 사용자에게)
  Future<void> sendInstantNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 데이터베이스에 알림 저장
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type.name,
        'data': data ?? {},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // 실시간 브로드캐스트 (간단한 방식으로 변경)
      final channel = _supabase.channel('user_notifications_$userId');
      await channel.sendBroadcastMessage(
        event: 'notification',
        payload: {
          'title': title,
          'body': body,
          'type': type.name,
          'data': data ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      developer.log('Instant notification sent to user: $userId');
    } catch (e) {
      developer.log('Failed to send instant notification: $e');
      rethrow;
    }
  }

  /// 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      
      developer.log('Notification marked as read: $notificationId');
    } catch (e) {
      developer.log('Failed to mark notification as read: $e');
      rethrow;
    }
  }

  /// 모든 알림 읽음 처리
  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _currentUserId!)
          .eq('is_read', false);
      
      _currentBadgeCount = 0;
      _updateBadgeCount();
      
      developer.log('All notifications marked as read');
    } catch (e) {
      developer.log('Failed to mark all notifications as read: $e');
      rethrow;
    }
  }

  /// 배지 카운트 조회
  int get badgeCount => _currentBadgeCount;

  /// 연결 상태 확인
  bool get isConnected => 
      _notificationChannel != null &&
      _userChannel != null;

  /// 재연결
  Future<void> reconnect() async {
    try {
      developer.log('Reconnecting realtime notification service');
      
      await _notificationChannel?.unsubscribe();
      await _userChannel?.unsubscribe();
      
      await _setupNotificationChannel();
      await _setupUserSpecificChannel();
      
      developer.log('Realtime notification service reconnected');
    } catch (e) {
      developer.log('Failed to reconnect realtime notification service: $e');
    }
  }

  /// 서비스 종료
  void dispose() {
    _notificationChannel?.unsubscribe();
    _userChannel?.unsubscribe();
    _eventController.close();
    _isInitialized = false;
    
    developer.log('Realtime notification service disposed');
  }
}