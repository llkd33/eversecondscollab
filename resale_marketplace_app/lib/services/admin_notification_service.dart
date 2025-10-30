import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Admin-specific notification service for system notifications
class AdminNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final AdminNotificationService _instance =
      AdminNotificationService._internal();

  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  RealtimeChannel? _notificationChannel;
  Function(Map<String, dynamic>)? _onNotificationReceived;

  /// Initialize realtime notification listener
  Future<void> initialize({
    required String userId,
    Function(Map<String, dynamic>)? onNotificationReceived,
  }) async {
    _onNotificationReceived = onNotificationReceived;

    // Subscribe to notifications for this user
    _notificationChannel = _supabase.channel('admin_notifications:$userId').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'system_notifications',
          callback: (payload) {
            final notification = payload.newRecord;
            final targetUsers = notification['target_users'] as List?;

            // Check if notification is for this user or all admins
            if (targetUsers == null || targetUsers.contains(userId)) {
              _handleNewNotification(notification);
            }
          },
        ).subscribe();
  }

  /// Handle new notification
  void _handleNewNotification(Map<String, dynamic> notification) {
    debugPrint('New admin notification received: ${notification['title']}');
    _onNotificationReceived?.call(notification);
  }

  /// Create notification
  Future<Map<String, dynamic>?> createNotification({
    required String notificationType,
    required String severity,
    required String title,
    required String message,
    List<String>? targetUsers,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
  }) async {
    try {
      final notificationData = {
        'notification_type': notificationType,
        'severity': severity,
        'title': title,
        'message': message,
        'target_users': targetUsers,
        'read_by': [],
        'action_url': actionUrl,
        'metadata': metadata,
        'expires_at': expiresAt?.toIso8601String(),
      };

      final response = await _supabase
          .from('system_notifications')
          .insert(notificationData)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error creating notification: $e');
      return null;
    }
  }

  /// Get notifications for user
  Future<List<Map<String, dynamic>>> getNotifications({
    required String userId,
    bool unreadOnly = false,
    String? severity,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('system_notifications').select();

      // Filter by target users (null means all admins)
      query = query.or('target_users.is.null,target_users.cs.{$userId}');

      if (unreadOnly) {
        query = query.not('read_by', 'cs', '{$userId}');
      }

      if (severity != null) {
        query = query.eq('severity', severity);
      }

      // Filter out expired notifications
      query = query.or(
          'expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}');

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead({
    required String notificationId,
    required String userId,
  }) async {
    try {
      // Get current notification
      final notification = await _supabase
          .from('system_notifications')
          .select('read_by')
          .eq('id', notificationId)
          .single();

      final List<String> readBy =
          List<String>.from(notification['read_by'] ?? []);

      if (!readBy.contains(userId)) {
        readBy.add(userId);

        await _supabase
            .from('system_notifications')
            .update({'read_by': readBy}).eq('id', notificationId);
      }

      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead({required String userId}) async {
    try {
      final notifications = await getNotifications(
        userId: userId,
        unreadOnly: true,
      );

      for (final notification in notifications) {
        await markAsRead(
          notificationId: notification['id'],
          userId: userId,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('system_notifications')
          .delete()
          .eq('id', notificationId);

      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  /// Get unread count
  Future<int> getUnreadCount({required String userId}) async {
    try {
      final response = await _supabase
          .from('system_notifications')
          .select('id', const FetchOptions(count: CountOption.exact))
          .or('target_users.is.null,target_users.cs.{$userId}')
          .not('read_by', 'cs', '{$userId}')
          .or(
              'expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
          .count();

      return response.count ?? 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Create system alert for critical events
  Future<void> createSystemAlert({
    required String title,
    required String message,
    String? actionUrl,
  }) async {
    await createNotification(
      notificationType: 'error',
      severity: 'critical',
      title: title,
      message: message,
      targetUsers: null, // All admins
      actionUrl: actionUrl,
    );
  }

  /// Create warning notification
  Future<void> createWarning({
    required String title,
    required String message,
    List<String>? targetUsers,
    String? actionUrl,
  }) async {
    await createNotification(
      notificationType: 'warning',
      severity: 'high',
      title: title,
      message: message,
      targetUsers: targetUsers,
      actionUrl: actionUrl,
    );
  }

  /// Create info notification
  Future<void> createInfo({
    required String title,
    required String message,
    List<String>? targetUsers,
    String? actionUrl,
  }) async {
    await createNotification(
      notificationType: 'info',
      severity: 'low',
      title: title,
      message: message,
      targetUsers: targetUsers,
      actionUrl: actionUrl,
    );
  }

  /// Create success notification
  Future<void> createSuccess({
    required String title,
    required String message,
    List<String>? targetUsers,
  }) async {
    await createNotification(
      notificationType: 'success',
      severity: 'low',
      title: title,
      message: message,
      targetUsers: targetUsers,
    );
  }

  /// Cleanup: Dispose realtime channel
  void dispose() {
    _notificationChannel?.unsubscribe();
    _notificationChannel = null;
  }
}
