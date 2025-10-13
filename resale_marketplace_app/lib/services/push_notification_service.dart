import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_router.dart';

enum NotificationType { chatMessage, transaction, review, system, promotion }

class NotificationPayload {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  NotificationPayload({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      id: json['id'] as String? ?? '',
      type: _parseNotificationType(json['type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  static NotificationType _parseNotificationType(String? type) {
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

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;

  final StreamController<NotificationPayload> _notificationController =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get notificationStream =>
      _notificationController.stream;

  bool _isInitialized = false;
  String? _fcmToken;

  /// Push 알림 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log('Initializing push notification service');

      // Firebase 초기화 확인
      await _ensureFirebaseInitialized();

      // 권한 요청
      await _requestPermissions();

      // 로컬 알림 초기화
      await _initializeLocalNotifications();

      // FCM 설정
      await _setupFCM();

      // 토큰 관리
      await _manageFCMToken();

      _isInitialized = true;
      developer.log('Push notification service initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize push notification service: $e');
      rethrow;
    }
  }

  /// Firebase 초기화 확인
  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  /// 알림 권한 요청
  Future<bool> _requestPermissions() async {
    // iOS 권한 설정
    if (Platform.isIOS) {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      developer.log('iOS permission status: ${settings.authorizationStatus}');
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    // Android 권한 설정
    if (Platform.isAndroid) {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted = await androidImplementation
            .requestNotificationsPermission();
        developer.log('Android permission granted: $granted');
        return granted ?? false;
      }
    }

    return true;
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
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Android 알림 채널 생성
  Future<void> _createNotificationChannels() async {
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      // 채팅 알림 채널
      const chatChannel = AndroidNotificationChannel(
        'chat_messages',
        '채팅 메시지',
        description: '새로운 채팅 메시지 알림',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

      // 거래 알림 채널
      const transactionChannel = AndroidNotificationChannel(
        'transactions',
        '거래 알림',
        description: '거래 관련 알림',
        importance: Importance.high,
      );

      // 시스템 알림 채널
      const systemChannel = AndroidNotificationChannel(
        'system',
        '시스템 알림',
        description: '앱 시스템 알림',
        importance: Importance.defaultImportance,
      );

      await androidImplementation.createNotificationChannel(chatChannel);
      await androidImplementation.createNotificationChannel(transactionChannel);
      await androidImplementation.createNotificationChannel(systemChannel);
    }
  }

  /// FCM 설정
  Future<void> _setupFCM() async {
    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 백그라운드 메시지 처리
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // 앱이 종료된 상태에서 알림으로 앱 실행
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  /// FCM 토큰 관리
  Future<void> _manageFCMToken() async {
    try {
      // 현재 토큰 가져오기
      _fcmToken = await _firebaseMessaging.getToken();
      developer.log('FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _saveFCMToken(_fcmToken!);
      }

      // 토큰 변경 감지
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        developer.log('FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        await _saveFCMToken(newToken);
      });
    } catch (e) {
      developer.log('Failed to manage FCM token: $e');
    }
  }

  /// FCM 토큰을 서버에 저장
  Future<void> _saveFCMToken(String token) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('user_fcm_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('FCM token saved successfully');
    } catch (e) {
      developer.log('Failed to save FCM token: $e');
    }
  }

  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    developer.log('Foreground message received: ${message.messageId}');

    final payload = _createNotificationPayload(message);
    _notificationController.add(payload);

    // 로컬 알림 표시
    _showLocalNotification(message);
  }

  /// 백그라운드 메시지 처리
  void _handleBackgroundMessage(RemoteMessage message) {
    developer.log('Background message received: ${message.messageId}');

    final payload = _createNotificationPayload(message);
    _notificationController.add(payload);

    // 필요시 특정 화면으로 네비게이션
    _navigateFromNotification(message);
  }

  /// 알림 클릭 처리
  void _onNotificationTapped(NotificationResponse response) {
    developer.log('Notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _navigateFromNotificationData(data);
      } catch (e) {
        developer.log('Failed to parse notification payload: $e');
      }
    }
  }

