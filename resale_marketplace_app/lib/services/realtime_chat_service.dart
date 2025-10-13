import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';
import '../models/user_model.dart';

enum ChatEventType {
  messageReceived,
  messageDelivered,
  messageRead,
  typing,
  stopTyping,
  userOnline,
  userOffline,
}

class ChatEvent {
  final ChatEventType type;
  final dynamic data;
  final String? userId;
  final DateTime timestamp;

  ChatEvent({
    required this.type,
    required this.data,
    this.userId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class RealtimeChatService {
  static final RealtimeChatService _instance = RealtimeChatService._internal();
  factory RealtimeChatService() => _instance;
  RealtimeChatService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _chatChannel;
  RealtimeChannel? _presenceChannel;

  final Map<String, RealtimeChannel> _roomChannels = {};
  final Map<String, Timer> _typingTimers = {};
  final Map<String, Set<String>> _onlineUsers = {};

  final StreamController<ChatEvent> _eventController =
      StreamController<ChatEvent>.broadcast();

  Stream<ChatEvent> get eventStream => _eventController.stream;

  /// 실시간 채팅 초기화
  Future<void> initialize() async {
    try {
      developer.log('Initializing realtime chat service');

      // 전역 presence 채널 설정
      await _setupPresenceChannel();

      developer.log('Realtime chat service initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize realtime chat: $e');
      rethrow;
    }
  }

  /// Presence 채널 설정 (온라인 상태 관리)
  Future<void> _setupPresenceChannel() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _presenceChannel = _supabase.channel('presence')
      ..onPresenceSync((payload) {
        // For now, just pass empty data to avoid errors
        _handlePresenceSync({});
      })
      ..onPresenceJoin((payload) {
        // For now, just pass empty data to avoid errors
        _handlePresenceJoin({});
      })
      ..onPresenceLeave((payload) {
        // For now, just pass empty data to avoid errors
        _handlePresenceLeave({});
      })
      ..subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _presenceChannel?.track({
            'user_id': user.id,
            'online_at': DateTime.now().toIso8601String(),
          });
        }
      });
  }

  /// 채팅방 입장
  Future<void> joinChatRoom(String roomId) async {
    try {
      developer.log('Joining chat room: $roomId');

      if (_roomChannels.containsKey(roomId)) {
        developer.log('Already in chat room: $roomId');
        return;
      }

      final channel = _supabase.channel('chat_room_$roomId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_room_id',
            value: roomId,
          ),
          callback: (payload) => _handleNewMessage(payload),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_room_id',
            value: roomId,
          ),
          callback: (payload) => _handleMessageUpdate(payload),
        )
        ..onBroadcast(
          event: 'typing',
          callback: (payload) => _handleTypingEvent(payload),
        )
        ..onBroadcast(
          event: 'stop_typing',
          callback: (payload) => _handleStopTypingEvent(payload),
        )
        ..subscribe();

      _roomChannels[roomId] = channel;

      // 채팅방 읽음 상태 업데이트
      await _markRoomAsRead(roomId);

      developer.log('Successfully joined chat room: $roomId');
    } catch (e) {
      developer.log('Failed to join chat room $roomId: $e');
      rethrow;
    }
  }

  /// 채팅방 나가기
  Future<void> leaveChatRoom(String roomId) async {
    try {
      developer.log('Leaving chat room: $roomId');

      final channel = _roomChannels[roomId];
      if (channel != null) {
        await channel.unsubscribe();
        _roomChannels.remove(roomId);
      }

      // 타이핑 타이머 정리
      _typingTimers[roomId]?.cancel();
      _typingTimers.remove(roomId);

      developer.log('Successfully left chat room: $roomId');
    } catch (e) {
      developer.log('Failed to leave chat room $roomId: $e');
    }
  }

  /// 메시지 전송
  Future<ChatMessageModel?> sendMessage({
    required String roomId,
    required String content,
    required String messageType,
    List<String>? imageUrls,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');

      final messageData = {
        'chat_room_id': roomId,
        'sender_id': user.id,
        'content': content,
        'message_type': messageType,
        'image_urls': imageUrls ?? <String>[],
        'metadata': metadata ?? <String, dynamic>{},
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      };

      final response = await _supabase
          .from('chat_messages')
          .insert(messageData)
          .select('*, sender:sender_id(*)')
          .single();

      // 타이핑 중지 브로드캐스트
      await stopTyping(roomId);

      return ChatMessageModel.fromJson(response);
    } catch (e) {
      developer.log('Failed to send message: $e');
      rethrow;
    }
  }

  /// 이미지 메시지 전송
  Future<ChatMessageModel?> sendImageMessage({
    required String roomId,
    required List<String> imageUrls,
    String? caption,
  }) async {
    return await sendMessage(
      roomId: roomId,
      content: caption ?? '',
      messageType: 'image',
      imageUrls: imageUrls,
    );
  }

  /// 타이핑 시작
  Future<void> startTyping(String roomId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final channel = _roomChannels[roomId];
      if (channel == null) return;

      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': user.id,
          'room_id': roomId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // 타이핑 타이머 설정 (3초 후 자동으로 중지)
      _typingTimers[roomId]?.cancel();
      _typingTimers[roomId] = Timer(const Duration(seconds: 3), () {
        stopTyping(roomId);
      });
    } catch (e) {
      developer.log('Failed to start typing: $e');
    }
  }

  /// 타이핑 중지
  Future<void> stopTyping(String roomId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final channel = _roomChannels[roomId];
      if (channel == null) return;

      await channel.sendBroadcastMessage(
        event: 'stop_typing',
        payload: {
          'user_id': user.id,
          'room_id': roomId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _typingTimers[roomId]?.cancel();
      _typingTimers.remove(roomId);
    } catch (e) {
      developer.log('Failed to stop typing: $e');
    }
  }

  /// 메시지 읽음 처리
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _supabase
          .from('chat_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
    } catch (e) {
      developer.log('Failed to mark message as read: $e');
    }
  }

  /// 채팅방 전체 읽음 처리
  Future<void> _markRoomAsRead(String roomId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('chat_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('chat_room_id', roomId)
          .neq('sender_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      developer.log('Failed to mark room as read: $e');
    }
  }

  /// 온라인 사용자 목록 가져오기
  Set<String> getOnlineUsers(String roomId) {
    return _onlineUsers[roomId] ?? {};
  }

  /// 사용자 온라인 상태 확인
  bool isUserOnline(String userId) {
    return _onlineUsers.values.any((users) => users.contains(userId));
  }

  // Event Handlers
  void _handleNewMessage(PostgresChangePayload payload) {
    try {
      final messageData = payload.newRecord;
      final message = ChatMessageModel.fromJson(messageData);

      _eventController.add(
        ChatEvent(
          type: ChatEventType.messageReceived,
          data: message,
          userId: message.senderId,
        ),
      );
    } catch (e) {
      developer.log('Failed to handle new message: $e');
    }
  }

  void _handleMessageUpdate(PostgresChangePayload payload) {
    try {
      final messageData = payload.newRecord;
      final message = ChatMessageModel.fromJson(messageData);

      if (message.isRead) {
        _eventController.add(
          ChatEvent(
            type: ChatEventType.messageRead,
            data: message,
            userId: message.senderId,
          ),
        );
      }
    } catch (e) {
      developer.log('Failed to handle message update: $e');
    }
  }

  void _handleTypingEvent(Map<String, dynamic> payload) {
    try {
      final userId = payload['user_id'] as String?;
      if (userId != null) {
        _eventController.add(
          ChatEvent(type: ChatEventType.typing, data: payload, userId: userId),
        );
      }
    } catch (e) {
      developer.log('Failed to handle typing event: $e');
    }
  }

  void _handleStopTypingEvent(Map<String, dynamic> payload) {
    try {
      final userId = payload['user_id'] as String?;
      if (userId != null) {
        _eventController.add(
          ChatEvent(
            type: ChatEventType.stopTyping,
            data: payload,
            userId: userId,
          ),
        );
      }
    } catch (e) {
      developer.log('Failed to handle stop typing event: $e');
    }
  }

  void _handlePresenceSync(Map<String, List<Map<String, dynamic>>> payload) {
    try {
      final onlineUserIds = payload.values
          .expand((presences) => presences)
          .map((p) => p['user_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      // 모든 채팅방에 온라인 사용자 업데이트
      for (final roomId in _roomChannels.keys) {
        _onlineUsers[roomId] = onlineUserIds;
      }

      _eventController.add(
        ChatEvent(type: ChatEventType.userOnline, data: onlineUserIds.toList()),
      );
    } catch (e) {
      developer.log('Failed to handle presence sync: $e');
    }
  }

  void _handlePresenceJoin(Map<String, List<Map<String, dynamic>>> payload) {
    try {
      final newPresences = payload['joins'] ?? [];
      if (newPresences.isNotEmpty) {
        final userId = newPresences.first['user_id'] as String?;
        if (userId != null) {
          _eventController.add(
            ChatEvent(
              type: ChatEventType.userOnline,
              data: userId,
              userId: userId,
            ),
          );
        }
      }
    } catch (e) {
      developer.log('Failed to handle presence join: $e');
    }
  }

  void _handlePresenceLeave(Map<String, List<Map<String, dynamic>>> payload) {
    try {
      final leftPresences = payload['leaves'] ?? [];
      if (leftPresences.isNotEmpty) {
        final userId = leftPresences.first['user_id'] as String?;
        if (userId != null) {
          _eventController.add(
            ChatEvent(
              type: ChatEventType.userOffline,
              data: userId,
              userId: userId,
            ),
          );
        }
      }
    } catch (e) {
      developer.log('Failed to handle presence leave: $e');
    }
  }

  /// 서비스 종료
  Future<void> dispose() async {
    try {
      // 모든 채팅방 나가기
      final roomIds = List<String>.from(_roomChannels.keys);
      for (final roomId in roomIds) {
        await leaveChatRoom(roomId);
      }

      // Presence 채널 해제
      await _presenceChannel?.unsubscribe();
      _presenceChannel = null;

      // 타이머 정리
      for (final timer in _typingTimers.values) {
        timer.cancel();
      }
      _typingTimers.clear();

      // 스트림 컨트롤러 종료
      await _eventController.close();

      developer.log('Realtime chat service disposed');
    } catch (e) {
      developer.log('Failed to dispose realtime chat service: $e');
    }
  }
}
