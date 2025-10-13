import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../services/shop_service.dart';
import '../shop/public_shop_screen.dart';

/// 🔗 다른 사용자 프로필 화면 (딥링크용)
/// 웹/앱 딥링크: https://app.everseconds.com/user/{userId} | resale://user/{userId}
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserService _userService = UserService();
  final ShopService _shopService = ShopService();
  
  UserModel? _user;
  ShopModel? _shop;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 사용자 정보 로드
      final user = await _userService.getUserById(widget.userId);
      if (user == null) {
        setState(() {
          _errorMessage = '사용자를 찾을 수 없습니다.';
          _isLoading = false;
        });
        return;
      }

      // 사용자의 샵 정보 로드
      ShopModel? shop;
      if (user.shopId != null) {
        shop = await _shopService.getShopById(user.shopId!);
      }

      setState(() {
        _user = user;
        _shop = shop;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '프로필을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.name ?? '사용자 프로필'),
        actions: [
          if (_user != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareProfile,
              tooltip: '프로필 공유',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('프로필을 불러오는 중...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserProfile,
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_user == null) {
      return const Center(
        child: Text('사용자 정보를 찾을 수 없습니다.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            if (_shop != null) ...[
              _buildShopSection(),
              const SizedBox(height: 24),
            ],
            _buildStatsSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 프로필 이미지
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 사용자 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_user!.email != null) ...[
                    Text(
                      _user!.email!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    '가입일: ${_formatDate(_user!.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopSection() {
    if (_shop == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  '샵 정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _shop!.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_shop!.description != null) ...[
              const SizedBox(height: 4),
              Text(
                _shop!.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '상품 ${_shop!.totalProductCount}개',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _visitShop(),
              icon: const Icon(Icons.store),
              label: const Text('샵 방문하기'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  '활동 정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '판매 상품',
                    '${_shop?.ownProductCount ?? 0}개',
                    Icons.sell,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '대신팔기',
                    '${_shop?.resaleCount ?? 0}개',
                    Icons.handshake,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final currentUser = context.read<AuthProvider>().currentUser;
    
    // 본인 프로필인 경우
    if (currentUser?.id == widget.userId) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/profile'),
                icon: const Icon(Icons.edit),
                label: const Text('프로필 수정'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 다른 사용자 프로필인 경우
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _startChat,
              icon: const Icon(Icons.chat),
              label: const Text('채팅하기'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _visitShop() {
    if (_shop?.shareUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicShopScreen(shareUrl: _shop!.shareUrl!),
        ),
      );
    }
  }

  void _startChat() {
    // TODO: 채팅 시작 로직 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('채팅 기능은 준비 중입니다.')),
    );
  }

  void _shareProfile() {
    final webLink = 'https://app.everseconds.com/user/${widget.userId}';
    final appLink = 'resale://user/${widget.userId}';
    
    Share.share(
      '${_user!.name}님의 프로필을 확인해보세요!\n\n'
      '웹에서 보기: $webLink\n'
      '앱에서 보기: $appLink',
      subject: '${_user!.name}님의 프로필',
    );

    // 클립보드에도 복사
    Clipboard.setData(ClipboardData(text: webLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('링크가 클립보드에 복사되었습니다')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}