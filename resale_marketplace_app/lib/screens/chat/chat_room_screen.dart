import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;
  final String userName;
  final String productTitle;

  const ChatRoomScreen({
    super.key,
    required this.chatRoomId,
    required this.userName,
    required this.productTitle,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_MockMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMockMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMockMessages() {
    // TODO: 실제 메시지 데이터로 교체
    _messages.addAll([
      _MockMessage(
        id: '1',
        content: '안녕하세요! ${widget.productTitle}에 관심이 있어서 연락드렸습니다.',
        senderId: 'other',
        senderName: widget.userName,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: MessageType.text,
      ),
      _MockMessage(
        id: '2',
        content: '네, 안녕하세요! 어떤 부분이 궁금하신가요?',
        senderId: 'me',
        senderName: '나',
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: -5)),
        type: MessageType.text,
      ),
      _MockMessage(
        id: '3',
        content: '상품 상태는 어떤가요? 사용감이 많이 있나요?',
        senderId: 'other',
        senderName: widget.userName,
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        type: MessageType.text,
      ),
      _MockMessage(
        id: '4',
        content: '거의 새 제품 수준입니다. 박스와 구성품도 모두 있어요.',
        senderId: 'me',
        senderName: '나',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 25)),
        type: MessageType.text,
      ),
      _MockMessage(
        id: '5',
        content: '안전거래로 진행하고 싶은데 가능한가요?',
        senderId: 'other',
        senderName: widget.userName,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        type: MessageType.text,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildProductInfo(),
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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == 'me';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildMessageBubble(message, isMe),
        );
      },
    );
  }

  Widget _buildMessageBubble(_MockMessage message, bool isMe) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              message.senderName.substring(0, 1),
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
                padding: const EdgeInsets.symmetric(
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
                child: Text(
                  message.content,
                  style: AppStyles.bodyMedium.copyWith(
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatMessageTime(message.timestamp),
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
            child: const Text(
              '나',
              style: TextStyle(
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

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final newMessage = _MockMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      senderId: 'me',
      senderName: '나',
      timestamp: DateTime.now(),
      type: MessageType.text,
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });

    // 메시지 전송 후 스크롤을 맨 아래로
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // TODO: 실제 메시지 전송 로직 구현
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

enum MessageType {
  text,
  image,
  system,
}

class _MockMessage {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final MessageType type;

  _MockMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.type,
  });
}