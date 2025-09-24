import 'package:flutter/material.dart';
import '../../widgets/common_app_bar.dart';
import '../../theme/app_theme.dart';
import '../../widgets/safe_network_image.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import 'package:go_router/go_router.dart';

class ChatListScreen extends StatefulWidget {
  final UserModel? initialUser;
  final List<ChatModel>? initialChats;
  final Future<UserModel?> Function()? userLoaderOverride;
  final Future<List<ChatModel>> Function(String userId)? chatLoaderOverride;
  final bool deferInitialLoad;

  const ChatListScreen({
    super.key,
    this.initialUser,
    this.initialChats,
    this.userLoaderOverride,
    this.chatLoaderOverride,
    this.deferInitialLoad = false,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  ChatService? _chatService;
  AuthService? _authService;
  List<ChatModel> _chats = [];
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;

    if (widget.initialChats != null) {
      _chats = List<ChatModel>.from(widget.initialChats!);
      _isLoading = false;
    }

    if (!widget.deferInitialLoad && widget.initialChats == null) {
      _loadChats();
    } else if (widget.deferInitialLoad) {
      _isLoading = false;
    }
  }

  Future<void> _loadChats() async {
    try {
      setState(() => _isLoading = true);

      final user =
          _currentUser ??
          (widget.userLoaderOverride != null
              ? await widget.userLoaderOverride!()
              : await (_authService ??= AuthService()).getCurrentUser());

      _currentUser = user;

      if (user != null) {
        final chats = widget.chatLoaderOverride != null
            ? await widget.chatLoaderOverride!(user.id)
            : await (_chatService ??= ChatService()).getMyChats(user.id);

        if (!mounted) return;
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading chats: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ChatAppBar(),
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildChatList(),
    );
  }

  Widget _buildChatList() {
    if (_chats.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _chats.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return _ChatListItem(
            chat: chat,
            currentUserId: _currentUser?.id ?? '',
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: AppSpacing.md),
          Text(
            '아직 채팅방이 없습니다',
            style: AppStyles.headingSmall.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '상품에 관심을 표시하면\n채팅방이 생성됩니다',
            style: AppStyles.bodyMedium.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final ChatModel chat;
  final String currentUserId;

  const _ChatListItem({required this.chat, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final hasUnreadMessages = (chat.unreadCount ?? 0) > 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToChatRoom(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _buildUserAvatar(),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildChatInfo(hasUnreadMessages)),
              const SizedBox(width: AppSpacing.sm),
              _buildProductPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    // 대화 상대방 찾기
    final otherParticipant = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          backgroundImage: chat.otherUserProfileImage != null
              ? NetworkImage(chat.otherUserProfileImage!)
              : null,
          child: chat.otherUserProfileImage == null
              ? Text(
                  chat.otherUserName?.substring(0, 1).toUpperCase() ??
                  (otherParticipant.isNotEmpty
                      ? otherParticipant.substring(0, 1).toUpperCase()
                      : '?'),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        if (chat.isResaleChat)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.store,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatInfo(bool hasUnreadMessages) {
    // 상대방 이름 가져오기 (실제 이름 또는 ID 사용)
    final otherParticipant = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => 'Unknown',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chat.otherUserName ?? otherParticipant,
                      style: AppStyles.bodyMedium.copyWith(
                        fontWeight: hasUnreadMessages
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (chat.isResaleChat) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '대신팔기',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              _formatTime(chat.lastMessageTime ?? chat.updatedAt),
              style: AppStyles.bodySmall.copyWith(
                color: hasUnreadMessages
                    ? AppTheme.primaryColor
                    : Colors.grey[600],
                fontWeight: hasUnreadMessages
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // 대신팔기 정보 표시
        if (chat.isResaleChat && chat.resellerName != null) ...[
          Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: Colors.blue[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${chat.resellerName}님이 대신 판매중',
                  style: AppStyles.bodySmall.copyWith(
                    color: Colors.blue[600],
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Text(
          chat.lastMessage ?? '대화를 시작하세요',
          style: AppStyles.bodySmall.copyWith(
            fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.normal,
            color: hasUnreadMessages ? Colors.black87 : Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if ((chat.unreadCount ?? 0) > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  chat.unreadCount! > 99 ? '99+' : chat.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  Widget _buildProductPreview() {
    if (chat.productId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 80,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
            child: chat.productImage != null
                ? SafeNetworkImage(
                    imageUrl: chat.productImage!,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(6),
                  )
                : const Icon(Icons.image, color: Colors.grey, size: 20),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            chat.productTitle ?? '상품',
            style: AppStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    if (price >= 10000) {
      final man = price ~/ 10000;
      final remainder = price % 10000;
      if (remainder == 0) {
        return '${man}만';
      } else {
        return '${man}만 ${remainder ~/ 1000}천';
      }
    } else if (price >= 1000) {
      return '${price ~/ 1000}천';
    } else {
      return price.toString();
    }
  }

  void _navigateToChatRoom(BuildContext context) {
    final otherParticipant = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => 'Unknown',
    );

    context.push(
      '/chat_room',
      extra: {
        'chatRoomId': chat.id,
        'userName': chat.otherUserName ?? otherParticipant,
        'productTitle': chat.productTitle ?? '',
      },
    );
  }
}
