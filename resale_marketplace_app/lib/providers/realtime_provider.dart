import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../services/realtime_chat_service.dart';
import '../services/push_notification_service.dart';
import '../services/realtime_product_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/realtime_report_service.dart';
import '../models/product_model.dart';
import '../models/report_model.dart';

/// 실시간 기능을 위한 상태 관리 Provider
class RealtimeProvider with ChangeNotifier {
  RealtimeProvider({
    RealtimeChatService? realtimeChatService,
    PushNotificationService? pushNotificationService,
    RealtimeProductService? realtimeProductService,
    RealtimeNotificationService? realtimeNotificationService,
    RealtimeReportService? realtimeReportService,
  }) : _realtimeChatService = realtimeChatService ?? RealtimeChatService(),
       _pushNotificationService = pushNotificationService ?? PushNotificationService(),
       _realtimeProductService = realtimeProductService ?? RealtimeProductService(),
       _realtimeNotificationService = realtimeNotificationService ?? RealtimeNotificationService(),
       _realtimeReportService = realtimeReportService ?? RealtimeReportService();

  final RealtimeChatService _realtimeChatService;
  final PushNotificationService _pushNotificationService;
  final RealtimeProductService _realtimeProductService;
  final RealtimeNotificationService _realtimeNotificationService;
  final RealtimeReportService _realtimeReportService;

  // 채팅 관련 상태
  final Map<String, List<ChatMessageModel>> _chatMessages = {};
  final Map<String, Set<String>> _onlineUsers = {};
  final Map<String, Set<String>> _typingUsers = {};
  final Set<String> _activeChatRooms = {};

  // 알림 관련 상태
  final List<NotificationPayload> _notifications = [];
  int _unreadNotificationCount = 0;
  int _realTimeBadgeCount = 0;

  // 상품 관련 상태
  final Map<String, ProductModel> _cachedProducts = {};
  final Set<String> _subscribedCategories = {};
  final Set<String> _subscribedProducts = {};

  // 신고 관련 상태
  final List<ReportModel> _recentReports = [];
  int _pendingReportsCount = 0;
  Map<String, int> _reportStats = {};
  Map<String, int> _reportTypeStats = {};

  // 연결 상태
  bool _isConnected = false;
  bool _isInitialized = false;

  StreamSubscription? _chatEventSubscription;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _productEventSubscription;
  StreamSubscription? _realtimeNotificationSubscription;
  StreamSubscription? _reportStatsSubscription;
  StreamSubscription? _reportTypeStatsSubscription;
  StreamSubscription? _pendingReportsSubscription;
  StreamSubscription? _recentReportsSubscription;

  // Getters
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  int get unreadNotificationCount => _unreadNotificationCount;
  int get realTimeBadgeCount => _realTimeBadgeCount;
  List<NotificationPayload> get notifications =>
      List.unmodifiable(_notifications);
  Set<String> get activeChatRooms => Set.unmodifiable(_activeChatRooms);
  Map<String, ProductModel> get cachedProducts => Map.unmodifiable(_cachedProducts);
  Set<String> get subscribedCategories => Set.unmodifiable(_subscribedCategories);
  Set<String> get subscribedProducts => Set.unmodifiable(_subscribedProducts);
  
  // 신고 관련 Getters
  List<ReportModel> get recentReports => List.unmodifiable(_recentReports);
  int get pendingReportsCount => _pendingReportsCount;
  Map<String, int> get reportStats => Map.unmodifiable(_reportStats);
  Map<String, int> get reportTypeStats => Map.unmodifiable(_reportTypeStats);

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

  /// 캐시된 상품 가져오기
  ProductModel? getCachedProduct(String productId) {
    return _cachedProducts[productId];
  }

  /// 카테고리 구독 상태 확인
  bool isSubscribedToCategory(String category) {
    return _subscribedCategories.contains(category);
  }

