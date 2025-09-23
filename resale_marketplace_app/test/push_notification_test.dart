import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/services/push_notification_service.dart';

class FakePushNotificationService {
  bool initialized = false;
  String? fcmToken;
  final List<NotificationPayload> sentNotifications = [];
  int badgeCount = 0;

  Future<void> initialize() async {
    initialized = true;
    fcmToken = 'test-token';
  }

  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    sentNotifications.add(
      NotificationPayload(
        type: type,
        title: title,
        body: body,
        data: data ?? {},
      ),
    );
  }

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
      data: {'chat_room_id': chatRoomId},
    );
  }

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

  Future<void> updateBadgeCount(int count) async {
    badgeCount = count;
  }

  Future<void> clearBadge() async {
    badgeCount = 0;
  }
}

void main() {
  group('FakePushNotificationService Tests', () {
    late FakePushNotificationService notificationService;

    setUp(() {
      notificationService = FakePushNotificationService();
    });

    test('should initialize successfully', () async {
      await notificationService.initialize();
      expect(notificationService.initialized, isTrue);
      expect(notificationService.fcmToken, equals('test-token'));
    });

    test('should send push notification', () async {
      await notificationService.sendPushNotification(
        userId: 'user-id',
        title: 'Hello',
        body: 'World',
        type: NotificationType.chatMessage,
        data: const {'key': 'value'},
      );

      expect(notificationService.sentNotifications, hasLength(1));
      final payload = notificationService.sentNotifications.first;
      expect(payload.title, equals('Hello'));
      expect(payload.body, equals('World'));
      expect(payload.type, equals(NotificationType.chatMessage));
      expect(payload.data, equals(const {'key': 'value'}));
    });

    test('should send chat notification', () async {
      await notificationService.sendChatNotification(
        recipientId: 'user-id',
        senderName: 'Alice',
        message: 'Hi',
        chatRoomId: 'room-1',
      );

      expect(notificationService.sentNotifications, hasLength(1));
      expect(
        notificationService.sentNotifications.first.data['chat_room_id'],
        equals('room-1'),
      );
    });

    test('should send transaction notification', () async {
      await notificationService.sendTransactionNotification(
        userId: 'user-id',
        title: 'Transaction',
        message: 'Completed',
        transactionId: 'txn-1',
      );

      expect(notificationService.sentNotifications, hasLength(1));
      expect(
        notificationService.sentNotifications.first.data['transaction_id'],
        equals('txn-1'),
      );
    });

    test('should manage badge count', () async {
      await notificationService.updateBadgeCount(5);
      expect(notificationService.badgeCount, equals(5));

      await notificationService.clearBadge();
      expect(notificationService.badgeCount, equals(0));
    });
  });

  group('NotificationPayload Tests', () {
    test('should create notification payload correctly', () {
      const data = <String, dynamic>{'key': 'value'};
      final timestamp = DateTime.now();

      final payload = NotificationPayload(
        type: NotificationType.chatMessage,
        title: 'Test Title',
        body: 'Test Body',
        data: data,
        timestamp: timestamp,
      );

      expect(payload.type, equals(NotificationType.chatMessage));
      expect(payload.title, equals('Test Title'));
      expect(payload.body, equals('Test Body'));
      expect(payload.data, equals(data));
      expect(payload.timestamp, equals(timestamp));
    });

    test('should create notification payload from JSON', () {
      final json = <String, dynamic>{
        'type': 'chat_message',
        'title': 'Test Title',
        'body': 'Test Body',
        'data': {'key': 'value'},
        'timestamp': '2024-01-01T12:00:00Z',
      };

      final payload = NotificationPayload.fromJson(json);

      expect(payload.type, equals(NotificationType.chatMessage));
      expect(payload.title, equals('Test Title'));
      expect(payload.body, equals('Test Body'));
      expect(payload.data, equals({'key': 'value'}));
    });

    test('should convert notification payload to JSON', () {
      final payload = NotificationPayload(
        type: NotificationType.transaction,
        title: 'Transaction',
        body: 'Your order is ready',
        data: const {'transaction_id': '123'},
      );

      final json = payload.toJson();

      expect(json['type'], equals('transaction'));
      expect(json['title'], equals('Transaction'));
      expect(json['body'], equals('Your order is ready'));
      expect(json['data'], equals({'transaction_id': '123'}));
      expect(json['timestamp'], isA<String>());
    });

    test('should handle unknown notification type', () {
      final json = <String, dynamic>{
        'type': 'unknown_type',
        'title': 'Test',
        'body': 'Test',
        'data': const <String, dynamic>{},
      };

      final payload = NotificationPayload.fromJson(json);

      expect(payload.type, equals(NotificationType.system));
    });
  });

  group('NotificationType Tests', () {
    test('should have correct notification types', () {
      expect(NotificationType.chatMessage, isA<NotificationType>());
      expect(NotificationType.transaction, isA<NotificationType>());
      expect(NotificationType.review, isA<NotificationType>());
      expect(NotificationType.system, isA<NotificationType>());
      expect(NotificationType.promotion, isA<NotificationType>());
    });

    test('should convert notification type to string correctly', () {
      expect(NotificationType.chatMessage.name, equals('chatMessage'));
      expect(NotificationType.transaction.name, equals('transaction'));
      expect(NotificationType.review.name, equals('review'));
      expect(NotificationType.system.name, equals('system'));
      expect(NotificationType.promotion.name, equals('promotion'));
    });
  });
}