  /// 로컬 알림 표시 (public method for realtime service)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const details = AndroidNotificationDetails(
      'system',
      '시스템 알림',
      channelDescription: '앱 시스템 알림',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: details,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      notificationDetails,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// 로컬 알림 표시 (private method for Firebase messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final payload = _createNotificationPayload(message);
    const chatDetails = AndroidNotificationDetails(
      'chat_messages',
      '채팅 메시지',
      channelDescription: '새로운 채팅 메시지 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const transactionDetails = AndroidNotificationDetails(
      'transactions',
      '거래 알림',
      channelDescription: '거래 관련 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const systemDetails = AndroidNotificationDetails(
      'system',
      '시스템 알림',
      channelDescription: '앱 시스템 알림',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    AndroidNotificationDetails details;
    switch (payload.type) {
      case NotificationType.chatMessage:
        details = chatDetails;
        break;
      case NotificationType.transaction:
        details = transactionDetails;
        break;
      default:
        details = systemDetails;
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: details,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(payload.toJson()),
    );
  }

  /// 알림에서 네비게이션
  void _navigateFromNotification(RemoteMessage message) {
    _navigateFromNotificationData(message.data);
  }

  /// 알림 데이터로 네비게이션
  void _navigateFromNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final context = AppRouter.navigatorKey.currentContext;

    if (context == null) return;

    switch (type) {
      case 'chat_message':
        final chatRoomId = data['chat_room_id'] as String?;
        if (chatRoomId != null) {
          AppRouter.router.push('/chat/$chatRoomId');
        }
        break;
      case 'transaction':
        final transactionId = data['transaction_id'] as String?;
        if (transactionId != null) {
          AppRouter.router.push('/transaction/$transactionId');
        }
        break;
      case 'review':
        AppRouter.router.push('/profile');
        break;
      default:
        break;
    }
  }

  /// RemoteMessage에서 NotificationPayload 생성
  NotificationPayload _createNotificationPayload(RemoteMessage message) {
    final notification = message.notification;
    final type = _parseNotificationType(message.data['type'] as String?);

    return NotificationPayload(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: notification?.title ?? '',
      body: notification?.body ?? '',
      data: message.data,
    );
  }

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

  /// 특정 사용자에게 푸시 알림 전송 (서버 API 호출)
  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'type': type.name,
          'data': data ?? {},
        },
      );

      developer.log('Push notification sent successfully');
    } catch (e) {
      developer.log('Failed to send push notification: $e');
    }
  }

  /// 채팅 메시지 알림 전송
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    await sendPushNotification(
      userId: recipientId,
      title: senderName,
      body: message,
      type: NotificationType.chatMessage,
      data: {'chat_room_id': chatRoomId, 'sender_name': senderName},
    );
  }

  /// 거래 알림 전송
  Future<void> sendTransactionNotification({
    required String userId,
    required String title,
    required String message,
    required String transactionId,
  }) async {
    await sendPushNotification(
      userId: userId,
      title: title,
      body: message,
      type: NotificationType.transaction,
      data: {'transaction_id': transactionId},
    );
  }

  /// 알림 배지 수 업데이트
  Future<void> updateBadgeCount(int count) async {
    if (Platform.isIOS) {
      // Note: setApplicationIconBadgeCount is not available in current Firebase Messaging version
      // You may need to use a platform-specific implementation or a third-party package
      // await _firebaseMessaging.setApplicationIconBadgeCount(count);
    }
  }

  /// 알림 배지 클리어
  Future<void> clearBadge() async {
    await updateBadgeCount(0);
  }

  /// 특정 FCM 토큰으로 직접 알림 전송
  Future<void> sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-notification-to-token',
        body: {
          'token': token,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      developer.log('Notification sent to token successfully');
    } catch (e) {
      developer.log('Failed to send notification to token: $e');
    }
  }

  /// 현재 FCM 토큰 가져오기
  String? get fcmToken => _fcmToken;

  /// 서비스 종료
  Future<void> dispose() async {
    await _notificationController.close();
    developer.log('Push notification service disposed');
  }
}

/// 백그라운드 메시지 핸들러 (글로벌 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  developer.log('Background message received: ${message.messageId}');

  // 백그라운드에서 필요한 처리 수행
  // 예: 로컬 데이터베이스 업데이트, 백그라운드 동기화 등
}
