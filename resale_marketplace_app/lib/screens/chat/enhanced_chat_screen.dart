import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/realtime_chat_service.dart';
import '../../theme/app_theme.dart';

class EnhancedChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserId;
  final String? productId;

  const EnhancedChatScreen({
    super.key,
    required this.chatRoomId,
    required this.otherUserId,
    this.productId,
  });

  @override
  State<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends State<EnhancedChatScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final RealtimeChatService _realtimeChatService = RealtimeChatService();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<ChatMessageModel> _messages = [];
  UserModel? _otherUser;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _isTyping = false;
  String _typingUserId = '';
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  StreamSubscription? _chatEventSubscription;
  Timer? _typingTimer;
  
  late AnimationController _typingAnimationController;
  late AnimationController _fabAnimationController;

  double _screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  String _initial(String? value) {
    if (value == null) return '?';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeChat();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _chatEventSubscription?.cancel();
    _typingTimer?.cancel();
    _typingAnimationController.dispose();
    _fabAnimationController.dispose();
    _realtimeChatService.leaveChatRoom(widget.chatRoomId);
    super.dispose();
  }

  void _setupAnimations() {
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _initializeChat() async {
    try {
      setState(() => _isLoading = true);

      // 채팅방 정보 로드
      await _loadChatData();
      
      // 실시간 채팅방 입장
      await _realtimeChatService.joinChatRoom(widget.chatRoomId);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅을 불러오는데 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadChatData() async {
    final messagesFuture = _chatService.getChatRoomMessages(
      widget.chatRoomId,
    );
    final userFuture = _chatService.getUserById(widget.otherUserId);

    final messages = await messagesFuture;
    final otherUser = await userFuture;

    if (!mounted) return;

    setState(() {
      _messages = messages;
      _otherUser = otherUser;
    });

    _scrollToBottom();
  }

  void _setupRealtimeListeners() {
    _chatEventSubscription = _realtimeChatService.eventStream.listen((event) {
      switch (event.type) {
        case ChatEventType.messageReceived:
          _handleNewMessage(event.data as ChatMessageModel);
          break;
        case ChatEventType.messageDelivered:
          _handleMessageDelivered(event.data as ChatMessageModel);
          break;
        case ChatEventType.messageRead:
          _handleMessageRead(event.data as ChatMessageModel);
          break;
        case ChatEventType.typing:
          _handleTypingEvent(event.userId!);
          break;
        case ChatEventType.stopTyping:
          _handleStopTypingEvent(event.userId!);
          break;
        case ChatEventType.userOnline:
        case ChatEventType.userOffline:
          _handlePresenceUpdate();
          break;
      }
    });
  }

  void _handleNewMessage(ChatMessageModel message) {
    if (mounted && message.chatRoomId == widget.chatRoomId) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
      
      // 상대방 메시지인 경우 읽음 처리
      if (message.senderId !=
          context.read<AuthProvider>().currentUser?.id) {
        _realtimeChatService.markMessageAsRead(message.id);
      }
    }
  }

  void _handleMessageDelivered(ChatMessageModel message) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = message;
      }
    });
  }

  void _handleMessageRead(ChatMessageModel message) {
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = message;
        }
      });
    }
  }

  void _handleTypingEvent(String userId) {
    if (userId != context.read<AuthProvider>().currentUser?.id) {
      setState(() {
        _isTyping = true;
        _typingUserId = userId;
      });
      _typingAnimationController.repeat();
      
      // 5초 후 자동으로 타이핑 상태 해제
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 5), () {
        _handleStopTypingEvent(userId);
      });
    }
  }

  void _handleStopTypingEvent(String userId) {
    if (userId == _typingUserId) {
      setState(() {
        _isTyping = false;
        _typingUserId = '';
      });
      _typingAnimationController.stop();
      _typingTimer?.cancel();
    }
  }

  void _handlePresenceUpdate() {
    // 온라인 상태 업데이트 (UI 갱신)
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToBottom() {
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _messageController.clear();
    });

    try {
      await _realtimeChatService.sendMessage(
        roomId: widget.chatRoomId,
        content: content,
        messageType: 'text',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendImageMessage() async {
    try {
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다. 다시 시도해주세요.')),
        );
        return;
      }
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (images.isNotEmpty) {
        setState(() => _isSending = true);

        // 이미지 업로드
        final imageUrls = <String>[];
        for (final image in images) {
          final imageUrl = await _chatService.uploadChatImage(
            File(image.path),
            widget.chatRoomId,
            currentUserId,
          );
          if (imageUrl != null) {
            imageUrls.add(imageUrl);
          }
        }

        if (imageUrls.isNotEmpty) {
          await _realtimeChatService.sendImageMessage(
            roomId: widget.chatRoomId,
            imageUrls: imageUrls,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 전송에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _onMessageTextChanged(String text) {
    if (text.isNotEmpty) {
      _realtimeChatService.startTyping(widget.chatRoomId);
    } else {
      _realtimeChatService.stopTyping(widget.chatRoomId);
    }
  }

  void _showImageViewer(List<String> imageUrls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImageViewerScreen(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
    
    if (_showEmojiPicker) {
      _messageFocusNode.unfocus();
    } else {
      _messageFocusNode.requestFocus();
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    _messageController.text += emoji.emoji;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Widget _buildMessage(ChatMessageModel message) {
    final isMe =
        message.senderId == context.read<AuthProvider>().currentUser?.id;

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 4,
        horizontal: _screenWidth(context) * 0.04,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: message.sender?.profileImage != null
                  ? CachedNetworkImageProvider(message.sender!.profileImage!)
                  : null,
              child: message.sender?.profileImage == null
                  ? Text(
                      _initial(message.sender?.name),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && message.sender != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.sender!.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                _buildMessageBubble(message, isMe),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.formattedTime,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 12,
                        color: message.isRead ? AppTheme.primaryColor : Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: _screenWidth(context) * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primaryColor : Colors.grey[200],
        borderRadius: BorderRadius.circular(18),
      ),
      child: message.isImageMessage
          ? _buildImageContent(message)
          : _buildTextContent(message, isMe),
    );
  }

  Widget _buildTextContent(ChatMessageModel message, bool isMe) {
    return Text(
      message.content,
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black87,
        fontSize: 16,
      ),
    );
  }

  Widget _buildImageContent(ChatMessageModel message) {
    final imageUrls = message.imageUrls!;
    
    if (imageUrls.length == 1) {
      return _buildSingleImage(imageUrls.first, imageUrls, 0);
    } else {
      return _buildMultipleImages(imageUrls);
    }
  }

  Widget _buildSingleImage(String imageUrl, List<String> allUrls, int index) {
    return GestureDetector(
      onTap: () => _showImageViewer(allUrls, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: _screenWidth(context) * 0.6,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: _screenWidth(context) * 0.6,
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            width: _screenWidth(context) * 0.6,
            height: 200,
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          ),
        ),
      ),
    );
  }

  Widget _buildMultipleImages(List<String> imageUrls) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: imageUrls.length == 2 ? 2 : 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: imageUrls.length > 4 ? 4 : imageUrls.length,
      itemBuilder: (context, index) {
        final isLastItem = index == 3 && imageUrls.length > 4;
        
        return GestureDetector(
          onTap: () => _showImageViewer(imageUrls, index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrls[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
              if (isLastItem)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '+${imageUrls.length - 3}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    if (!_isTyping) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: _screenWidth(context) * 0.04,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: _otherUser?.profileImage != null
                ? CachedNetworkImageProvider(_otherUser!.profileImage!)
                : null,
            child: _otherUser?.profileImage == null
                ? Text(
                    _initial(_otherUser?.name),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _typingAnimationController,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (index) {
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[
                              400 + ((_typingAnimationController.value * 3).floor() == index ? 200 : 0)
                            ],
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _sendImageMessage,
                icon: const Icon(Icons.add_photo_alternate),
                color: AppTheme.primaryColor,
              ),
              IconButton(
                onPressed: _toggleEmojiPicker,
                icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions),
                color: AppTheme.primaryColor,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  onChanged: _onMessageTextChanged,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _messageController,
                builder: (context, child) {
                  final hasText = _messageController.text.trim().isNotEmpty;
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: hasText ? 48 : 0,
                    child: hasText
                        ? IconButton(
                            onPressed: _isSending ? null : _sendMessage,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            color: AppTheme.primaryColor,
                          )
                        : null,
                  );
                },
              ),
            ],
          ),
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: _onEmojiSelected,
                config: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  categoryViewConfig: CategoryViewConfig(
                    initCategory: Category.RECENT,
                    backgroundColor: const Color(0xFFF2F2F2),
                    indicatorColor: AppTheme.primaryColor,
                    iconColor: Colors.grey,
                    iconColorSelected: AppTheme.primaryColor,
                    backspaceColor: AppTheme.primaryColor,
                    categoryIcons: const CategoryIcons(),
                    tabIndicatorAnimDuration: kTabScrollDuration,
                  ),
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28,
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    gridPadding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFFF2F2F2),
                    recentsLimit: 28,
                    noRecents: const Text(
                      '최근 사용한 이모지가 없습니다',
                      style: TextStyle(fontSize: 16, color: Colors.black26),
                      textAlign: TextAlign.center,
                    ),
                    loadingIndicator: const SizedBox.shrink(),
                    buttonMode: ButtonMode.MATERIAL,
                  ),
                  skinToneConfig: const SkinToneConfig(
                    enabled: true,
                    dialogBackgroundColor: Colors.white,
                    indicatorColor: Colors.grey,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: const Color(0xFFF2F2F2),
                    buttonColor: AppTheme.primaryColor,
                    buttonIconColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _realtimeChatService.isUserOnline(widget.otherUserId);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: _otherUser?.profileImage != null
                      ? CachedNetworkImageProvider(_otherUser!.profileImage!)
                      : null,
                  child: _otherUser?.profileImage == null
                      ? Text(
                          _initial(_otherUser?.name),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUser?.name ?? '사용자',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isOnline)
                    const Text(
                      '온라인',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  // 프로필 보기
                  break;
                case 'block':
                  // 차단하기
                  break;
                case 'report':
                  // 신고하기
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('프로필 보기'),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('차단하기'),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('신고하기'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Column(
                        children: [
                          _buildMessage(message),
                          if (index == _messages.length - 1) _buildTypingIndicator(),
                        ],
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}

class _ImageViewerScreen extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _ImageViewerScreen({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${initialIndex + 1} / ${imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // 이미지 저장 기능
            },
            icon: const Icon(Icons.download, color: Colors.white),
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(imageUrls[index]),
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(tag: imageUrls[index]),
          );
        },
        itemCount: imageUrls.length,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        pageController: PageController(initialPage: initialIndex),
      ),
    );
  }
}
