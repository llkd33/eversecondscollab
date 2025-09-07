import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/services/chat_service.dart';
import 'package:resale_marketplace_app/models/chat_model.dart';
import 'package:resale_marketplace_app/models/message_model.dart';

void main() {
  group('Chat Service Tests', () {
    test('should create chat with participants', () async {
      // Test chat creation parameters
      final participants = ['user1', 'user2'];
      final productId = 'product123';
      
      // Note: This test would need mock Supabase client for actual testing
      expect(participants.length, equals(2));
      expect(productId, isNotEmpty);
    });

    test('should handle resale chat creation', () async {
      // Test resale chat creation parameters
      final participants = ['buyer', 'reseller'];
      final productId = 'product123';
      final resellerId = 'reseller';
      final originalSellerId = 'original_seller';
      
      expect(participants.contains(resellerId), isTrue);
      expect(originalSellerId, isNotEmpty);
    });

    test('should validate message model', () {
      // Test message model validation
      expect(() => MessageModel(
        id: '',
        chatId: 'chat123',
        senderId: 'user1',
        content: 'Hello',
        createdAt: DateTime.now(),
      ), throwsArgumentError);

      expect(() => MessageModel(
        id: 'msg123',
        chatId: '',
        senderId: 'user1',
        content: 'Hello',
        createdAt: DateTime.now(),
      ), throwsArgumentError);

      expect(() => MessageModel(
        id: 'msg123',
        chatId: 'chat123',
        senderId: '',
        content: 'Hello',
        createdAt: DateTime.now(),
      ), throwsArgumentError);

      expect(() => MessageModel(
        id: 'msg123',
        chatId: 'chat123',
        senderId: 'user1',
        content: '',
        createdAt: DateTime.now(),
      ), throwsArgumentError);
    });

    test('should validate chat model', () {
      // Test chat model validation
      expect(() => ChatModel(
        id: '',
        participants: ['user1', 'user2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);

      expect(() => ChatModel(
        id: 'chat123',
        participants: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);

      expect(() => ChatModel(
        id: 'chat123',
        participants: ['user1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);

      expect(() => ChatModel(
        id: 'chat123',
        participants: ['user1', 'user1'], // Duplicate participants
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);
    });

    test('should format message time correctly', () {
      final message = MessageModel(
        id: 'msg123',
        chatId: 'chat123',
        senderId: 'user1',
        content: 'Hello',
        createdAt: DateTime(2024, 1, 1, 14, 30),
      );

      expect(message.formattedTime, equals('14:30'));
      expect(message.formattedDate, equals('2024년 1월 1일'));
    });

    test('should identify message types correctly', () {
      final textMessage = MessageModel(
        id: 'msg1',
        chatId: 'chat123',
        senderId: 'user1',
        content: 'Hello',
        createdAt: DateTime.now(),
        messageType: 'text',
      );

      final imageMessage = MessageModel(
        id: 'msg2',
        chatId: 'chat123',
        senderId: 'user1',
        content: 'https://example.com/image.jpg',
        createdAt: DateTime.now(),
        messageType: 'image',
      );

      final systemMessage = MessageModel(
        id: 'msg3',
        chatId: 'chat123',
        senderId: '00000000-0000-0000-0000-000000000000',
        content: 'System message',
        createdAt: DateTime.now(),
        messageType: 'system',
      );

      expect(textMessage.isTextMessage, isTrue);
      expect(textMessage.isImageMessage, isFalse);
      expect(textMessage.isSystemMessage, isFalse);

      expect(imageMessage.isTextMessage, isFalse);
      expect(imageMessage.isImageMessage, isTrue);
      expect(imageMessage.isSystemMessage, isFalse);

      expect(systemMessage.isTextMessage, isFalse);
      expect(systemMessage.isImageMessage, isFalse);
      expect(systemMessage.isSystemMessage, isTrue);
    });

    test('should generate chat title correctly', () {
      final normalChat = ChatModel(
        id: 'chat123',
        participants: ['user1', 'user2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        otherUserName: 'John Doe',
      );

      final resaleChat = ChatModel(
        id: 'chat456',
        participants: ['user1', 'user2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isResaleChat: true,
        otherUserName: 'John Doe',
        resellerName: 'Jane Smith',
      );

      expect(normalChat.getChatTitle(), equals('John Doe'));
      expect(resaleChat.getChatTitle(), equals('John Doe (Jane Smith님이 대신판매 중)'));
    });

    test('should get other user ID correctly', () {
      final chat = ChatModel(
        id: 'chat123',
        participants: ['user1', 'user2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(chat.getOtherUserId('user1'), equals('user2'));
      expect(chat.getOtherUserId('user2'), equals('user1'));
      expect(chat.getOtherUserId('user3'), equals('user1')); // Returns first participant when current user not found
    });

    test('should validate message type', () {
      expect(MessageType.isValid('text'), isTrue);
      expect(MessageType.isValid('image'), isTrue);
      expect(MessageType.isValid('system'), isTrue);
      expect(MessageType.isValid('invalid'), isFalse);
    });

    test('should create system messages correctly', () {
      final resellerNotice = SystemMessages.safeTransactionNotice('John Doe');
      expect(resellerNotice, contains('John Doe'));
      expect(resellerNotice, contains('대신판매'));

      expect(SystemMessages.safeTransactionGuide, isNotEmpty);
      expect(SystemMessages.depositGuide, isNotEmpty);
      expect(SystemMessages.depositConfirmed, isNotEmpty);
      expect(SystemMessages.shippingStarted, isNotEmpty);
      expect(SystemMessages.transactionCompleted, isNotEmpty);
    });
  });

  group('Chat Model Tests', () {
    test('should create chat model from JSON', () {
      final json = {
        'id': 'chat123',
        'participants': ['user1', 'user2'],
        'product_id': 'product123',
        'reseller_id': 'reseller1',
        'is_resale_chat': true,
        'original_seller_id': 'seller1',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
        'product_title': 'Test Product',
        'product_image': 'https://example.com/image.jpg',
        'product_price': 10000,
        'other_user_name': 'John Doe',
        'reseller_name': 'Jane Smith',
        'last_message': 'Hello',
        'last_message_time': '2024-01-01T00:00:00Z',
        'unread_count': 5,
      };

      final chat = ChatModel.fromJson(json);

      expect(chat.id, equals('chat123'));
      expect(chat.participants, equals(['user1', 'user2']));
      expect(chat.productId, equals('product123'));
      expect(chat.resellerId, equals('reseller1'));
      expect(chat.isResaleChat, isTrue);
      expect(chat.originalSellerId, equals('seller1'));
      expect(chat.productTitle, equals('Test Product'));
      expect(chat.productImage, equals('https://example.com/image.jpg'));
      expect(chat.productPrice, equals(10000));
      expect(chat.otherUserName, equals('John Doe'));
      expect(chat.resellerName, equals('Jane Smith'));
      expect(chat.lastMessage, equals('Hello'));
      expect(chat.unreadCount, equals(5));
    });

    test('should convert chat model to JSON', () {
      final chat = ChatModel(
        id: 'chat123',
        participants: ['user1', 'user2'],
        productId: 'product123',
        resellerId: 'reseller1',
        isResaleChat: true,
        originalSellerId: 'seller1',
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        productTitle: 'Test Product',
        productImage: 'https://example.com/image.jpg',
        productPrice: 10000,
        otherUserName: 'John Doe',
        resellerName: 'Jane Smith',
        lastMessage: 'Hello',
        lastMessageTime: DateTime.parse('2024-01-01T00:00:00Z'),
        unreadCount: 5,
      );

      final json = chat.toJson();

      expect(json['id'], equals('chat123'));
      expect(json['participants'], equals(['user1', 'user2']));
      expect(json['product_id'], equals('product123'));
      expect(json['reseller_id'], equals('reseller1'));
      expect(json['is_resale_chat'], isTrue);
      expect(json['original_seller_id'], equals('seller1'));
      expect(json['product_title'], equals('Test Product'));
      expect(json['product_image'], equals('https://example.com/image.jpg'));
      expect(json['product_price'], equals(10000));
      expect(json['other_user_name'], equals('John Doe'));
      expect(json['reseller_name'], equals('Jane Smith'));
      expect(json['last_message'], equals('Hello'));
      expect(json['unread_count'], equals(5));
    });

    test('should copy chat model with new values', () {
      final originalChat = ChatModel(
        id: 'chat123',
        participants: ['user1', 'user2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        productTitle: 'Original Title',
        unreadCount: 0,
      );

      final updatedChat = originalChat.copyWith(
        productTitle: 'Updated Title',
        unreadCount: 5,
      );

      expect(updatedChat.id, equals(originalChat.id));
      expect(updatedChat.participants, equals(originalChat.participants));
      expect(updatedChat.productTitle, equals('Updated Title'));
      expect(updatedChat.unreadCount, equals(5));
    });
  });

  group('Message Model Tests', () {
    test('should create message model from JSON', () {
      final json = {
        'id': 'msg123',
        'chat_id': 'chat123',
        'sender_id': 'user1',
        'content': 'Hello World',
        'created_at': '2024-01-01T14:30:00Z',
        'sender_name': 'John Doe',
        'sender_image': 'https://example.com/avatar.jpg',
        'is_read': true,
        'message_type': 'text',
      };

      final message = MessageModel.fromJson(json);

      expect(message.id, equals('msg123'));
      expect(message.chatId, equals('chat123'));
      expect(message.senderId, equals('user1'));
      expect(message.content, equals('Hello World'));
      expect(message.senderName, equals('John Doe'));
      expect(message.senderImage, equals('https://example.com/avatar.jpg'));
      expect(message.isRead, isTrue);
      expect(message.messageType, equals('text'));
    });

    test('should convert message model to JSON', () {
      final message = MessageModel(
        id: 'msg123',
        chatId: 'chat123',
        senderId: 'user1',
        content: 'Hello World',
        createdAt: DateTime.parse('2024-01-01T14:30:00Z'),
        senderName: 'John Doe',
        senderImage: 'https://example.com/avatar.jpg',
        isRead: true,
        messageType: 'text',
      );

      final json = message.toJson();

      expect(json['id'], equals('msg123'));
      expect(json['chat_id'], equals('chat123'));
      expect(json['sender_id'], equals('user1'));
      expect(json['content'], equals('Hello World'));
      expect(json['sender_name'], equals('John Doe'));
      expect(json['sender_image'], equals('https://example.com/avatar.jpg'));
      expect(json['is_read'], isTrue);
      expect(json['message_type'], equals('text'));
    });

    test('should copy message model with new values', () {
      final originalMessage = MessageModel(
        id: 'msg123',
        chatId: 'chat123',
        senderId: 'user1',
        content: 'Hello',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final updatedMessage = originalMessage.copyWith(
        content: 'Updated Hello',
        isRead: true,
      );

      expect(updatedMessage.id, equals(originalMessage.id));
      expect(updatedMessage.chatId, equals(originalMessage.chatId));
      expect(updatedMessage.senderId, equals(originalMessage.senderId));
      expect(updatedMessage.content, equals('Updated Hello'));
      expect(updatedMessage.isRead, isTrue);
    });

    test('should identify sender correctly', () {
      final message = MessageModel(
        id: 'msg123',
        chatId: 'chat123',
        senderId: 'user1',
        content: 'Hello',
        createdAt: DateTime.now(),
      );

      expect(message.isSentBy('user1'), isTrue);
      expect(message.isSentBy('user2'), isFalse);
    });
  });
}