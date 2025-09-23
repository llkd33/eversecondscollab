import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../models/user_model.dart';
import '../services/realtime_chat_service.dart';
import '../services/push_notification_service.dart';

/// 실시간 기능을 위한 상태 관리 Provider
class RealtimeProvider with ChangeNotifier {
  RealtimeProvider({
    RealtimeChatService? realtimeChatService,
    PushNotificationService? pushNotificationService,
  }) : _realtimeChatService = realtimeChatService ?? RealtimeChatService(),
       _pushNotificationService =
           pushNotificationService ?? PushNotificationService();

  final RealtimeChatService _realtimeChatService;
  final PushNotificationService _pushNotificationService;

  // 채팅 관련 상태
  final Map<String, List<ChatMessageModel>> _chatMessages = {};
  final Map<String, Set<String>> _onlineUsers = {};
  final Map<String, Set<String>> _typingUsers = {};
  final Set<String> _activeChatRooms = {};

  // 알림 관련 상태
  final List<NotificationPayload> _notifications = [];
  int _unreadNotificationCount = 0;

  // 연결 상태
  bool _isConnected = false;
  bool _isInitialized = false;

  StreamSubscription? _chatEventSubscription;
  StreamSubscription? _notificationSubscription;

  // Getters
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  int get unreadNotificationCount => _unreadNotificationCount;
  List<NotificationPayload> get notifications =>
      List.unmodifiable(_notifications);
  Set<String> get activeChatRooms => Set.unmodifiable(_activeChatRooms);

  /// 특정 채팅방의 메시지 목록
  List<ChatMessageModel> getChatMessages(String roomId) {
    return List.unmodifiable(_chatMessages[roomId] ?? []);
  }

  /// 특정 채팅방의 온라인 사용자 목록
  Set<String> getOnlineUsers(String roomId) {
    return Set.unmodifiable(_onlineUsers[roomId] ?? {});
  }

  /// 특정 채팅방의 타이핑 중인 사용자 목록
  Set<String> getTypingUsers(String roomId) {
    return Set.unmodifiable(_typingUsers[roomId] ?? {});
  }

  /// 사용자 온라인 상태 확인
  bool isUserOnline(String userId) {
    return _realtimeChatService.isUserOnline(userId);
  }

  /// 사용자 타이핑 상태 확인
  bool isUserTyping(String roomId, String userId) {
    return _typingUsers[roomId]?.contains(userId) ?? false;
  }

  /// 실시간 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log('Initializing realtime provider');

      // 실시간 채팅 서비스 초기화
      await _realtimeChatService.initialize();

      // 푸시 알림 서비스 초기화
      await _pushNotificationService.initialize();

      // 이벤트 리스너 설정
      _setupEventListeners();

      _isConnected = true;
      _isInitialized = true;

      developer.log('Realtime provider initialized successfully');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to initialize realtime provider: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 이벤트 리스너 설정
  void _setupEventListeners() {
    // 채팅 이벤트 리스너
    _chatEventSubscription = _realtimeChatService.eventStream.listen(
      _handleChatEvent,
      onError: (error) {
        developer.log('Chat event error: $error');
        _isConnected = false;
        notifyListeners();
      },
    );

    // 푸시 알림 이벤트 리스너
    _notificationSubscription = _pushNotificationService.notificationStream
        .listen(
          _handleNotificationEvent,
          onError: (error) {
            developer.log('Notification event error: $error');
          },
        );
  }

  /// 채팅 이벤트 처리
  void _handleChatEvent(ChatEvent event) {
    switch (event.type) {
      case ChatEventType.messageReceived:
        _handleMessageReceived(event.data as ChatMessageModel);
        break;
      case ChatEventType.messageDelivered:
        _handleMessageDelivered(event.data as ChatMessageModel);
        break;
      case ChatEventType.messageRead:
        _handleMessageRead(event.data as ChatMessageModel);
        break;
      case ChatEventType.typing:
        _handleTypingEvent(event);
        break;
      case ChatEventType.stopTyping:
        _handleStopTypingEvent(event);
        break;
      case ChatEventType.userOnline:
        _handleUserOnlineEvent(event);
        break;
      case ChatEventType.userOffline:
        _handleUserOfflineEvent(event);
        break;
    }
  }

