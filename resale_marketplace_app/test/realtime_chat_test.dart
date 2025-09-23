import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/models/chat_message_model.dart';
import 'package:resale_marketplace_app/services/realtime_chat_service.dart';

class FakeRealtimeChatService {
  final Map<String, Set<String>> _roomOnlineUsers = {};

  Future<void> joinChatRoom(String roomId) async {
    _roomOnlineUsers.putIfAbsent(roomId, () => <String>{});
  }

  Future<void> leaveChatRoom(String roomId) async {
    _roomOnlineUsers.remove(roomId);
  }

  Future<ChatMessageModel?> sendMessage({
    required String roomId,
    required String content,
    required String messageType,
    List<String>? imageUrls,
    Map<String, dynamic>? metadata,
  }) async {
    final resolvedType = _parseType(messageType);
    return ChatMessageModel(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      chatRoomId: roomId,
      senderId: 'sender-id',
      content: content,
      messageType: resolvedType,
      createdAt: DateTime.now(),
      isRead: false,
    );
  }

  Future<ChatMessageModel?> sendImageMessage({
    required String roomId,
    required List<String> imageUrls,
    String? caption,
  }) async {
    return ChatMessageModel(
      id: 'img-${DateTime.now().microsecondsSinceEpoch}',
      chatRoomId: roomId,
      senderId: 'sender-id',
      content: caption ?? '',
      messageType: MessageType.image,
      imageUrls: imageUrls,
      createdAt: DateTime.now(),
      isRead: false,
    );
  }

  Future<void> startTyping(String roomId) async {}

  Future<void> stopTyping(String roomId) async {}

  Future<void> markMessageAsRead(String messageId) async {}

  Set<String> getOnlineUsers(String roomId) =>
      _roomOnlineUsers[roomId] ?? <String>{};

  bool isUserOnline(String userId) =>
      _roomOnlineUsers.values.any((users) => users.contains(userId));

  void addOnlineUser(String roomId, String userId) {
    _roomOnlineUsers.putIfAbsent(roomId, () => <String>{}).add(userId);
  }

  MessageType _parseType(String? type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'system':
        return MessageType.system;
      case 'transaction':
        return MessageType.transaction;
      default:
        return MessageType.text;
    }
  }
}

void main() {
  group('RealtimeChatService (fake) Tests', () {
    late FakeRealtimeChatService chatService;

    setUp(() {
      chatService = FakeRealtimeChatService();
    });

    group('Chat Room Management', () {
      test('should join chat room successfully', () {
        expectLater(chatService.joinChatRoom('room-1'), completes);
      });

      test('should leave chat room successfully', () async {
        await chatService.joinChatRoom('room-1');
        expectLater(chatService.leaveChatRoom('room-1'), completes);
      });
    });

    group('Message Handling', () {
      test('should send text message successfully', () async {
        final message = await chatService.sendMessage(
          roomId: 'room-1',
          content: 'Hello',
          messageType: MessageType.text.name,
        );
        expect(message, isA<ChatMessageModel>());
      });

      test('should send image message successfully', () async {
        final message = await chatService.sendImageMessage(
          roomId: 'room-1',
          imageUrls: const ['https://example.com/image.jpg'],
          caption: 'Test',
        );
        expect(message, isA<ChatMessageModel>());
        expect(message?.imageUrls, isNotEmpty);
      });
    });

    group('Typing Indicators', () {
      test('should start typing without throwing', () {
        expectLater(chatService.startTyping('room-1'), completes);
      });

      test('should stop typing without throwing', () {
        expectLater(chatService.stopTyping('room-1'), completes);
      });
    });

    group('Message Read Status', () {
      test('should mark message as read successfully', () {
        expectLater(chatService.markMessageAsRead('message-id'), completes);
      });
    });

    group('Online Status', () {
      test('should get online users for room', () async {
        await chatService.joinChatRoom('room-1');
        chatService.addOnlineUser('room-1', 'user-1');

        final onlineUsers = chatService.getOnlineUsers('room-1');
        expect(onlineUsers, contains('user-1'));
      });

      test('should check if user is online', () async {
        await chatService.joinChatRoom('room-1');
        chatService.addOnlineUser('room-1', 'user-1');

        expect(chatService.isUserOnline('user-1'), isTrue);
        expect(chatService.isUserOnline('user-2'), isFalse);
      });
    });
  });

  group('ChatEvent Tests', () {
    test('should create chat event with correct properties', () {
      const type = ChatEventType.messageReceived;
      const data = 'test data';
      const userId = 'test-user-id';
      final timestamp = DateTime.now();

      final event = ChatEvent(
        type: type,
        data: data,
        userId: userId,
        timestamp: timestamp,
      );

      expect(event.type, equals(type));
      expect(event.data, equals(data));
      expect(event.userId, equals(userId));
      expect(event.timestamp, equals(timestamp));
    });

    test('should create chat event with default timestamp', () {
      const type = ChatEventType.typing;
      const data = 'test data';

      final event = ChatEvent(type: type, data: data);

      expect(event.type, equals(type));
      expect(event.data, equals(data));
      expect(event.userId, isNull);
      expect(event.timestamp, isA<DateTime>());
    });
  });

  group('ChatMessageModel Tests', () {
    test('should create message from JSON correctly', () {
      final json = {
        'id': 'test-id',
        'chat_room_id': 'room-id',
        'sender_id': 'sender-id',
        'content': 'Test message',
        'message_type': 'text',
        'created_at': '2024-01-01T12:00:00Z',
        'is_read': false,
      };

      final message = ChatMessageModel.fromJson(json);

      expect(message.id, equals('test-id'));
      expect(message.chatRoomId, equals('room-id'));
      expect(message.senderId, equals('sender-id'));
      expect(message.content, equals('Test message'));
      expect(message.messageType, equals(MessageType.text));
      expect(message.isRead, isFalse);
    });

    test('should format time correctly', () {
      final now = DateTime.now();
      final message = ChatMessageModel(
        id: 'test-id',
        chatRoomId: 'room-id',
        senderId: 'sender-id',
        content: 'Test message',
        messageType: MessageType.text,
        createdAt: now,
        isRead: false,
      );

      final formattedTime = message.formattedTime;
      expect(formattedTime, isA<String>());
      expect(formattedTime.isNotEmpty, isTrue);
    });
  });
}
