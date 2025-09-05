class ChatModel {
  final String id;
  final List<String> participants;
  final String? productId;
  final String? resellerId; // 대신판매자 ID
  final bool isResaleChat; // 대신팔기 채팅방 여부
  final String? originalSellerId; // 원 판매자 ID
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 조인된 정보
  final String? productTitle;
  final String? productImage;
  final int? productPrice;
  final String? otherUserName; // 상대방 이름
  final String? otherUserProfileImage;
  final String? resellerName; // 대신판매자 이름
  final String? originalSellerName; // 원 판매자 이름
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  ChatModel({
    required this.id,
    required this.participants,
    this.productId,
    this.resellerId,
    this.isResaleChat = false,
    this.originalSellerId,
    required this.createdAt,
    required this.updatedAt,
    this.productTitle,
    this.productImage,
    this.productPrice,
    this.otherUserName,
    this.otherUserProfileImage,
    this.resellerName,
    this.originalSellerName,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('Chat ID cannot be empty');
    if (participants.isEmpty) throw ArgumentError('Chat must have participants');
    if (participants.length < 2) throw ArgumentError('Chat must have at least 2 participants');
    if (participants.toSet().length != participants.length) {
      throw ArgumentError('Duplicate participants not allowed');
    }
    if (unreadCount < 0) throw ArgumentError('Unread count cannot be negative');
    if (productPrice != null && productPrice! <= 0) {
      throw ArgumentError('Product price must be positive');
    }
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'],
      participants: List<String>.from(json['participants'] ?? []),
      productId: json['product_id'],
      resellerId: json['reseller_id'],
      isResaleChat: json['is_resale_chat'] ?? false,
      originalSellerId: json['original_seller_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      productTitle: json['product_title'],
      productImage: json['product_image'],
      productPrice: json['product_price'],
      otherUserName: json['other_user_name'],
      otherUserProfileImage: json['other_user_profile_image'],
      resellerName: json['reseller_name'],
      originalSellerName: json['original_seller_name'],
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'] != null 
          ? DateTime.parse(json['last_message_time'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'product_id': productId,
      'reseller_id': resellerId,
      'is_resale_chat': isResaleChat,
      'original_seller_id': originalSellerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (productTitle != null) 'product_title': productTitle,
      if (productImage != null) 'product_image': productImage,
      if (productPrice != null) 'product_price': productPrice,
      if (otherUserName != null) 'other_user_name': otherUserName,
      if (otherUserProfileImage != null) 'other_user_profile_image': otherUserProfileImage,
      if (resellerName != null) 'reseller_name': resellerName,
      if (originalSellerName != null) 'original_seller_name': originalSellerName,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastMessageTime != null) 'last_message_time': lastMessageTime!.toIso8601String(),
      'unread_count': unreadCount,
    };
  }

  // 채팅방 제목 생성 (대신팔기 정보 포함)
  String getChatTitle() {
    if (isResaleChat && resellerName != null) {
      return '$otherUserName (${resellerName}님이 대신판매 중)';
    }
    return otherUserName ?? '채팅';
  }

  // 채팅방 설명 생성
  String? getChatDescription() {
    if (isResaleChat) {
      if (originalSellerName != null) {
        return '원 판매자: $originalSellerName | 대신판매: $resellerName';
      }
      return '대신판매 상품';
    }
    return null;
  }

  // 상대방 ID 가져오기
  String? getOtherUserId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  ChatModel copyWith({
    String? id,
    List<String>? participants,
    String? productId,
    String? resellerId,
    bool? isResaleChat,
    String? originalSellerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? productTitle,
    String? productImage,
    int? productPrice,
    String? otherUserName,
    String? otherUserProfileImage,
    String? resellerName,
    String? originalSellerName,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      productId: productId ?? this.productId,
      resellerId: resellerId ?? this.resellerId,
      isResaleChat: isResaleChat ?? this.isResaleChat,
      originalSellerId: originalSellerId ?? this.originalSellerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserProfileImage: otherUserProfileImage ?? this.otherUserProfileImage,
      resellerName: resellerName ?? this.resellerName,
      originalSellerName: originalSellerName ?? this.originalSellerName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}