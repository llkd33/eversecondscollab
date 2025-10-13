import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/realtime_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/realtime_notification_badge.dart' hide ConnectionStatusIndicator;

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 배지 카운트 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RealtimeProvider>().updateBadgeCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // 연결 상태 표시
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConnectionStatusIndicator(),
          ),
          // 모두 읽음 버튼
          Consumer<RealtimeProvider>(
            builder: (context, realtimeProvider, _) {
              final hasUnread = realtimeProvider.unreadNotificationCount > 0 ||
                               realtimeProvider.realTimeBadgeCount > 0;
              
              if (!hasUnread) return const SizedBox.shrink();
              
              return TextButton(
                onPressed: () => _markAllAsRead(realtimeProvider),
                child: const Text('모두 읽음'),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(
            child: const SizedBox.shrink(),
          ),
          Expanded(
            child: Consumer<RealtimeProvider>(
              builder: (context, realtimeProvider, _) {
                final notifications = realtimeProvider.notifications;
                
                if (notifications.isEmpty) {
                  return _buildEmptyState();
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    // 실제 알림 데이터 새로고침 로직 추가 가능
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(
                        notification,
                        index,
                        realtimeProvider,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '알림이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 알림이 오면 여기에 표시됩니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    NotificationPayload notification,
    int index,
    RealtimeProvider realtimeProvider,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleNotificationTap(notification, index, realtimeProvider),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildNotificationIcon(notification.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (notification.body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            notification.body,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (action) => _handleNotificationAction(
                      action,
                      notification,
                      index,
                      realtimeProvider,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'read',
                        child: Row(
                          children: [
                            Icon(Icons.mark_email_read, size: 20),
                            SizedBox(width: 8),
                            Text('읽음 처리'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('삭제', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getNotificationTypeColor(notification.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getNotificationTypeLabel(notification.type),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getNotificationTypeColor(notification.type),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(notification.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.chatMessage:
        iconData = Icons.message;
        color = AppTheme.primaryColor;
        break;
      case NotificationType.transaction:
        iconData = Icons.shopping_cart;
        color = Colors.green;
        break;
      case NotificationType.review:
        iconData = Icons.star;
        color = Colors.orange;
        break;
      case NotificationType.promotion:
        iconData = Icons.local_offer;
        color = Colors.purple;
        break;
      case NotificationType.system:
      default:
        iconData = Icons.info;
        color = Colors.blue;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: color,
        size: 20,
      ),
    );
  }

  Color _getNotificationTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.chatMessage:
        return AppTheme.primaryColor;
      case NotificationType.transaction:
        return Colors.green;
      case NotificationType.review:
        return Colors.orange;
      case NotificationType.promotion:
        return Colors.purple;
      case NotificationType.system:
      default:
        return Colors.blue;
    }
  }

  String _getNotificationTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.chatMessage:
        return '채팅';
      case NotificationType.transaction:
        return '거래';
      case NotificationType.review:
        return '리뷰';
      case NotificationType.promotion:
        return '프로모션';
      case NotificationType.system:
      default:
        return '시스템';
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return '방금 전';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  void _handleNotificationTap(
    NotificationPayload notification,
    int index,
    RealtimeProvider realtimeProvider,
  ) {
    // 알림 클릭 시 해당 화면으로 이동
    _navigateToNotificationTarget(notification);
    
    // 읽음 처리
    realtimeProvider.markNotificationAsRead(index);
  }

  void _handleNotificationAction(
    String action,
    NotificationPayload notification,
    int index,
    RealtimeProvider realtimeProvider,
  ) {
    switch (action) {
      case 'read':
        realtimeProvider.markNotificationAsRead(index);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림을 읽음 처리했습니다')),
        );
        break;
      case 'delete':
        realtimeProvider.markNotificationAsRead(index);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림을 삭제했습니다')),
        );
        break;
    }
  }

  void _navigateToNotificationTarget(NotificationPayload notification) {
    // 알림 타입에 따라 적절한 화면으로 이동
    switch (notification.type) {
      case NotificationType.chatMessage:
        final chatRoomId = notification.data['chat_room_id'] as String?;
        if (chatRoomId != null) {
          // AppRouter.router.push('/chat/$chatRoomId');
        }
        break;
      case NotificationType.transaction:
        final transactionId = notification.data['transaction_id'] as String?;
        if (transactionId != null) {
          // AppRouter.router.push('/transaction/$transactionId');
        }
        break;
      case NotificationType.review:
        // AppRouter.router.push('/profile');
        break;
      default:
        break;
    }
  }

  void _markAllAsRead(RealtimeProvider realtimeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 알림 읽음'),
        content: const Text('모든 알림을 읽음 처리하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              realtimeProvider.markAllNotificationsAsRead();
              realtimeProvider.markAllRealtimeNotificationsAsRead();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('모든 알림을 읽음 처리했습니다')),
              );
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}