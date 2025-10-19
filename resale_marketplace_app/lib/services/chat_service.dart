import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../utils/uuid.dart';

class ChatService {
  ChatService({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  final Map<String, StreamSubscription> _subscriptions = {};
  static bool _isGetUserChatsRpcAvailable = true;
  static bool _isGetChatMessagesRpcAvailable = true;

  // 채팅방 생성 (대신팔기 지원)
  Future<ChatModel?> createChat({
    required List<String> participants,
    String? productId,
    String? resellerId, // 대신판매자 ID
    bool isResaleChat = false,
    String? originalSellerId, // 원 판매자 ID
    Map<String, dynamic>? extraData, // 추가 메타데이터
  }) async {
    try {
      // Validate participants (must all be UUIDs)
      final validParticipants = participants.where(UuidUtils.isValid).toList();
      if (validParticipants.length != participants.length) {
        throw Exception('잘못된 사용자 ID가 포함되어 있습니다. 다시 로그인 후 시도해주세요.');
      }

      // 이미 존재하는 채팅방 확인
      final existingChat = await _findExistingChat(
        validParticipants,
        productId,
        resellerId,
      );
      if (existingChat != null) return existingChat;

      final payload = <String, dynamic>{
        'participants': validParticipants,
        'is_resale_chat': isResaleChat,
      };
      if (productId != null && UuidUtils.isValid(productId)) {
        payload['product_id'] = productId;
      }
      if (resellerId != null && UuidUtils.isValid(resellerId)) {
        payload['reseller_id'] = resellerId;
      }
      if (originalSellerId != null && UuidUtils.isValid(originalSellerId)) {
        payload['original_seller_id'] = originalSellerId;
      }

      final response = await _client
          .from('chats')
          .insert(payload)
          .select()
          .single();

      final chat = ChatModel.fromJson(response);

      // 대신팔기 채팅방인 경우 시스템 메시지 추가
      if (isResaleChat && resellerId != null) {
        // 대신판매자와 원 판매자 정보 가져오기
        final resellerInfo = extraData?['reseller_name'] ?? '대신판매자';
        final originalSellerInfo = extraData?['original_seller_name'] ?? '원 판매자';
        
        await sendSystemMessage(
          chatId: chat.id,
          content:
              '🏪 대신팔기 거래 안내\n\n'
              '${resellerInfo}님이 ${originalSellerInfo}님을 대신하여 판매중입니다.\n'
              '• 대신판매자가 거래를 중개합니다\n'
              '• 상품은 원 판매자가 직접 발송합니다\n'
              '• 거래 시 대신판매 수수료가 적용됩니다',
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

      if (productId != null && UuidUtils.isValid(productId)) {
        query = query.eq('product_id', productId);
      }

      // 대신팔기 채팅방 구분
      if (resellerId != null && UuidUtils.isValid(resellerId)) {
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
      if (!UuidUtils.isValid(chatId)) {
        print('getChatById skipped: invalid UUID "$chatId"');
        return null;
      }
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
      if (response['messages'] != null &&
          (response['messages'] as List).isNotEmpty) {
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

  // 내 채팅방 목록 조회 (최적화된 버전)
  Future<List<ChatModel>> getMyChats(String userId) async {
    try {
      // Guard: avoid Postgres 22P02 when userId is not a UUID
      if (!UuidUtils.isValid(userId)) {
        print('getMyChats skipped: invalid UUID "$userId"');
        return [];
      }
      if (!_isGetUserChatsRpcAvailable) {
        return await _getMyChatsBasic(userId);
      }
      // 데이터베이스 함수를 사용하여 최적화된 쿼리 실행
      final response = await _client.rpc(
        'get_user_chats',
        params: {'user_id': userId},
      );

      return (response as List).map((item) {
        return ChatModel.fromJson({
          'id': item['chat_id'],
          'participants': item['participants'],
          'product_id': item['product_id'],
          'reseller_id': item['reseller_id'],
          'is_resale_chat': item['is_resale_chat'],
          'original_seller_id': item['original_seller_id'],
          'created_at': item['created_at'],
          'updated_at': item['updated_at'],
          'product_title': item['product_title'],
          'product_image': item['product_image'],
          'product_price': item['product_price'],
          'last_message': item['last_message'],
          'last_message_time': item['last_message_time'],
          'unread_count': item['unread_count'],
        });
      }).toList();
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST202') {
        _isGetUserChatsRpcAvailable = false;
        print(
          'get_user_chats rpc unavailable — falling back to basic chat query.',
        );
        return await _getMyChatsBasic(userId);
      }
      print('Error getting my chats: $e');
      // Fallback to basic query if function fails
      return await _getMyChatsBasic(userId);
    }
  }

  // 기본 채팅방 목록 조회 (fallback) - 최적화 버전
  Future<List<ChatModel>> _getMyChatsBasic(String userId) async {
    try {
      // 1️⃣ 채팅방 정보와 상품 정보를 JOIN으로 한번에 가져오기
      final chatsResponse = await _client
          .from('chats')
          .select('*, products(title, images, price)')
          .contains('participants', [userId])
          .order('updated_at', ascending: false);

      if ((chatsResponse as List).isEmpty) return [];

      // 2️⃣ 모든 채팅방 ID 수집
      final chatIds = (chatsResponse as List)
          .map((chat) => chat['id'] as String)
          .where(UuidUtils.isValid)
          .toList();

      if (chatIds.isEmpty) return [];

      // 3️⃣ 마지막 메시지들을 한번에 가져오기 (DISTINCT ON 사용)
      final messagesResponse = await _client
          .from('messages')
          .select('id, chat_id, content, created_at, sender_id')
          .inFilter('chat_id', chatIds)
          .order('chat_id')
          .order('created_at', ascending: false);

      // 각 채팅방별 마지막 메시지 매핑
      final Map<String, Map<String, dynamic>> lastMessageMap = {};
      for (final msg in messagesResponse as List) {
        final chatId = msg['chat_id'] as String;
        if (!lastMessageMap.containsKey(chatId)) {
          lastMessageMap[chatId] = msg;
        }
      }

      // 4️⃣ 읽지 않은 메시지 개수를 한번에 가져오기
      final readStatusResponse = await _client
          .from('user_chat_read_status')
          .select('chat_id, last_read_at')
          .eq('user_id', userId)
          .inFilter('chat_id', chatIds);

      // 읽음 상태 매핑
      final Map<String, DateTime> readStatusMap = {};
      for (final status in readStatusResponse as List) {
        final chatId = status['chat_id'] as String;
        final lastReadAt = status['last_read_at'] != null
            ? DateTime.parse(status['last_read_at'])
            : DateTime.fromMillisecondsSinceEpoch(0);
        readStatusMap[chatId] = lastReadAt;
      }

      // 5️⃣ 읽지 않은 메시지 개수 계산 (메모리에서 처리)
      final Map<String, int> unreadCountMap = {};
      for (final msg in messagesResponse as List) {
        final chatId = msg['chat_id'] as String;
        final senderId = msg['sender_id'] as String;
        final createdAt = DateTime.parse(msg['created_at']);
        final lastReadAt = readStatusMap[chatId] ?? DateTime.fromMillisecondsSinceEpoch(0);

        // 다른 사용자가 보낸 메시지이고, 마지막 읽음 시간 이후인 경우
        if (senderId != userId && createdAt.isAfter(lastReadAt)) {
          unreadCountMap[chatId] = (unreadCountMap[chatId] ?? 0) + 1;
        }
      }

      // 6️⃣ 최종 데이터 조합
      List<ChatModel> chats = [];
      for (final item in chatsResponse as List) {
        final chat = ChatModel.fromJson(item);
        final chatId = chat.id;

        // 상품 정보 추가
        ChatModel updatedChat = chat;
        if (item['products'] != null) {
          final product = item['products'];
          updatedChat = chat.copyWith(
            productTitle: product['title'],
            productImage: product['images']?.isNotEmpty == true
                ? product['images'][0]
                : null,
            productPrice: product['price'],
          );
        }

        // 마지막 메시지와 읽지 않은 개수 추가
        final lastMsg = lastMessageMap[chatId];
        if (lastMsg != null) {
          updatedChat = updatedChat.copyWith(
            lastMessage: lastMsg['content'],
            lastMessageTime: DateTime.parse(lastMsg['created_at']),
            unreadCount: unreadCountMap[chatId] ?? 0,
          );
        }

        chats.add(updatedChat);
      }

      return chats;
    } catch (e) {
      print('Error getting basic chats: $e');
      return [];
    }
  }

  // 마지막 메시지 조회
  Future<MessageModel?> _getLastMessage(String chatId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return MessageModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error getting last message: $e');
      return null;
    }
  }

  // 읽지 않은 메시지 개수 조회
  Future<int> _getUnreadCount(String chatId, String userId) async {
    try {
      // Guard: avoid invalid uuid errors
      if (!UuidUtils.isValid(chatId) || !UuidUtils.isValid(userId)) {
        print(
          'getUnreadCount skipped: invalid UUID chatId="$chatId" userId="$userId"',
        );
        return 0;
      }
      // 사용자의 마지막 읽음 시간 조회
      final readStatus = await _client
          .from('user_chat_read_status')
          .select('last_read_at')
          .eq('user_id', userId)
          .eq('chat_id', chatId)
          .maybeSingle();

      final lastReadAt =
          readStatus != null && readStatus['last_read_at'] != null
          ? DateTime.parse(readStatus['last_read_at'])
          : DateTime.fromMillisecondsSinceEpoch(0);

      // 마지막 읽음 시간 이후의 다른 사용자 메시지 개수
      final response = await _client
          .from('messages')
          .select('*')
          .eq('chat_id', chatId)
          .neq('sender_id', userId)
          .gt('created_at', lastReadAt.toIso8601String());

      return (response as List).length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
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
      final response = await _client
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': senderId,
            'content': content,
            'message_type': messageType,
          })
          .select()
          .single();

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

  // 채팅방 메시지 목록 조회 (최적화된 버전)
  Future<List<MessageModel>> getChatMessages(
    String chatId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (!UuidUtils.isValid(chatId)) {
        print('getChatMessages skipped: invalid UUID "$chatId"');
        return [];
      }
      if (!_isGetChatMessagesRpcAvailable) {
        return await _getChatMessagesBasic(
          chatId,
          limit: limit,
          offset: offset,
        );
      }
      // 데이터베이스 함수를 사용하여 최적화된 쿼리 실행
      final response = await _client.rpc(
        'get_chat_messages',
        params: {
          'chat_id_param': chatId,
          'limit_param': limit,
          'offset_param': offset,
        },
      );

      return (response as List)
          .map((item) {
            return MessageModel.fromJson({
              'id': item['message_id'],
              'chat_id': item['chat_id'],
              'sender_id': item['sender_id'],
              'content': item['content'],
              'message_type': item['message_type'],
              'created_at': item['created_at'],
              'sender_name': item['sender_name'],
              'sender_image': item['sender_profile_image'],
            });
          })
          .toList()
          .reversed
          .toList(); // 시간순으로 정렬
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST202') {
        _isGetChatMessagesRpcAvailable = false;
        print(
          'get_chat_messages rpc unavailable — falling back to basic messages query.',
        );
        return await _getChatMessagesBasic(
          chatId,
          limit: limit,
          offset: offset,
        );
      }
      print('Error getting chat messages with function: $e');
      // Fallback to basic query
      return await _getChatMessagesBasic(chatId, limit: limit, offset: offset);
    }
  }

  // 기본 메시지 조회 (fallback)
  Future<List<MessageModel>> _getChatMessagesBasic(
    String chatId, {
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

      return (response as List)
          .map((item) {
            final message = MessageModel.fromJson(item);

            // 발송자 정보
            if (item['users'] != null) {
              return message.copyWith(
                senderName: item['users']['name'],
                senderImage: item['users']['profile_image'],
              );
            }

            return message;
          })
          .toList()
          .reversed
          .toList(); // 시간순으로 정렬
    } catch (e) {
      print('Error getting basic chat messages: $e');
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

    if (!UuidUtils.isValid(chatId)) {
      print('subscribeToChat skipped: invalid UUID "$chatId"');
      final sub = Stream<List<Map<String, dynamic>>>.empty().listen((_) {});
      _subscriptions[chatId] = sub;
      return sub;
    }

    // 새 구독 생성 - Supabase Realtime을 사용한 실시간 구독
    final subscription = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            // 새로운 메시지들을 처리
            for (final messageData in data) {
              try {
                final message = MessageModel.fromJson(messageData);
                onNewMessage(message);
              } catch (e) {
                print('Error parsing message: $e');
              }
            }
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
  Future<String?> uploadChatImage(
    File imageFile,
    String chatId,
    String userId,
  ) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName =
          'chat_${chatId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _client.storage.from('chat-images').uploadBinary(fileName, bytes);

      final url = _client.storage.from('chat-images').getPublicUrl(fileName);

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
        await _client.from('chats').delete().eq('id', chatId);
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

  // 채팅방 읽음 상태 업데이트
  Future<void> markChatAsRead(String chatId, String userId) async {
    try {
      // Guard: avoid invalid uuid errors
      if (!UuidUtils.isValid(chatId) || !UuidUtils.isValid(userId)) {
        print(
          'markChatAsRead skipped: invalid UUID chatId="$chatId" userId="$userId"',
        );
        return;
      }
      await _client.from('user_chat_read_status').upsert({
        'user_id': userId,
        'chat_id': chatId,
        'last_read_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }

  // 채팅방 참여자 정보 조회
  Future<List<Map<String, dynamic>>> getChatParticipants(String chatId) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) return [];

      final response = await _client
          .from('users')
          .select('id, name, profile_image')
          .inFilter('id', chat.participants);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('Error getting chat participants: $e');
      return [];
    }
  }

  // 채팅방 온라인 상태 확인 (실시간 presence)
  Future<Map<String, bool>> getChatPresence(String chatId) async {
    try {
      // Supabase Realtime Presence를 사용하여 온라인 상태 확인
      // 실제 구현에서는 Presence API를 사용해야 함
      final chat = await getChatById(chatId);
      if (chat == null) return {};

      // 임시로 모든 참여자를 온라인으로 표시 (실제로는 Presence API 사용)
      Map<String, bool> presence = {};
      for (String userId in chat.participants) {
        presence[userId] = true; // 실제로는 Presence 상태 확인
      }

      return presence;
    } catch (e) {
      print('Error getting chat presence: $e');
      return {};
    }
  }

  // 타이핑 상태 전송
  Future<void> sendTypingStatus(
    String chatId,
    String userId,
    bool isTyping,
  ) async {
    try {
      // Supabase Realtime Broadcast를 사용하여 타이핑 상태 전송
      final channel = _client.channel('chat:$chatId');

      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': userId,
          'is_typing': isTyping,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error sending typing status: $e');
    }
  }

  // 타이핑 상태 구독
  void subscribeToTyping(
    String chatId,
    Function(String userId, bool isTyping) onTypingChange,
  ) {
    try {
      final channel = _client.channel('chat:$chatId');

      channel.onBroadcast(
        event: 'typing',
        callback: (payload) {
          final userId = payload['user_id'] as String?;
          final isTyping = payload['is_typing'] as bool?;

          if (userId != null && isTyping != null) {
            onTypingChange(userId, isTyping);
          }
        },
      );

      channel.subscribe();
    } catch (e) {
      print('Error subscribing to typing: $e');
    }
  }

  // 채팅방 통계 조회
  Future<Map<String, dynamic>> getChatStats(String chatId) async {
    try {
      final allMessages = await _client
          .from('messages')
          .select('message_type')
          .eq('chat_id', chatId);

      final totalMessages = (allMessages as List).length;
      final imageMessages = allMessages
          .where((m) => m['message_type'] == 'image')
          .length;
      final textMessages = totalMessages - imageMessages;

      return {
        'total_messages': totalMessages,
        'image_messages': imageMessages,
        'text_messages': textMessages,
      };
    } catch (e) {
      print('Error getting chat stats: $e');
      return {'total_messages': 0, 'image_messages': 0, 'text_messages': 0};
    }
  }

  // 리소스 정리
  void dispose() {
    unsubscribeAll();
  }
}
