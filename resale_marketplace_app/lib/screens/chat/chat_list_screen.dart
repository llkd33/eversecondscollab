import 'package:flutter/material.dart';
import '../../widgets/common_app_bar.dart';
import '../../theme/app_theme.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ChatAppBar(),
      backgroundColor: AppTheme.backgroundColor,
      body: _buildChatList(),
    );
  }

  Widget _buildChatList() {
    // TODO: 실제 채팅방 데이터로 교체
    final mockChatRooms = List.generate(8, (index) => _MockChatRoom(
      id: 'chat_$index',
      userName: '사용자${index + 1}',
      userAvatar: null,
      productTitle: _getProductTitle(index),
      productPrice: _getProductPrice(index),
      productImage: null,
      lastMessage: _getLastMessage(index),
      lastMessageTime: _getLastMessageTime(index),
      unreadCount: index % 3 == 0 ? (index % 5) + 1 : 0,
      isOnline: index % 4 == 0,
    ));

    if (mockChatRooms.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: mockChatRooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return _ChatListItem(chatRoom: mockChatRooms[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '아직 채팅방이 없습니다',
            style: AppStyles.headingSmall.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '상품에 관심을 표시하면\n채팅방이 생성됩니다',
            style: AppStyles.bodyMedium.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getProductTitle(int index) {
    final products = [
      '아이폰 14 Pro 256GB',
      '삼성 갤럭시 S23',
      '맥북 에어 M2',
      '에어팟 프로 2세대',
      '아이패드 프로 11인치',
      '닌텐도 스위치',
      '소니 WH-1000XM4',
      '애플워치 시리즈 8',
    ];
    return products[index % products.length];
  }

  int _getProductPrice(int index) {
    final prices = [1200000, 800000, 1500000, 250000, 900000, 350000, 300000, 450000];
    return prices[index % prices.length];
  }

  String _getLastMessage(int index) {
    final messages = [
      '네, 언제 거래 가능하신가요?',
      '상품 상태는 어떤가요?',
      '직거래 가능한가요?',
      '안전거래로 진행하고 싶어요',
      '사진 더 보여주실 수 있나요?',
      '가격 조금 더 깎아주실 수 있나요?',
      '내일 거래 가능할까요?',
      '운송장 번호 알려주세요',
    ];
    return messages[index % messages.length];
  }

  String _getLastMessageTime(int index) {
    final times = [
      '방금 전',
      '5분 전',
      '1시간 전',
      '오후 2:30',
      '오전 11:15',
      '어제',
      '2일 전',
      '1주일 전',
    ];
    return times[index % times.length];
  }
}

class _MockChatRoom {
  final String id;
  final String userName;
  final String? userAvatar;
  final String productTitle;
  final int productPrice;
  final String? productImage;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  _MockChatRoom({
    required this.id,
    required this.userName,
    this.userAvatar,
    required this.productTitle,
    required this.productPrice,
    this.productImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isOnline,
  });
}

class _ChatListItem extends StatelessWidget {
  final _MockChatRoom chatRoom;
  
  const _ChatListItem({required this.chatRoom});

  @override
  Widget build(BuildContext context) {
    final hasUnreadMessages = chatRoom.unreadCount > 0;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToChatRoom(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _buildUserAvatar(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildChatInfo(hasUnreadMessages),
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildProductPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          backgroundImage: chatRoom.userAvatar != null 
              ? NetworkImage(chatRoom.userAvatar!) 
              : null,
          child: chatRoom.userAvatar == null
              ? Text(
                  chatRoom.userName.substring(0, 1),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        if (chatRoom.isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatInfo(bool hasUnreadMessages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                chatRoom.userName,
                style: AppStyles.bodyMedium.copyWith(
                  fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              chatRoom.lastMessageTime,
              style: AppStyles.bodySmall.copyWith(
                color: hasUnreadMessages ? AppTheme.primaryColor : Colors.grey[600],
                fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          chatRoom.lastMessage,
          style: AppStyles.bodySmall.copyWith(
            fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.normal,
            color: hasUnreadMessages ? Colors.black87 : Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (chatRoom.unreadCount > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  chatRoom.unreadCount > 99 ? '99+' : chatRoom.unreadCount.toString(),
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

  Widget _buildProductPreview() {
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
            child: chatRoom.productImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      chatRoom.productImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.image,
                    color: Colors.grey,
                    size: 20,
                  ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            chatRoom.productTitle,
            style: AppStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${_formatPrice(chatRoom.productPrice)}원',
            style: AppStyles.bodySmall.copyWith(
              color: AppTheme.secondaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
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
    // TODO: 실제 채팅방 화면으로 네비게이션 구현
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatRoomId: chatRoom.id,
          userName: chatRoom.userName,
          productTitle: chatRoom.productTitle,
        ),
      ),
    );
  }
}