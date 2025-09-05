import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../config/supabase_config.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;
  final String userName;
  final String productTitle;
  final bool isResaleChat; // 대신팔기 채팅방 여부
  final String? resellerName; // 대신판매자 이름
  final String? originalSellerName; // 원 판매자 이름

  const ChatRoomScreen({
    super.key,
    required this.chatRoomId,
    required this.userName,
    required this.productTitle,
    this.isResaleChat = false,
    this.resellerName,
    this.originalSellerName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  List<MessageModel> _messages = [];
  StreamSubscription? _messageSubscription;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current user
      _currentUser = await _authService.getCurrentUser();
      
      if (_currentUser != null) {
        // Load existing messages
        await _loadMessages();
        
        // Subscribe to new messages
        _subscribeToMessages();
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getChatMessages(
        widget.chatRoomId,
        limit: 50,
      );
      
      setState(() {
        _messages = messages;
      });
      
      // Scroll to bottom after loading messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      print('Error loading messages: $e');
    }
  }
  
  void _subscribeToMessages() {
    _messageSubscription = _chatService.subscribeToChat(
      widget.chatRoomId,
      (MessageModel newMessage) {
        // Don't add if message already exists
        if (!_messages.any((m) => m.id == newMessage.id)) {
          setState(() {
            _messages.add(newMessage);
          });
          
          // Auto scroll to new message
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _chatService.unsubscribeFromChat(widget.chatRoomId);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (widget.productTitle.isNotEmpty) _buildProductInfo(),
                Expanded(
                  child: _buildMessageList(),
                ),
                _buildTransactionButtons(),
                _buildMessageInput(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.userName,
            style: AppStyles.headingSmall,
          ),
          Text(
            '온라인', // TODO: 실제 온라인 상태로 교체
            style: AppStyles.bodySmall.copyWith(
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.report, color: Colors.red),
                  SizedBox(width: 8),
                  Text('신고하기'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('차단하기'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.image,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productTitle,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '120만원', // TODO: 실제 가격으로 교체
                  style: AppStyles.priceText,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: 상품 상세 페이지로 이동
            },
            child: const Text('상품보기'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '대화를 시작해보세요',
              style: AppStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _currentUser?.id;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildMessageBubble(message, isMe),
        );
      },
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    // System messages
    if (message.messageType == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: AppStyles.bodySmall.copyWith(
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              message.senderName?.substring(0, 1).toUpperCase() ?? 
                widget.userName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: message.messageType == 'image' 
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                decoration: BoxDecoration(
                  color: isMe ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: message.messageType == 'image'
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          message.content,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, size: 50),
                            );
                          },
                        ),
                      )
                    : Text(
                        message.content,
                        style: AppStyles.bodyMedium.copyWith(
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatMessageTime(message.createdAt),
                style: AppStyles.bodySmall.copyWith(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: AppSpacing.sm),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
            child: Text(
              _currentUser?.name.substring(0, 1).toUpperCase() ?? '나',
              style: const TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionButtons() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showSafeTransactionDialog,
              icon: const Icon(Icons.security, size: 18),
              label: const Text('안전거래'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.successColor,
                side: const BorderSide(color: AppTheme.successColor),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showTrackingDialog,
              icon: const Icon(Icons.local_shipping, size: 18),
              label: const Text('운송장'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 이미지 선택 버튼
          IconButton(
            onPressed: _isUploadingImage ? null : _pickAndSendImage,
            icon: Icon(
              Icons.image,
              color: _isUploadingImage ? Colors.grey : AppTheme.primaryColor,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null || _currentUser == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      // 이미지 업로드
      final imageFile = File(image.path);
      final imageUrl = await _chatService.uploadChatImage(
        imageFile,
        widget.chatRoomId,
        _currentUser!.id,
      );

      if (imageUrl != null) {
        // 이미지 메시지 전송
        final sentMessage = await _chatService.sendMessage(
          chatId: widget.chatRoomId,
          senderId: _currentUser!.id,
          content: imageUrl,
          messageType: 'image',
        );

        if (sentMessage != null) {
          // 스크롤 하단으로
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 전송 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUser == null || _isSending) return;

    setState(() {
      _isSending = true;
      _messageController.clear();
    });

    try {
      final sentMessage = await _chatService.sendMessage(
        chatId: widget.chatRoomId,
        senderId: _currentUser!.id,
        content: content,
        messageType: 'text',
      );

      if (sentMessage != null) {
        // Message will be added through subscription
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        // Show error if message failed to send
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('메시지 전송에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('메시지 전송 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'report':
        _showReportDialog();
        break;
      case 'block':
        _showBlockDialog();
        break;
    }
  }

  void _showSafeTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('안전거래'),
        content: const Text('안전거래를 시작하시겠습니까?\n\n구매자의 결제금이 플랫폼에 임시 보관되며,\n상품 수령 확인 후 판매자에게 정산됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 안전거래 시작 로직
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('안전거래가 시작되었습니다')),
              );
            },
            child: const Text('시작하기'),
          ),
        ],
      ),
    );
  }

  void _showTrackingDialog() {
    final trackingController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운송장 번호 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('운송장 번호를 입력하면 자동으로 배송 추적이 시작됩니다.'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: trackingController,
              decoration: const InputDecoration(
                labelText: '운송장 번호',
                hintText: '예: 1234567890',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final trackingNumber = trackingController.text.trim();
              if (trackingNumber.isNotEmpty) {
                Navigator.pop(context);
                // TODO: 운송장 번호 저장 및 추적 시작 로직
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('운송장 번호가 등록되었습니다: $trackingNumber')),
                );
              }
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신고하기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('신고 사유를 선택해주세요:'),
            const SizedBox(height: AppSpacing.md),
            ...[
              '사기/허위 정보',
              '욕설/비방',
              '스팸/광고',
              '기타',
            ].map((reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: null, // TODO: 상태 관리
              onChanged: (value) {
                // TODO: 신고 사유 선택 로직
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 신고 제출 로직
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('신고가 접수되었습니다')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('신고하기'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 차단'),
        content: Text('${widget.userName}님을 차단하시겠습니까?\n\n차단된 사용자와는 더 이상 채팅할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 사용자 차단 로직
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.userName}님을 차단했습니다')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: const Text('차단하기'),
          ),
        ],
      ),
    );
  }
}