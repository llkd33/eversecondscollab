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
          
          // Mark chat as read if user is viewing
          if (_currentUser != null) {
            _chatService.markChatAsRead(widget.chatRoomId, _currentUser!.id);
          }
          
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
    // Mark chat as read when leaving
    if (_currentUser != null) {
      _chatService.markChatAsRead(widget.chatRoomId, _currentUser!.id);
    }
    
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActions,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.more_horiz, color: Colors.white),
      ),
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
      child: Column(
        children: [
          // 안전거래 안내 메시지
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[600],
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '안전한 거래를 하기 원하시면 안전거래로 거래하세요',
                    style: AppStyles.bodySmall.copyWith(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // 대신판매 거래 표시
          if (widget.isResaleChat) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.store,
                    color: Colors.orange[600],
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${widget.resellerName ?? "대신판매자"}님에 의해 대신판매되는 거래입니다',
                      style: AppStyles.bodySmall.copyWith(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          
          // 거래 방식 선택 버튼
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startSafeTransaction,
                  icon: const Icon(Icons.security, size: 18),
                  label: const Text('안전거래'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startNormalTransaction,
                  icon: const Icon(Icons.handshake, size: 18),
                  label: const Text('일반거래'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                ),
              ),
            ],
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

  void _startSafeTransaction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: AppTheme.successColor),
            const SizedBox(width: AppSpacing.sm),
            const Text('안전거래 시작'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '안전거래 진행 순서:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('1. 구매자가 법인계좌로 입금'),
            const Text('2. 입금확인 요청'),
            const Text('3. 관리자 입금 확인'),
            const Text('4. 판매자 상품 발송'),
            const Text('5. 구매자 수령 확인'),
            const Text('6. 자동 정산 완료'),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 안전거래는 플랫폼이 중간에서 거래를 보장하는 서비스입니다.',
                style: TextStyle(fontSize: 12),
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
              Navigator.pop(context);
              _showSafeTransactionDetails();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('시작하기'),
          ),
        ],
      ),
    );
  }

  void _showSafeTransactionDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('안전거래 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💳 입금 계좌 정보',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('은행: 우리은행'),
                  Text('계좌번호: 1002-XXX-XXXXXX'),
                  Text('예금주: 에버세컨즈'),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    '입금액: 상품금액 + 수수료',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '입금 후 아래 "입금확인 요청" 버튼을 눌러주세요.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestDepositConfirmation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('입금확인 요청'),
          ),
        ],
      ),
    );
  }

  void _requestDepositConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('입금확인 요청'),
        content: const Text(
          '입금을 완료하셨나요?\n\n입금확인 요청을 보내면 관리자가 확인 후\n판매자에게 알림을 보내드립니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 시스템 메시지 전송
              await _chatService.sendSystemMessage(
                chatId: widget.chatRoomId,
                content: '입금확인 요청이 전송되었습니다.\n관리자가 확인 후 연락드리겠습니다.',
              );
              
              // TODO: 실제 SMS 발송 로직 구현
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('입금확인 요청이 전송되었습니다'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('요청하기'),
          ),
        ],
      ),
    );
  }

  void _startNormalTransaction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.handshake, color: AppTheme.primaryColor),
            const SizedBox(width: AppSpacing.sm),
            const Text('일반거래'),
          ],
        ),
        content: const Text(
          '일반거래를 선택하셨습니다.\n\n거래 당사자 간 직접 거래하시며,\n거래 완료 시 판매자가 직접 거래완료 처리를 해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 시스템 메시지 전송
              await _chatService.sendSystemMessage(
                chatId: widget.chatRoomId,
                content: '일반거래가 시작되었습니다.\n안전한 거래를 위해 직거래를 권장합니다.',
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('일반거래가 시작되었습니다'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('시작하기'),
          ),
        ],
      ),
    );
  }

  void _showTrackingDialog() {
    final trackingController = TextEditingController();
    String selectedCourier = 'CJ대한통운';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('배송 정보 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('배송 정보를 입력하면 상대방에게 알림이 전송됩니다.'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedCourier,
                decoration: const InputDecoration(
                  labelText: '택배사',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'CJ대한통운',
                  '한진택배',
                  '로젠택배',
                  '우체국택배',
                  '롯데택배',
                  'GSPostbox',
                ].map((courier) => DropdownMenuItem(
                  value: courier,
                  child: Text(courier),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedCourier = value;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: trackingController,
                decoration: const InputDecoration(
                  labelText: '운송장 번호',
                  hintText: '예: 1234567890',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final trackingNumber = trackingController.text.trim();
                if (trackingNumber.isNotEmpty) {
                  Navigator.pop(context);
                  
                  // 시스템 메시지로 배송 정보 전송
                  await _chatService.sendSystemMessage(
                    chatId: widget.chatRoomId,
                    content: '📦 배송이 시작되었습니다!\n\n'
                        '택배사: $selectedCourier\n'
                        '운송장번호: $trackingNumber\n\n'
                        '배송 조회는 해당 택배사 홈페이지에서 확인하실 수 있습니다.',
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('배송 정보가 전송되었습니다'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              child: const Text('전송'),
            ),
          ],
        ),
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

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              '빠른 작업',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              children: [
                _buildQuickActionItem(
                  icon: Icons.local_shipping,
                  label: '배송정보',
                  onTap: () {
                    Navigator.pop(context);
                    _showTrackingDialog();
                  },
                ),
                _buildQuickActionItem(
                  icon: Icons.receipt_long,
                  label: '거래완료',
                  onTap: () {
                    Navigator.pop(context);
                    _showTransactionCompleteDialog();
                  },
                ),
                _buildQuickActionItem(
                  icon: Icons.help_outline,
                  label: '도움말',
                  onTap: () {
                    Navigator.pop(context);
                    _showHelpDialog();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래 완료'),
        content: const Text(
          '거래를 완료하시겠습니까?\n\n거래 완료 후에는 취소할 수 없으며,\n상호 리뷰를 남길 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 시스템 메시지 전송
              await _chatService.sendSystemMessage(
                chatId: widget.chatRoomId,
                content: '🎉 거래가 완료되었습니다!\n\n'
                    '서로에게 리뷰를 남겨주시면\n다른 사용자들에게 도움이 됩니다.',
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('거래가 완료되었습니다'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('완료하기'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅 도움말'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '💡 안전거래 이용법',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. 안전거래 버튼 클릭'),
              Text('2. 법인계좌로 입금'),
              Text('3. 입금확인 요청'),
              Text('4. 상품 수령 후 완료'),
              SizedBox(height: 16),
              Text(
                '📞 고객센터',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('전화: 1588-0000'),
              Text('운영시간: 평일 9:00-18:00'),
              SizedBox(height: 16),
              Text(
                '⚠️ 주의사항',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• 개인정보를 요구하는 경우 신고해주세요'),
              Text('• 직거래 시 안전한 장소에서 만나세요'),
              Text('• 의심스러운 거래는 즉시 신고해주세요'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}