import 'package:intl/intl.dart';
import 'user_model.dart';

enum MessageType {
  text,
  image,
  system,
  transaction,
}

class ChatMessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String content;
  final MessageType messageType;
  final List<String>? imageUrls;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isRead;
  final DateTime? readAt;
  final UserModel? sender;

  ChatMessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.imageUrls,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
    required this.isRead,
    this.readAt,
    this.sender,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      chatRoomId: json['chat_room_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      messageType: _parseMessageType(json['message_type'] as String?),
      imageUrls: json['image_urls'] != null 
          ? List<String>.from(json['image_urls'] as List)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null 
          ? DateTime.parse(json['read_at'] as String)
          : null,
      sender: json['sender'] != null 
          ? UserModel.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType.name,
      'image_urls': imageUrls,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      if (sender != null) 'sender': sender!.toJson(),
    };
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'text':
        return MessageType.text;
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

  ChatMessageModel copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? content,
    MessageType? messageType,
    List<String>? imageUrls,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRead,
    DateTime? readAt,
    UserModel? sender,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      imageUrls: imageUrls ?? this.imageUrls,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      sender: sender ?? this.sender,
    );
  }

  /// 메시지 시간 포맷팅
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(createdAt);
    } else if (now.difference(createdAt).inDays < 7) {
      return DateFormat('E HH:mm').format(createdAt);
    } else {
      return DateFormat('MM/dd HH:mm').format(createdAt);
    }
  }

  /// 메시지가 이미지 타입인지 확인
  bool get isImageMessage => messageType == MessageType.image && imageUrls != null && imageUrls!.isNotEmpty;

  /// 메시지가 시스템 메시지인지 확인
  bool get isSystemMessage => messageType == MessageType.system;

  /// 메시지가 거래 관련인지 확인
  bool get isTransactionMessage => messageType == MessageType.transaction;

  /// 메시지 미리보기 텍스트
  String get previewText {
    switch (messageType) {
      case MessageType.image:
        return '📷 이미지';
      case MessageType.system:
        return content;
      case MessageType.transaction:
        return '💰 거래 정보';
      case MessageType.text:
      default:
        return content;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatMessageModel(id: $id, senderId: $senderId, content: $content, messageType: $messageType, createdAt: $createdAt, isRead: $isRead)';
  }
}