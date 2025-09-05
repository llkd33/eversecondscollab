class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  
  // 추가 정보
  final String? senderName;
  final String? senderImage;
  final bool? isRead;
  final String? messageType; // text, image, system

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.senderImage,
    this.isRead = false,
    this.messageType = MessageType.text,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('Message ID cannot be empty');
    if (chatId.isEmpty) throw ArgumentError('Chat ID cannot be empty');
    if (senderId.isEmpty) throw ArgumentError('Sender ID cannot be empty');
    if (content.isEmpty) throw ArgumentError('Message content cannot be empty');
    if (content.length > 1000) throw ArgumentError('Message content too long (max 1000 characters)');
    if (!MessageType.isValid(messageType ?? MessageType.text)) {
      throw ArgumentError('Invalid message type');
    }
  }

  // JSON에서 Message 객체 생성
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      chatId: json['chat_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      senderName: json['sender_name'],
      senderImage: json['sender_image'],
      isRead: json['is_read'] ?? false,
      messageType: json['message_type'] ?? 'text',
    );
  }

  // Message 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      if (senderName != null) 'sender_name': senderName,
      if (senderImage != null) 'sender_image': senderImage,
      if (isRead != null) 'is_read': isRead,
      if (messageType != null) 'message_type': messageType,
    };
  }

  // copyWith 메서드
  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    DateTime? createdAt,
    String? senderName,
    String? senderImage,
    bool? isRead,
    String? messageType,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderImage: senderImage ?? this.senderImage,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
    );
  }

  // 헬퍼 메서드
  bool get isSystemMessage => messageType == 'system';
  bool get isImageMessage => messageType == 'image';
  bool get isTextMessage => messageType == 'text';
  
  // 메시지 발송자 확인
  bool isSentBy(String userId) => senderId == userId;
  
  // 시간 포맷팅
  String get formattedTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  // 날짜 포맷팅
  String get formattedDate {
    return '${createdAt.year}년 ${createdAt.month}월 ${createdAt.day}일';
  }
}

// 메시지 타입 enum
class MessageType {
  static const String text = 'text';
  static const String image = 'image';
  static const String system = 'system';

  static const List<String> all = [text, image, system];
  static bool isValid(String type) => all.contains(type);
}

// 시스템 메시지 템플릿
class SystemMessages {
  static String safeTransactionNotice(String resellerName) {
    return '$resellerName님에 의해 대신판매되는 거래입니다.';
  }
  
  static const String safeTransactionGuide = 
      '안전한 거래를 하기 원하시면 안전거래로 거래하세요.';
  
  static const String depositGuide = 
      '법인계좌로 입금해주세요. 입금 후 입금확인 요청 버튼을 눌러주세요.';
  
  static const String depositConfirmed = 
      '입금이 확인되었습니다. 판매자가 상품을 발송할 예정입니다.';
  
  static const String shippingStarted = 
      '상품이 발송되었습니다. 배송 정보를 확인해주세요.';
  
  static const String transactionCompleted = 
      '거래가 완료되었습니다. 리뷰를 남겨주세요.';
}