  /// 상품 구독 상태 확인
  bool isSubscribedToProduct(String productId) {
    return _subscribedProducts.contains(productId);
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

      // 실시간 상품 서비스 초기화
      await _realtimeProductService.initialize();

      // 실시간 알림 서비스 초기화
      await _realtimeNotificationService.initialize();

      // 실시간 신고 서비스 초기화
      await _setupReportStreams();

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

    // 상품 이벤트 리스너
    _productEventSubscription = _realtimeProductService.eventStream.listen(
      _handleProductEvent,
      onError: (error) {
        developer.log('Product event error: $error');
      },
    );

    // 실시간 알림 이벤트 리스너
    _realtimeNotificationSubscription = _realtimeNotificationService.eventStream.listen(
      _handleRealtimeNotificationEvent,
      onError: (error) {
        developer.log('Realtime notification event error: $error');
      },
    );

    // 신고 실시간 알림 시작
    _startReportNotifications();
  }

  /// 신고 관련 스트림 설정
  Future<void> _setupReportStreams() async {
    // 신고 통계 스트림
    _reportStatsSubscription = _realtimeReportService.getReportStatsStream().listen(
      (stats) {
        _reportStats = stats;
        _pendingReportsCount = stats['pending'] ?? 0;
        notifyListeners();
      },
      onError: (error) {
        developer.log('Report stats stream error: $error');
      },
    );

    // 타입별 신고 통계 스트림
    _reportTypeStatsSubscription = _realtimeReportService.getReportsByTypeStream().listen(
      (typeStats) {
        _reportTypeStats = typeStats;
        notifyListeners();
      },
      onError: (error) {
        developer.log('Report type stats stream error: $error');
      },
    );

    // 최근 신고 목록 스트림
    _recentReportsSubscription = _realtimeReportService.getRecentReportsStream(limit: 20).listen(
      (reports) {
        _recentReports.clear();
        _recentReports.addAll(reports);
        notifyListeners();
      },
      onError: (error) {
        developer.log('Recent reports stream error: $error');
      },
    );

    // 미처리 신고 수 스트림
    _pendingReportsSubscription = _realtimeReportService.getPendingReportsCountStream().listen(
      (count) {
        _pendingReportsCount = count;
        notifyListeners();
      },
      onError: (error) {
        developer.log('Pending reports count stream error: $error');
      },
    );
  }

  /// 신고 실시간 알림 시작
  Future<void> _startReportNotifications() async {
    await _realtimeReportService.startReportNotifications(
      onNewReport: _handleNewReport,
      onReportUpdated: _handleReportUpdated,
    );
  }

  /// 새 신고 처리
  void _handleNewReport(ReportModel report) {
    // 최근 신고 목록에 추가
    _recentReports.insert(0, report);
    if (_recentReports.length > 20) {
      _recentReports.removeLast();
    }

    // 긴급 신고인 경우 즉시 알림
    if (report.priority == 'critical' || report.priority == 'high') {
      _showUrgentReportNotification(report);
    }

    developer.log('New report received: ${report.reason} (${report.priority})');
    notifyListeners();
  }

  /// 신고 업데이트 처리
  void _handleReportUpdated(ReportModel report) {
    // 기존 신고 업데이트
    final index = _recentReports.indexWhere((r) => r.id == report.id);
    if (index != -1) {
      _recentReports[index] = report;
    }

    developer.log('Report updated: ${report.id} -> ${report.status}');
    notifyListeners();
  }

