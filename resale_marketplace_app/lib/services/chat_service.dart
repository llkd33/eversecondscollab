import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final SupabaseClient _client = SupabaseConfig.client;
  final Map<String, StreamSubscription> _subscriptions = {};

  // 채팅방 생성 (대신팔기 지원)
  Future<ChatModel?> createChat({
    required List<String> participants,
    String? productId,
    String? resellerId, // 대신판매자 ID
    bool isResaleChat = false,
    String? originalSellerId, // 원 판매자 ID
  }) async {
    try {
      // 이미 존재하는 채팅방 확인
      final existingChat = await _findExistingChat(participants, productId, resellerId);
      if (existingChat != null) return existingChat;

      final response = await _client.from('chats').insert({
        'participants': participants,
        'product_id': productId,
        'reseller_id': resellerId,
        'is_resale_chat': isResaleChat,
        'original_seller_id': originalSellerId,
      }).select().single();

      final chat = ChatModel.fromJson(response);

      // 대신팔기 채팅방인 경우 시스템 메시지 추가
      if (isResaleChat && resellerId != null) {
        await sendSystemMessage(
          chatId: chat.id,
          content: '🔔 대신팔기 채팅방 안내\n\n'
              '이 채팅방은 대신팔기 상품 거래를 위한 채팅방입니다.\n'
              '대신판매자가 원 판매자를 대신하여 상품을 판매하고 있습니다.\n'
              '거래 시 대신판매 수수료가 적용됩니다.',
        );
      }

      return chat;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

  // 기존 채팅방 찾기 (대신팔기 지원)
  Future<ChatModel?> _findExistingChat(
    List<String> participants, 
    String? productId,
    String? resellerId,
  ) async {
    try {
      var query = _client
          .from('chats')
          .select()
          .contains('participants', participants);
      
      if (productId != null) {
        query = query.eq('product_id', productId);
      }

      // 대신팔기 채팅방 구분
      if (resellerId != null) {
        query = query.eq('reseller_id', resellerId);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;
      
      return ChatModel.fromJson(response);
    } catch (e) {
      print('Error finding existing chat: $e');
      return null;
    }
  }

  // 채팅방 ID로 조회
  Future<ChatModel?> getChatById(String chatId) async {
    try {
      final response = await _client
          .from('chats')
          .select('*, products(title, images), messages(content, created_at)')
          .eq('id', chatId)
          .single();

      final chat = ChatModel.fromJson(response);
      
      // 추가 정보 설정
      if (response['products'] != null) {
        final product = response['products'];
        return chat.copyWith(
          productTitle: product['title'],
          productImage: product['images']?.isNotEmpty == true 
              ? product['images'][0] 
              : null,
        );
      }
      
      // 마지막 메시지 정보
      if (response['messages'] != null && (response['messages'] as List).isNotEmpty) {
        final lastMsg = (response['messages'] as List).last;
        return chat.copyWith(
          lastMessage: lastMsg['content'],
          lastMessageTime: DateTime.parse(lastMsg['created_at']),
        );
      }
      
      return chat;
    } catch (e) {
      print('Error getting chat by id: $e');
      return null;
    }
  }

  // 내 채팅방 목록 조회
  Future<List<ChatModel>> getMyChats(String userId) async {
    try {
      final response = await _client
          .from('chats')
          .select('*, products(title, images), messages(content, created_at, sender_id)')
          .contains('participants', [userId])
          .order('updated_at', ascending: false);

      return (response as List).map((item) {
        final chat = ChatModel.fromJson(item);
        
        // 상품 정보
        if (item['products'] != null) {
          final product = item['products'];
          chat.copyWith(
            productTitle: product['title'],
            productImage: product['images']?.isNotEmpty == true 
                ? product['images'][0] 
                : null,
          );
        }
        
        // 마지막 메시지 정보
        if (item['messages'] != null && (item['messages'] as List).isNotEmpty) {
          final messages = item['messages'] as List;
          final lastMsg = messages.last;
          
          // 읽지 않은 메시지 개수
          final unreadCount = messages
              .where((m) => m['sender_id'] != userId)
              .length;
          
          return chat.copyWith(
            lastMessage: lastMsg['content'],
            lastMessageTime: DateTime.parse(lastMsg['created_at']),
            unreadCount: unreadCount,
          );
        }
        
        return chat;
      }).toList();
    } catch (e) {
      print('Error getting my chats: $e');
      return [];
    }
  }

  // 메시지 전송
  Future<MessageModel?> sendMessage({
    required String chatId,
    required String senderId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final response = await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': senderId,
        'content': content,
        'message_type': messageType,
      }).select().single();

      // 채팅방 업데이트 시간 갱신
      await _client
          .from('chats')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', chatId);

      return MessageModel.fromJson(response);
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // 채팅방 메시지 목록 조회
  Future<List<MessageModel>> getChatMessages(String chatId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('messages')
          .select('*, users!sender_id(name, profile_image)')
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((item) {
        final message = MessageModel.fromJson(item);
        
        // 발송자 정보
        if (item['users'] != null) {
          return message.copyWith(
            senderName: item['users']['name'],
            senderImage: item['users']['profile_image'],
          );
        }
        
        return message;
      }).toList().reversed.toList(); // 시간순으로 정렬
    } catch (e) {
      print('Error getting chat messages: $e');
      return [];
    }
  }

  // 실시간 메시지 구독
  StreamSubscription<List<Map<String, dynamic>>> subscribeToChat(
    String chatId,
    void Function(MessageModel) onNewMessage,
  ) {
    // 기존 구독 해제
    unsubscribeFromChat(chatId);

    // 새 구독 생성
    final subscription = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            // 가장 최근 메시지만 처리
            final latestMessage = MessageModel.fromJson(data.last);
            onNewMessage(latestMessage);
          }
        });

    _subscriptions[chatId] = subscription;
    return subscription;
  }

  // 채팅방 구독 해제
  void unsubscribeFromChat(String chatId) {
    _subscriptions[chatId]?.cancel();
    _subscriptions.remove(chatId);
  }

  // 모든 구독 해제
  void unsubscribeAll() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  // 시스템 메시지 전송
  Future<MessageModel?> sendSystemMessage({
    required String chatId,
    required String content,
  }) async {
    // 시스템 사용자 ID (특별한 ID 사용)
    const systemUserId = '00000000-0000-0000-0000-000000000000';
    
    return sendMessage(
      chatId: chatId,
      senderId: systemUserId,
      content: content,
      messageType: 'system',
    );
  }

  // 안전거래 시작 메시지
  Future<void> sendSafeTransactionStartMessage(
    String chatId, {
    String? resellerName,
  }) async {
    String message = '안전거래가 시작되었습니다.\n';
    
    if (resellerName != null) {
      message += SystemMessages.safeTransactionNotice(resellerName) + '\n';
    }
    
    message += SystemMessages.safeTransactionGuide + '\n';
    message += SystemMessages.depositGuide;
    
    await sendSystemMessage(chatId: chatId, content: message);
  }

  // 입금 확인 메시지
  Future<void> sendDepositConfirmedMessage(String chatId) async {
    await sendSystemMessage(
      chatId: chatId,
      content: SystemMessages.depositConfirmed,
    );
  }

  // 배송 시작 메시지
  Future<void> sendShippingStartedMessage(String chatId) async {
    await sendSystemMessage(
      chatId: chatId,
      content: SystemMessages.shippingStarted,
    );
  }

  // 거래 완료 메시지
  Future<void> sendTransactionCompletedMessage(String chatId) async {
    await sendSystemMessage(
      chatId: chatId,
      content: SystemMessages.transactionCompleted,
    );
  }

  // 채팅 이미지 업로드
  Future<String?> uploadChatImage(File imageFile, String chatId, String userId) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName = 'chat_${chatId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _client.storage
          .from('chat-images')
          .uploadBinary(fileName, bytes);

      final url = _client.storage
          .from('chat-images')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      print('Error uploading chat image: $e');
      return null;
    }
  }

  // 채팅방 나가기
  Future<bool> leaveChat(String chatId, String userId) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) return false;

      final updatedParticipants = chat.participants
          .where((id) => id != userId)
          .toList();

      if (updatedParticipants.isEmpty) {
        // 모든 참가자가 나가면 채팅방 삭제
        await _client
            .from('chats')
            .delete()
            .eq('id', chatId);
      } else {
        // 참가자 목록 업데이트
        await _client
            .from('chats')
            .update({'participants': updatedParticipants})
            .eq('id', chatId);
      }

      unsubscribeFromChat(chatId);
      return true;
    } catch (e) {
      print('Error leaving chat: $e');
      return false;
    }
  }

  // 리소스 정리
  void dispose() {
    unsubscribeAll();
  }
}

// 시스템 메시지 상수
class SystemMessages {
  static const String safeTransactionGuide = '''
안전거래 진행 순서:
1. 구매자가 입금
2. 판매자가 입금 확인
3. 판매자가 상품 발송
4. 구매자가 상품 수령 확인
5. 거래 완료
''';

  static const String depositGuide = '''
💳 입금 계좌 정보
은행: 우리은행
계좌번호: 1002-XXX-XXXXXX
예금주: 에버세컨즈
금액: 거래 금액 + 수수료
''';

  static String safeTransactionNotice(String resellerName) => '''
🔔 대신판매 안내
$resellerName님이 판매를 대행하고 있습니다.
대신판매 수수료가 추가됩니다.
''';

  static const String depositConfirmed = '''
✅ 입금이 확인되었습니다.
판매자에게 배송 준비를 요청했습니다.
''';

  static const String shippingStarted = '''
📦 상품이 발송되었습니다.
운송장 번호를 확인해주세요.
''';

  static const String transactionCompleted = '''
🎉 거래가 완료되었습니다!
리뷰를 남겨주시면 다른 구매자에게 도움이 됩니다.
''';
}