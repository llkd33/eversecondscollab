import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/notification_preferences_service.dart';
import '../../services/notification_analytics_service.dart';
import '../../widgets/notification_permission_dialog.dart';
import '../../providers/auth_provider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _chatNotifications = true;
  bool _transactionNotifications = true;
  bool _systemNotifications = true;
  bool _promotionNotifications = false;
  
  bool _isLoading = false;
  AuthorizationStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // FCM 권한 상태 확인
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      _permissionStatus = settings.authorizationStatus;
      
      // 사용자별 알림 설정 불러오기
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      
      if (userId != null) {
        final preferences = await NotificationPreferencesService().getUserPreferences(userId);
        
        if (mounted) {
          setState(() {
            _chatNotifications = preferences['chat_notifications'] ?? true;
            _transactionNotifications = preferences['transaction_notifications'] ?? true;
            _systemNotifications = preferences['resale_notifications'] ?? true;
            _promotionNotifications = preferences['promotion_notifications'] ?? false;
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('알림 설정 로드 실패: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await NotificationPermissionDialog.show(context);
    if (granted) {
      await _loadSettings();
    }
  }

  Future<void> _updateNotificationSetting(String type, bool enabled) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      
      if (userId != null) {
        final success = await NotificationPreferencesService().updatePreference(
          userId, 
          type, 
          enabled
        );
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(enabled ? '알림이 활성화되었습니다' : '알림이 비활성화되었습니다'),
              backgroundColor: enabled ? Colors.green : Colors.orange,
            ),
          );
        } else {
          throw Exception('서버 저장 실패');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정 저장에 실패했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('알림 설정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 권한 상태 카드
                  _buildPermissionStatusCard(),
                  
                  const SizedBox(height: 20),
                  
                  // 알림 설정
                  _buildNotificationSettings(),
                  
                  const SizedBox(height: 20),
                  
                  // 추가 옵션
                  _buildAdditionalOptions(),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionStatusCard() {
    final isGranted = _permissionStatus == AuthorizationStatus.authorized;
    final isProvisional = _permissionStatus == AuthorizationStatus.provisional;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGranted ? Icons.notifications_active : Icons.notifications_off,
                color: isGranted ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '알림 권한 상태',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getPermissionStatusText(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (!isGranted && !isProvisional) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '알림 권한 요청',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '알림 타입별 설정',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildNotificationTile(
            icon: Icons.chat_bubble_outline,
            title: '채팅 메시지',
            subtitle: '새로운 채팅 메시지 알림',
            value: _chatNotifications,
            onChanged: (value) {
              setState(() => _chatNotifications = value);
              _updateNotificationSetting('chat', value);
            },
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.swap_horiz,
            title: '거래 알림',
            subtitle: '거래 상태 변경 및 안전거래 알림',
            value: _transactionNotifications,
            onChanged: (value) {
              setState(() => _transactionNotifications = value);
              _updateNotificationSetting('transaction', value);
            },
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.store,
            title: '대신판매 알림',
            subtitle: '대신판매 요청 및 진행상황 알림',
            value: _systemNotifications,
            onChanged: (value) {
              setState(() => _systemNotifications = value);
              _updateNotificationSetting('resale', value);
            },
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.campaign,
            title: '마케팅 알림',
            subtitle: '이벤트, 할인 정보 등 마케팅 알림',
            value: _promotionNotifications,
            onChanged: (value) {
              setState(() => _promotionNotifications = value);
              _updateNotificationSetting('promotion', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: value ? AppTheme.primaryColor : Colors.grey,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildAdditionalOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '추가 설정',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.blue),
            title: const Text('방해 금지 시간'),
            subtitle: const Text('알림을 받지 않을 시간대 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 방해 금지 시간 설정 화면으로 이동
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('준비 중인 기능입니다')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.vibration, color: Colors.purple),
            title: const Text('진동 패턴'),
            subtitle: const Text('알림 진동 패턴 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 진동 패턴 설정
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('준비 중인 기능입니다')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.volume_up, color: Colors.orange),
            title: const Text('알림음 설정'),
            subtitle: const Text('알림음 변경 및 볼륨 조절'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 알림음 설정
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('준비 중인 기능입니다')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.clear_all, color: Colors.red),
            title: const Text('모든 알림 지우기'),
            subtitle: const Text('받은 모든 알림을 삭제합니다'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('알림 삭제'),
                  content: const Text('모든 알림을 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                await NotificationService().cancelAllNotifications();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('모든 알림이 삭제되었습니다'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  String _getPermissionStatusText() {
    switch (_permissionStatus) {
      case AuthorizationStatus.authorized:
        return '알림이 허용되어 모든 알림을 받을 수 있습니다';
      case AuthorizationStatus.provisional:
        return '임시 권한이 부여되어 일부 알림을 받을 수 있습니다';
      case AuthorizationStatus.denied:
        return '알림이 거부되어 알림을 받을 수 없습니다';
      case AuthorizationStatus.notDetermined:
        return '알림 권한이 아직 요청되지 않았습니다';
      default:
        return '알림 권한 상태를 확인할 수 없습니다';
    }
  }
}