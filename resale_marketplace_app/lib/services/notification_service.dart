import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  String? _fcmToken;
  bool _isInitialized = false;

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 로컬 알림 초기화
      await _initializeLocalNotifications();

      // FCM 초기화
      await _initializeFCM();

      _isInitialized = true;
      developer.log('NotificationService initialized successfully');
    } catch (error, stackTrace) {
      ErrorHandler().logError(
        AppError.fromException(
          Exception('알림 서비스 초기화에 실패했습니다: $error'),
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 알림 채널 생성
    if (!kIsWeb) {
      await _createNotificationChannels();
    }
  }

  /// FCM 초기화
  Future<void> _initializeFCM() async {
    // 권한 요청
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      developer.log('User granted permission');
    } else {
      developer.log('User declined or has not accepted permission');
      return;
    }

    // FCM 토큰 가져오기
    _fcmToken = await _firebaseMessaging.getToken();
    developer.log('FCM Token: $_fcmToken');

    // 토큰을 서버에 저장
    if (_fcmToken != null) {
      await _saveFCMTokenToServer(_fcmToken!);
    }

    // 토큰 갱신 리스너
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveFCMTokenToServer(newToken);
    });

    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 백그라운드 메시지 처리
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // 앱이 종료된 상태에서 알림으로 앱을 열었을 때
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  /// 알림 채널 생성 (Android)
  Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'chat_messages',
        '채팅 메시지',
        description: '새로운 채팅 메시지 알림',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
      AndroidNotificationChannel(
        'transactions',
        '거래 알림',
        description: '거래 상태 변경 알림',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'system',
        '시스템 알림',
        description: '시스템 관련 알림',
        importance: Importance.defaultImportance,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    developer.log('Received foreground message: ${message.messageId}');

    // 로컬 알림으로 표시
    _showLocalNotification(message);
  }

  /// 백그라운드 메시지 처리
  void _handleBackgroundMessage(RemoteMessage message) {
    developer.log('Received background message: ${message.messageId}');

    // 메시지 데이터에 따라 적절한 화면으로 이동
    _navigateFromNotification(message.data);
  }

  /// 알림 탭 처리
  void _onNotificationTapped(NotificationResponse response) {
    developer.log('Notification tapped: ${response.payload}');

    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _navigateFromNotification(data);
    }
  }

  /// 알림으로부터 네비게이션
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    switch (type) {
      case 'chat_message':
        if (id != null) {
          // 채팅방으로 이동
          // NavigationService.navigateTo('/chat/$id');
        }
        break;
      case 'transaction_update':
        if (id != null) {
          // 거래 상세로 이동
          // NavigationService.navigateTo('/transaction/$id');
        }
        break;
      case 'product_inquiry':
        if (id != null) {
          // 상품 상세로 이동
          // NavigationService.navigateTo('/product/$id');
        }
        break;
    }
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final channelId = _getChannelId(message.data['type']);

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _getChannelName(channelId),
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// 채널 ID 가져오기
  String _getChannelId(String? type) {
    switch (type) {
      case 'chat_message':
        return 'chat_messages';
      case 'transaction_update':
      case 'safe_transaction_update':
        return 'transactions';
      default:
        return 'system';
    }
  }

  /// 채널 이름 가져오기
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'chat_messages':
        return '채팅 메시지';
      case 'transactions':
        return '거래 알림';
      default:
        return '시스템 알림';
    }
  }

  /// FCM 토큰을 서버에 저장
  Future<void> _saveFCMTokenToServer(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('user_fcm_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('FCM token saved to server');
    } catch (error) {
      developer.log('Failed to save FCM token: $error');
    }
  }

  /// 특정 사용자에게 알림 전송 (서버 API 호출)
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
    } catch (error) {
      ErrorHandler().logError(
        AppError.fromException(
          Exception('알림 전송에 실패했습니다: $error'),
        ),
      );
    }
  }

  /// 채팅 메시지 알림
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    await sendNotificationToUser(
      userId: recipientId,
      title: senderName,
      body: message,
      data: {
        'type': 'chat_message',
        'id': chatRoomId,
        'sender_name': senderName,
      },
    );
  }

  /// 거래 상태 변경 알림
  Future<void> sendTransactionNotification({
    required String userId,
    required String title,
    required String message,
    required String transactionId,
    String? type,
  }) async {
    await sendNotificationToUser(
      userId: userId,
      title: title,
      body: message,
      data: {'type': type ?? 'transaction_update', 'id': transactionId},
    );
  }

  /// 상품 문의 알림
  Future<void> sendProductInquiryNotification({
    required String sellerId,
    required String inquirerName,
    required String productTitle,
    required String productId,
  }) async {
    await sendNotificationToUser(
      userId: sellerId,
      title: '상품 문의',
      body: '$inquirerName님이 "$productTitle"에 문의했습니다.',
      data: {
        'type': 'product_inquiry',
        'id': productId,
        'inquirer_name': inquirerName,
      },
    );
  }

  /// 로컬 알림 직접 표시
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? channelId,
    Map<String, dynamic>? data,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId ?? 'system',
          _getChannelName(channelId ?? 'system'),
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// 특정 알림 취소
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// FCM 토큰 가져오기
  String? get fcmToken => _fcmToken;

  /// 초기화 상태 확인
  bool get isInitialized => _isInitialized;
}

