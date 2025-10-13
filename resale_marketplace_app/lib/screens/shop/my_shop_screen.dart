import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/common_app_bar.dart';
import '../../theme/app_theme.dart';
import '../../services/shop_service.dart';
import '../../services/auth_service.dart';
import '../../models/shop_model.dart';

class MyShopScreen extends StatefulWidget {
  const MyShopScreen({super.key});

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShopService _shopService = ShopService();
  final AuthService _authService = AuthService();
  ShopModel? _myShop;
  bool _isLoadingShop = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB
    });
    _loadMyShop();
  }

  Future<void> _loadMyShop() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final shop = await _shopService.getShopByOwnerId(user.id);
      if (mounted) {
        setState(() {
          _myShop = shop;
          _isLoadingShop = false;
        });
      }
    } catch (e) {
      print('Error loading my shop: $e');
      if (mounted) {
        setState(() {
          _isLoadingShop = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _shareShopLink(BuildContext context) async {
    if (_myShop?.shareUrl == null || _myShop!.shareUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('샵 링크를 생성할 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final webLink = 'https://app.everseconds.com/shop/${_myShop!.shareUrl}';
    final shopName = _myShop!.name;
    final message = '$shopName을 확인해보세요!\n\n$webLink';

    try {
      await Share.share(
        message,
        subject: '$shopName 샵 공유',
      );
    } catch (e) {
      // Share not supported, fallback to clipboard
      await Clipboard.setData(ClipboardData(text: webLink));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('샵 링크가 클립보드에 복사되었습니다'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + kTextTabBarHeight),
        child: Column(
          children: [
            ShopAppBar(
              onSharePressed: () => _shareShopLink(context),
            ),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('내 상품'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('대신팔기'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyProductsTab(),
          _ResaleProductsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            // 내 상품 탭 - 상품 등록
            context.push('/product/create');
          } else {
            // 대신팔기 탭 - 대신팔기 상품 찾기
            context.push('/resale/browse');
          }
        },
        backgroundColor: _tabController.index == 0 
            ? AppTheme.primaryColor 
            : Colors.green,
        foregroundColor: Colors.white,
        child: Icon(_tabController.index == 0 ? Icons.add : Icons.search),
      ),
    );
  }
}

class _MyProductsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 내 상품 수익 요약
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[400]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '내 상품 현황',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    title: '총 판매액',
                    value: '₩150,000',
                    textColor: Colors.white,
                    icon: Icons.attach_money,
                  ),
                  _SummaryItem(
                    title: '등록 상품',
                    value: '5개',
                    textColor: Colors.white,
                    icon: Icons.inventory,
                  ),
                  _SummaryItem(
                    title: '판매 완료',
                    value: '3개',
                    textColor: Colors.white,
                    icon: Icons.check_circle,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // 상품 관리 버튼들
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/product/create'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('상품 등록'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: 상품 관리 화면으로 이동
                    context.push('/product/manage');
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('상품 관리'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 상품 리스트
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (context, index) {
              return _ProductListItem(
                title: '아이폰 14 Pro 256GB 딥퍼플',
                price: '₩${(index + 1) * 20000}',
                status: index % 2 == 0 ? '판매중' : '판매완료',
                imageUrl: null, // TODO: 실제 이미지 URL
                description: '상태 좋은 아이폰입니다. 케이스와 함께 드려요.',
                viewCount: (index + 1) * 15,
                likeCount: (index + 1) * 3,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResaleProductsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 대신팔기 수익 요약
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[400]!, Colors.green[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '대신팔기 현황',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    title: '수수료 수익',
                    value: '₩45,000',
                    textColor: Colors.white,
                    icon: Icons.monetization_on,
                  ),
                  _SummaryItem(
                    title: '대신팔기',
                    value: '8개',
                    textColor: Colors.white,
                    icon: Icons.store,
                  ),
                  _SummaryItem(
                    title: '판매 성공',
                    value: '3개',
                    textColor: Colors.white,
                    icon: Icons.trending_up,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // 대신팔기 관리 버튼들
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: 대신팔기 상품 탐색 화면으로 이동
                    context.push('/resale/browse');
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('상품 찾기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push('/resale/manage');
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('상품 관리'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 대신팔기 상품 리스트
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 8,
            itemBuilder: (context, index) {
              return _ProductListItem(
                title: '갤럭시 S23 Ultra 512GB',
                price: '₩${(index + 1) * 15000}',
                status: '대신팔기중',
                isResale: true,
                imageUrl: null, // TODO: 실제 이미지 URL
                description: '원 판매자: 김철수님',
                viewCount: (index + 1) * 12,
                likeCount: (index + 1) * 2,
                commissionRate: 15.0, // 15% 수수료
              );
            },
          ),
        ),
      ],
    );
  }


}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final Color? textColor;
  final IconData? icon;
  
  const _SummaryItem({
    required this.title,
    required this.value,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Colors.grey;
    final valueColor = textColor ?? Colors.black;
    
    return Column(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ProductListItem extends StatelessWidget {
  final String title;
  final String price;
  final String status;
  final bool isResale;
  final String? imageUrl;
  final String? description;
  final int? viewCount;
  final int? likeCount;
  final double? commissionRate;
  
  const _ProductListItem({
    required this.title,
    required this.price,
    required this.status,
    this.isResale = false,
    this.imageUrl,
    this.description,
    this.viewCount,
    this.likeCount,
    this.commissionRate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // TODO: 상품 상세/수정 화면으로 이동
          if (isResale) {
            context.push('/resale/detail');
          } else {
            context.push('/product/detail');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상품 이미지
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                  image: imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl == null
                    ? Icon(
                        isResale ? Icons.storefront : Icons.inventory_2,
                        color: Colors.grey[600],
                        size: 32,
                      )
                    : null,
              ),
              
              const SizedBox(width: 12),
              
              // 상품 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목과 상태
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status, isResale),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusTextColor(status, isResale),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // 가격
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // 설명 또는 원 판매자 정보
                    if (description != null)
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // 통계 정보
                    Row(
                      children: [
                        if (viewCount != null) ...[
                          Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            '$viewCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (likeCount != null) ...[
                          Icon(Icons.favorite, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            '$likeCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (isResale && commissionRate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '수수료 ${commissionRate!.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, bool isResale) {
    if (isResale) {
      switch (status) {
        case '대신팔기중':
          return Colors.green[100]!;
        case '판매완료':
          return Colors.blue[100]!;
        default:
          return Colors.grey[100]!;
      }
    } else {
      switch (status) {
        case '판매중':
          return Colors.blue[100]!;
        case '판매완료':
          return Colors.green[100]!;
        default:
          return Colors.grey[100]!;
      }
    }
  }

  Color _getStatusTextColor(String status, bool isResale) {
    if (isResale) {
      switch (status) {
        case '대신팔기중':
          return Colors.green[800]!;
        case '판매완료':
          return Colors.blue[800]!;
        default:
          return Colors.grey[800]!;
      }
    } else {
      switch (status) {
        case '판매중':
          return Colors.blue[800]!;
        case '판매완료':
          return Colors.green[800]!;
        default:
          return Colors.grey[800]!;
      }
    }
  }
}