  /// 긴급 신고 알림 표시
  void _showUrgentReportNotification(ReportModel report) {
    final notification = NotificationPayload(
      id: 'urgent_report_${report.id}',
      title: '🚨 긴급 신고',
      body: '${report.reason} - 즉시 확인이 필요합니다',
      type: NotificationType.system,
      data: {
        'type': 'urgent_report',
        'report_id': report.id,
        'priority': report.priority,
        'target_type': report.targetType,
      },
      timestamp: DateTime.now(),
    );

    _notifications.insert(0, notification);
    _realTimeBadgeCount++;
    notifyListeners();
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

  /// 상품 이벤트 처리
  void _handleProductEvent(ProductEvent event) {
    switch (event.type) {
      case ProductEventType.productUpdated:
        if (event.product != null) {
          _cachedProducts[event.productId] = event.product!;
          developer.log('Product updated: ${event.productId}');
        }
        break;
      case ProductEventType.productStatusChanged:
        if (event.product != null) {
          _cachedProducts[event.productId] = event.product!;
          developer.log('Product status changed: ${event.productId} to ${event.metadata?['new_status']}');
        }
        break;
      case ProductEventType.productLiked:
        developer.log('Product liked: ${event.productId}');
        break;
      case ProductEventType.productUnliked:
        developer.log('Product unliked: ${event.productId}');
        break;
      case ProductEventType.productViewed:
        if (event.product != null) {
          _cachedProducts[event.productId] = event.product!;
          developer.log('Product viewed: ${event.productId}, views: ${event.metadata?['view_count']}');
        }
        break;
      case ProductEventType.productDeleted:
        _cachedProducts.remove(event.productId);
        developer.log('Product deleted: ${event.productId}');
        break;
    }
    notifyListeners();
  }

  /// 실시간 알림 이벤트 처리
  void _handleRealtimeNotificationEvent(RealtimeNotificationEvent event) {
    switch (event.type) {
      case RealtimeNotificationEventType.newNotification:
        if (event.notification != null) {
          _notifications.insert(0, event.notification!);
          _unreadNotificationCount++;
          developer.log('Realtime notification received: ${event.notification!.title}');
        }
        break;
      case RealtimeNotificationEventType.notificationRead:
        developer.log('Notification read: ${event.notificationId}');
        break;
      case RealtimeNotificationEventType.notificationDeleted:
        developer.log('Notification deleted: ${event.notificationId}');
        break;
      case RealtimeNotificationEventType.badgeCountUpdated:
        if (event.badgeCount != null) {
          _realTimeBadgeCount = event.badgeCount!;
          developer.log('Badge count updated: ${event.badgeCount}');
        }
        break;
    }
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

  // === 상품 관련 메서드 ===

  /// 카테고리 구독
  Future<void> subscribeToCategory(String category) async {
    try {
      _realtimeProductService.subscribeToCategory(category);
      _subscribedCategories.add(category);
      developer.log('Subscribed to category: $category');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to subscribe to category $category: $e');
    }
  }

  /// 카테고리 구독 해제
  Future<void> unsubscribeFromCategory(String category) async {
    try {
      _realtimeProductService.unsubscribeFromCategory(category);
      _subscribedCategories.remove(category);
      developer.log('Unsubscribed from category: $category');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to unsubscribe from category $category: $e');
    }
  }

  /// 상품 구독
  Future<void> subscribeToProduct(String productId) async {
    try {
      _realtimeProductService.subscribeToProduct(productId);
      _subscribedProducts.add(productId);
      developer.log('Subscribed to product: $productId');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to subscribe to product $productId: $e');
    }
  }

  /// 상품 구독 해제
  Future<void> unsubscribeFromProduct(String productId) async {
    try {
      _realtimeProductService.unsubscribeFromProduct(productId);
      _subscribedProducts.remove(productId);
      developer.log('Unsubscribed from product: $productId');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to unsubscribe from product $productId: $e');
    }
  }

  /// 모든 카테고리 구독
  Future<void> subscribeToAllCategories() async {
    try {
      _realtimeProductService.subscribeToAllCategories();
      _subscribedCategories.clear();
      developer.log('Subscribed to all categories');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to subscribe to all categories: $e');
    }
  }

  /// 상품 조회수 증가
  Future<void> incrementProductViewCount(String productId) async {
    try {
      await _realtimeProductService.incrementViewCount(productId);
    } catch (e) {
      developer.log('Failed to increment view count for product $productId: $e');
    }
  }

  /// 상품 좋아요 토글
  Future<void> toggleProductLike(String productId, String userId) async {
    try {
      await _realtimeProductService.toggleLike(productId, userId);
    } catch (e) {
      developer.log('Failed to toggle like for product $productId: $e');
      rethrow;
    }
  }

  /// 상품 상태 변경 알림
  Future<void> notifyProductStatusChanged(String productId, String newStatus) async {
    try {
      // 캐시된 상품 정보 업데이트
      if (_cachedProducts.containsKey(productId)) {
        _cachedProducts[productId] = _cachedProducts[productId]!.copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
      }

      // 실시간 상품 서비스를 통해 상태 변경 브로드캐스트
      await _realtimeProductService.notifyStatusChange(productId, newStatus);
      
      developer.log('Product status change notified: $productId -> $newStatus');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to notify product status change: $e');
    }
  }

  // === 실시간 알림 관련 메서드 ===

  /// 즉시 알림 전송
  Future<void> sendInstantNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _realtimeNotificationService.sendInstantNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
        data: data,
      );
    } catch (e) {
      developer.log('Failed to send instant notification: $e');
      rethrow;
    }
  }

  /// 알림 읽음 처리 (실시간)
  Future<void> markRealtimeNotificationAsRead(String notificationId) async {
    try {
      await _realtimeNotificationService.markAsRead(notificationId);
    } catch (e) {
      developer.log('Failed to mark realtime notification as read: $e');
      rethrow;
    }
  }

  /// 모든 알림 읽음 처리 (실시간)
  Future<void> markAllRealtimeNotificationsAsRead() async {
    try {
      await _realtimeNotificationService.markAllAsRead();
      _realTimeBadgeCount = 0;
      notifyListeners();
    } catch (e) {
      developer.log('Failed to mark all realtime notifications as read: $e');
      rethrow;
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

  /// 테스트용 알림 추가 (실제 이벤트 기반)
  void addTransactionNotification(String productTitle) {
    final notification = NotificationPayload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.transaction,
      title: '거래 완료',
      body: '"$productTitle" 상품의 거래가 완료되었습니다.',
      data: {'type': 'transaction_complete'},
      timestamp: DateTime.now(),
    );
    
    _notifications.insert(0, notification);
    _unreadNotificationCount++;
    notifyListeners();
  }

  /// 상품 등록 알림
  void addProductNotification(String productTitle) {
    final notification = NotificationPayload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.system,
      title: '상품 등록 완료',
      body: '"$productTitle" 상품이 성공적으로 등록되었습니다.',
      data: {'type': 'product_registered'},
      timestamp: DateTime.now(),
    );
    
    _notifications.insert(0, notification);
    _unreadNotificationCount++;
    notifyListeners();
  }

  /// 채팅 메시지 알림 (테스트용)
  void addChatNotification(String senderName, String message) {
    final notification = NotificationPayload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.chatMessage,
      title: senderName,
      body: message,
      data: {'type': 'chat_message', 'sender': senderName},
      timestamp: DateTime.now(),
    );
    
    _notifications.insert(0, notification);
    _unreadNotificationCount++;
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
      await _productEventSubscription?.cancel();
      await _realtimeNotificationSubscription?.cancel();

      // 서비스 재초기화
      await _realtimeChatService.initialize();
      await _realtimeProductService.initialize();
      await _realtimeNotificationService.initialize();

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
    _productEventSubscription?.cancel();
    _realtimeNotificationSubscription?.cancel();
    _reportStatsSubscription?.cancel();
    _reportTypeStatsSubscription?.cancel();
    _pendingReportsSubscription?.cancel();
    _recentReportsSubscription?.cancel();
    _realtimeChatService.dispose();
    _pushNotificationService.dispose();
    _realtimeProductService.dispose();
    _realtimeNotificationService.dispose();
    _realtimeReportService.stopReportNotifications();
    super.dispose();
  }
}
