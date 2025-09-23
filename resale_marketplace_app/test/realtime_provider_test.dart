import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:resale_marketplace_app/providers/realtime_provider.dart';
import 'package:resale_marketplace_app/services/realtime_chat_service.dart';
import 'package:resale_marketplace_app/services/push_notification_service.dart';
import 'package:resale_marketplace_app/models/chat_message_model.dart';

import 'realtime_provider_test.mocks.dart';

// Mock 클래스 생성을 위한 어노테이션
@GenerateMocks([RealtimeChatService, PushNotificationService])
void main() {
  group('RealtimeProvider Tests', () {
    late RealtimeProvider realtimeProvider;
    late MockRealtimeChatService mockChatService;
    late MockPushNotificationService mockPushService;

    setUp(() {
      mockChatService = MockRealtimeChatService();
      mockPushService = MockPushNotificationService();
      realtimeProvider = RealtimeProvider(
        realtimeChatService: mockChatService,
        pushNotificationService: mockPushService,
      );
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Given
        when(mockChatService.initialize()).thenAnswer((_) async {});
        when(mockPushService.initialize()).thenAnswer((_) async {});
        when(
          mockChatService.eventStream,
        ).thenAnswer((_) => const Stream.empty());
        when(
          mockPushService.notificationStream,
        ).thenAnswer((_) => const Stream.empty());

        // When & Then
        expectLater(realtimeProvider.initialize(), completes);
      });

      test('should have correct initial state', () {
        // When & Then
        expect(realtimeProvider.isConnected, isFalse);
        expect(realtimeProvider.isInitialized, isFalse);
        expect(realtimeProvider.unreadNotificationCount, equals(0));
        expect(realtimeProvider.notifications, isEmpty);
        expect(realtimeProvider.activeChatRooms, isEmpty);
      });
    });

    group('Chat Room Management', () {
      test('should join chat room successfully', () async {
        // Given
        const roomId = 'test-room-id';
        when(mockChatService.joinChatRoom(roomId)).thenAnswer((_) async {});

        // When & Then
        expectLater(realtimeProvider.joinChatRoom(roomId), completes);
      });

      test('should leave chat room successfully', () async {
        // Given
        const roomId = 'test-room-id';
        when(mockChatService.leaveChatRoom(roomId)).thenAnswer((_) async {});

        // When & Then
        expectLater(realtimeProvider.leaveChatRoom(roomId), completes);
      });

      test('should get chat messages for room', () {
        // Given
        const roomId = 'test-room-id';

        // When
        final messages = realtimeProvider.getChatMessages(roomId);

        // Then
        expect(messages, isA<List<ChatMessageModel>>());
        expect(messages, isEmpty);
      });

      test('should get online users for room', () {
        // Given
        const roomId = 'test-room-id';

        // When
        final onlineUsers = realtimeProvider.getOnlineUsers(roomId);

        // Then
        expect(onlineUsers, isA<Set<String>>());
        expect(onlineUsers, isEmpty);
      });

      test('should get typing users for room', () {
        // Given
        const roomId = 'test-room-id';

        // When
        final typingUsers = realtimeProvider.getTypingUsers(roomId);

        // Then
        expect(typingUsers, isA<Set<String>>());
        expect(typingUsers, isEmpty);
      });
    });

    group('Message Operations', () {
      test('should send message successfully', () async {
        // Given
        const roomId = 'test-room-id';
        const content = 'Test message';
        const messageType = 'text';

        final expectedMessage = ChatMessageModel(
          id: 'message-id',
          chatRoomId: roomId,
          senderId: 'sender-id',
          content: content,
          messageType: MessageType.text,
          createdAt: DateTime.now(),
          isRead: false,
        );

        when(
          mockChatService.sendMessage(
            roomId: roomId,
            content: content,
            messageType: messageType,
          ),
        ).thenAnswer((_) async => expectedMessage);

        // When
        final message = await realtimeProvider.sendMessage(
          roomId: roomId,
          content: content,
          messageType: messageType,
        );

        // Then
        expect(message, equals(expectedMessage));
        verify(
          mockChatService.sendMessage(
            roomId: roomId,
            content: content,
            messageType: messageType,
          ),
        ).called(1);
      });

      test('should send image message successfully', () async {
        // Given
        const roomId = 'test-room-id';
        const imageUrls = ['https://example.com/image.jpg'];
        const caption = 'Test image';

        final expectedMessage = ChatMessageModel(
          id: 'message-id',
          chatRoomId: roomId,
          senderId: 'sender-id',
          content: caption,
          messageType: MessageType.image,
          imageUrls: imageUrls,
          createdAt: DateTime.now(),
          isRead: false,
        );

        when(
          mockChatService.sendImageMessage(
            roomId: roomId,
            imageUrls: imageUrls,
            caption: caption,
          ),
        ).thenAnswer((_) async => expectedMessage);

        // When
        final message = await realtimeProvider.sendImageMessage(
          roomId: roomId,
          imageUrls: imageUrls,
          caption: caption,
        );

        // Then
        expect(message, equals(expectedMessage));
        verify(
          mockChatService.sendImageMessage(
            roomId: roomId,
            imageUrls: imageUrls,
            caption: caption,
          ),
        ).called(1);
      });

      test('should start typing successfully', () async {
        // Given
        const roomId = 'test-room-id';
        when(mockChatService.startTyping(roomId)).thenAnswer((_) async {});

        // When & Then
        expectLater(realtimeProvider.startTyping(roomId), completes);
      });

      test('should stop typing successfully', () async {
        // Given
        const roomId = 'test-room-id';
        when(mockChatService.stopTyping(roomId)).thenAnswer((_) async {});

        // When & Then
        expectLater(realtimeProvider.stopTyping(roomId), completes);
      });

      test('should mark message as read successfully', () async {
        // Given
        const messageId = 'message-id';
        when(
          mockChatService.markMessageAsRead(messageId),
        ).thenAnswer((_) async {});

        // When & Then
        expectLater(realtimeProvider.markMessageAsRead(messageId), completes);
      });
    });

    group('User Status', () {
      test('should check if user is online', () {
        // Given
        const userId = 'user-id';
        when(mockChatService.isUserOnline(userId)).thenReturn(true);

        // When
        final isOnline = realtimeProvider.isUserOnline(userId);

        // Then
        expect(isOnline, isA<bool>());
      });

      test('should check if user is typing', () {
        // Given
        const roomId = 'room-id';
        const userId = 'user-id';

        // When
        final isTyping = realtimeProvider.isUserTyping(roomId, userId);

        // Then
        expect(isTyping, isFalse);
      });
    });

    group('Push Notifications', () {
      test('should send push notification successfully', () async {
        // Given
        const userId = 'user-id';
        const title = 'Test Title';
        const body = 'Test Body';
        const type = NotificationType.chatMessage;
        const data = {'key': 'value'};

        when(
          mockPushService.sendPushNotification(
            userId: userId,
            title: title,
            body: body,
            type: type,
            data: data,
          ),
        ).thenAnswer((_) async {});

        // When
        await realtimeProvider.sendPushNotification(
          userId: userId,
          title: title,
          body: body,
          type: type,
          data: data,
        );

        // Then
        verify(
          mockPushService.sendPushNotification(
            userId: userId,
            title: title,
            body: body,
            type: type,
            data: data,
          ),
        ).called(1);
      });

      test('should send chat notification successfully', () async {
        // Given
        const recipientId = 'recipient-id';
        const senderName = 'John Doe';
        const message = 'Hello!';
        const chatRoomId = 'room-id';

        when(
          mockPushService.sendChatNotification(
            recipientId: recipientId,
            senderName: senderName,
            message: message,
            chatRoomId: chatRoomId,
          ),
        ).thenAnswer((_) async {});

        // When
        await realtimeProvider.sendChatNotification(
          recipientId: recipientId,
          senderName: senderName,
          message: message,
          chatRoomId: chatRoomId,
        );

        // Then
        verify(
          mockPushService.sendChatNotification(
            recipientId: recipientId,
            senderName: senderName,
            message: message,
            chatRoomId: chatRoomId,
          ),
        ).called(1);
      });

      test('should mark notification as read', () {
        // Given
        const index = 0;

        // When
        realtimeProvider.markNotificationAsRead(index);

        // Then
        expect(realtimeProvider.unreadNotificationCount, equals(0));
      });

      test('should mark all notifications as read', () {
        // When
        realtimeProvider.markAllNotificationsAsRead();

        // Then
        expect(realtimeProvider.notifications, isEmpty);
        expect(realtimeProvider.unreadNotificationCount, equals(0));
      });

      test('should update badge count successfully', () async {
        // Given
        when(mockPushService.updateBadgeCount(any)).thenAnswer((_) async {});

        // When & Then
        expectLater(realtimeProvider.updateBadgeCount(), completes);
      });
    });

    group('Connection Management', () {
      test('should reconnect successfully', () async {
        // Given
        when(mockChatService.initialize()).thenAnswer((_) async {});
        when(
          mockChatService.eventStream,
        ).thenAnswer((_) => const Stream.empty());

        // When & Then
        expectLater(realtimeProvider.reconnect(), completes);
      });

      test('should check connection periodically', () {
        // When & Then
        expect(() => realtimeProvider.checkConnection(), returnsNormally);
      });
    });
  });
}