  /// 새 메시지 수신 처리
  void _handleMessageReceived(ChatMessageModel message) {
    final roomId = message.chatRoomId;

    if (!_chatMessages.containsKey(roomId)) {
      _chatMessages[roomId] = [];
    }

    // 중복 메시지 확인
    final existingIndex = _chatMessages[roomId]!.indexWhere(
      (m) => m.id == message.id,
    );
    if (existingIndex == -1) {
      _chatMessages[roomId]!.add(message);
      _chatMessages[roomId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      developer.log('New message received in room $roomId: ${message.content}');
      notifyListeners();
    }
  }

  /// 메시지 전달 처리
  void _handleMessageDelivered(ChatMessageModel message) {
    final roomId = message.chatRoomId;
    final messages = _chatMessages[roomId];

    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _chatMessages[roomId]![index] = message;
        notifyListeners();
      }
    }
  }

  /// 메시지 읽음 처리
  void _handleMessageRead(ChatMessageModel message) {
    final roomId = message.chatRoomId;
    final messages = _chatMessages[roomId];

    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _chatMessages[roomId]![index] = message;
        notifyListeners();
      }
    }
  }

  /// 타이핑 이벤트 처리
  void _handleTypingEvent(ChatEvent event) {
    final data = event.data as Map<String, dynamic>;
    final roomId = data['room_id'] as String;
    final userId = event.userId!;

    if (!_typingUsers.containsKey(roomId)) {
      _typingUsers[roomId] = {};
    }

    _typingUsers[roomId]!.add(userId);
    notifyListeners();

    // 5초 후 자동으로 타이핑 상태 제거
    Timer(const Duration(seconds: 5), () {
      _typingUsers[roomId]?.remove(userId);
      notifyListeners();
    });
  }

  /// 타이핑 중지 이벤트 처리
  void _handleStopTypingEvent(ChatEvent event) {
    final data = event.data as Map<String, dynamic>;
    final roomId = data['room_id'] as String;
    final userId = event.userId!;

    _typingUsers[roomId]?.remove(userId);
    notifyListeners();
  }

  /// 사용자 온라인 이벤트 처리
  void _handleUserOnlineEvent(ChatEvent event) {
    if (event.data is List) {
      // 전체 온라인 사용자 목록 업데이트
      final onlineUserIds = (event.data as List).cast<String>();
      for (final roomId in _activeChatRooms) {
        _onlineUsers[roomId] = onlineUserIds.toSet();
      }
    } else if (event.data is String) {
      // 특정 사용자 온라인
      final userId = event.data as String;
      for (final roomId in _activeChatRooms) {
        if (!_onlineUsers.containsKey(roomId)) {
          _onlineUsers[roomId] = {};
        }
        _onlineUsers[roomId]!.add(userId);
      }
    }
    notifyListeners();
  }

  /// 사용자 오프라인 이벤트 처리
  void _handleUserOfflineEvent(ChatEvent event) {
    final userId = event.data as String;
    for (final roomId in _activeChatRooms) {
      _onlineUsers[roomId]?.remove(userId);
    }
    notifyListeners();
  }

  /// 알림 이벤트 처리
  void _handleNotificationEvent(NotificationPayload notification) {
    _notifications.insert(0, notification);

    // 최대 100개의 알림만 유지
    if (_notifications.length > 100) {
      _notifications.removeRange(100, _notifications.length);
    }

    _unreadNotificationCount++;

    developer.log('New notification: ${notification.title}');
    notifyListeners();
  }

  /// 채팅방 입장
  Future<void> joinChatRoom(String roomId) async {
    try {
      await _realtimeChatService.joinChatRoom(roomId);
      _activeChatRooms.add(roomId);

      if (!_chatMessages.containsKey(roomId)) {
        _chatMessages[roomId] = [];
      }

      developer.log('Joined chat room: $roomId');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to join chat room $roomId: $e');
      rethrow;
    }
  }

  /// 채팅방 나가기
  Future<void> leaveChatRoom(String roomId) async {
    try {
      await _realtimeChatService.leaveChatRoom(roomId);
      _activeChatRooms.remove(roomId);
      _onlineUsers.remove(roomId);
      _typingUsers.remove(roomId);

      developer.log('Left chat room: $roomId');
      notifyListeners();
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
      final message = await _realtimeChatService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: messageType,
        imageUrls: imageUrls,
        metadata: metadata,
      );

      if (message != null) {
        _handleMessageReceived(message);
      }

      return message;
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
    try {
      final message = await _realtimeChatService.sendImageMessage(
        roomId: roomId,
        imageUrls: imageUrls,
        caption: caption,
      );

      if (message != null) {
        _handleMessageReceived(message);
      }

      return message;
    } catch (e) {
      developer.log('Failed to send image message: $e');
      rethrow;
    }
  }

  /// 타이핑 시작
  Future<void> startTyping(String roomId) async {
    try {
      await _realtimeChatService.startTyping(roomId);
    } catch (e) {
      developer.log('Failed to start typing: $e');
    }
  }

  /// 타이핑 중지
  Future<void> stopTyping(String roomId) async {
    try {
      await _realtimeChatService.stopTyping(roomId);
    } catch (e) {
      developer.log('Failed to stop typing: $e');
    }
  }

  /// 메시지 읽음 처리
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _realtimeChatService.markMessageAsRead(messageId);
    } catch (e) {
      developer.log('Failed to mark message as read: $e');
    }
  }

  /// 푸시 알림 전송
  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _pushNotificationService.sendPushNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
        data: data,
      );
    } catch (e) {
      developer.log('Failed to send push notification: $e');
    }
  }

  /// 채팅 알림 전송
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    try {
      await _pushNotificationService.sendChatNotification(
        recipientId: recipientId,
        senderName: senderName,
        message: message,
        chatRoomId: chatRoomId,
      );
    } catch (e) {
      developer.log('Failed to send chat notification: $e');
    }
  }

  /// 알림 읽음 처리
  void markNotificationAsRead(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications.removeAt(index);
      if (_unreadNotificationCount > 0) {
        _unreadNotificationCount--;
      }
      notifyListeners();
    }
  }

  /// 모든 알림 읽음 처리
  void markAllNotificationsAsRead() {
    _notifications.clear();
    _unreadNotificationCount = 0;
    notifyListeners();
  }

  /// 알림 배지 수 업데이트
  Future<void> updateBadgeCount() async {
    try {
      await _pushNotificationService.updateBadgeCount(_unreadNotificationCount);
    } catch (e) {
      developer.log('Failed to update badge count: $e');
    }
  }

  /// 연결 재시도
  Future<void> reconnect() async {
    try {
      developer.log('Attempting to reconnect realtime services');

      _isConnected = false;
      notifyListeners();

      // 기존 구독 해제
      await _chatEventSubscription?.cancel();
      await _notificationSubscription?.cancel();

      // 서비스 재초기화
      await _realtimeChatService.initialize();

      // 활성 채팅방 재연결
      final roomIds = List<String>.from(_activeChatRooms);
      _activeChatRooms.clear();

      for (final roomId in roomIds) {
        await joinChatRoom(roomId);
      }

      // 이벤트 리스너 재설정
      _setupEventListeners();

      _isConnected = true;
      developer.log('Realtime services reconnected successfully');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to reconnect realtime services: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  /// 연결 상태 확인
  void checkConnection() {
    // 연결 상태를 주기적으로 확인하고 필요시 재연결
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isConnected && _isInitialized) {
        reconnect();
      }
    });
  }

  @override
  void dispose() {
    _chatEventSubscription?.cancel();
    _notificationSubscription?.cancel();
    _realtimeChatService.dispose();
    _pushNotificationService.dispose();
    super.dispose();
  }
}
