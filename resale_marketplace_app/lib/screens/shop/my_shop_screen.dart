import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../providers/auth_provider.dart';

class MyShopScreen extends StatefulWidget {
  const MyShopScreen({super.key});

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShopService _shopService = ShopService();
  final UserService _userService = UserService();

  UserModel? _currentUser;
  ShopModel? _currentShop;
  List<ProductModel> _myProducts = [];
  List<ProductModel> _resaleProducts = [];
  Map<String, dynamic> _shopStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB
    });
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    print('🔄 내샵 데이터 로딩 시작');
    
    try {
      setState(() => _isLoading = true);

      final authProvider = context.read<AuthProvider>();

      if (!authProvider.isAuthenticated) {
        print('❌ 사용자 인증되지 않음 - 로그인 페이지로 이동');
        if (mounted) {
          const redirectPath = '/shop';
          final encoded = Uri.encodeComponent(redirectPath);
          context.go('/login?redirect=$encoded');
        }
        return;
      }

      _currentUser = authProvider.currentUser;
      print('👤 현재 사용자: ${_currentUser?.id}');

      if (_currentUser == null) {
        print('🔑 자동 로그인 시도');
        final autoLoginSucceeded = await authProvider.tryAutoLogin();
        if (autoLoginSucceeded) {
          _currentUser = authProvider.currentUser;
          print('✅ 자동 로그인 성공: ${_currentUser?.id}');
        } else {
          print('❌ 자동 로그인 실패');
        }
      }

      _currentUser ??= await _userService.getCurrentUser();

      if (_currentUser == null) {
        print('❌ 사용자 정보를 가져올 수 없음');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 불러오지 못했습니다. 다시 로그인해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 사용자의 샵 정보 가져오기
      print('🏪 샵 정보 조회 시작: ${_currentUser!.id}');
      _currentShop = await _shopService.getShopByOwnerId(_currentUser!.id);

      if (_currentShop == null) {
        print('🔨 샵이 없어서 생성 시도');
        _currentShop = await _shopService.ensureUserShop(
          _currentUser!.id,
          _currentUser!.name,
        );
        
        if (_currentShop == null) {
          print('❌ 샵 생성 실패');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('샵을 생성하는데 실패했습니다. 잠시 후 다시 시도해주세요.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } else {
          print('✅ 샵 생성 성공: ${_currentShop!.id}');
        }
      } else {
        print('✅ 기존 샵 정보 조회 성공: ${_currentShop!.id}');
      }

      if (_currentShop != null) {
        // 데이터를 병렬로 가져와서 성능 개선
        print('📦 상품 및 통계 정보 로딩 시작');
        
        final results = await Future.wait([
          // 내 상품 목록 가져오기
          _shopService.getShopProducts(_currentShop!.id).catchError((e) {
            print('❌ 내 상품 로딩 실패: $e');
            return <ProductModel>[];
          }),
          // 대신팔기 상품 목록 가져오기
          _shopService.getShopResaleProducts(_currentShop!.id).catchError((e) {
            print('❌ 대신팔기 상품 로딩 실패: $e');
            return <ProductModel>[];
          }),
          // 샵 통계 가져오기
          _shopService.getShopStats(_currentShop!.id).catchError((e) {
            print('❌ 샵 통계 로딩 실패: $e');
            return <String, dynamic>{};
          }),
        ]);

        _myProducts = results[0] as List<ProductModel>;
        _resaleProducts = results[1] as List<ProductModel>;
        _shopStats = results[2] as Map<String, dynamic>;
        
        print('✅ 데이터 로딩 완료');
        print('  - 내 상품: ${_myProducts.length}개');
        print('  - 대신팔기 상품: ${_resaleProducts.length}개');
        print('  - 통계: ${_shopStats.keys.join(", ")}');
      }
    } catch (e, stackTrace) {
      print('❌ 내샵 데이터 로딩 중 오류 발생: $e');
      print('스택 트레이스: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('샵 정보를 불러오는데 실패했습니다.\n오류: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '재시도',
              textColor: Colors.white,
              onPressed: _loadShopData,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print('🏁 내샵 데이터 로딩 완료');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareShopLink(BuildContext context) {
    if (_currentShop == null) return;

    final shopLink = 'https://resalemarketplace-kea39vgf7-everseconds-projects.vercel.app/shop/${_currentShop!.shareUrl}';

    Clipboard.setData(ClipboardData(text: shopLink));

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: '공유하기',
          textColor: Colors.white,
          onPressed: () {
            _showShareDialog(context, shopLink);
          },
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context, String shopLink) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_currentShop?.name ?? '내 샵'} 공유하기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('내 샵을 친구들에게 공유해보세요!'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(shopLink, style: const TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shopLink));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('링크가 복사되었습니다')),
                      );
                    },
                  ),
                ],
              ),
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
              Share.share(
                '${_currentUser?.name}님의 샵을 확인해보세요!\n$shopLink',
                subject: '${_currentShop?.name} 공유',
              );
            },
            child: const Text('공유하기'),
          ),
        ],
      ),
    );
  }

  void _editShopInfo() {
    if (_currentShop == null) return;

    showDialog(
      context: context,
      builder: (context) => _ShopEditDialog(
        shop: _currentShop!,
        onSave: (name, description) async {
          final success = await _shopService.updateShop(
            shopId: _currentShop!.id,
            name: name,
            description: description,
          );

          if (success) {
            await _loadShopData(); // 데이터 새로고침
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('샵 정보가 업데이트되었습니다')));
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('샵 정보 업데이트에 실패했습니다'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(_currentShop?.name ?? '내 샵'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editShopInfo,
            tooltip: '샵 정보 수정',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareShopLink(context),
            tooltip: '샵 공유',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('내 상품 (${_myProducts.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('대신팔기 (${_resaleProducts.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyProductsTab(
            products: _myProducts,
            stats: _shopStats,
            onRefresh: _loadShopData,
          ),
          _ResaleProductsTab(
            products: _resaleProducts,
            stats: _shopStats,
            onRefresh: _loadShopData,
            onRemoveResale: _removeResaleProduct,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            // 내 상품 탭 - 상품 등록
            context.push('/product/create').then((_) => _loadShopData());
          } else {
            // 대신팔기 탭 - 대신팔기 상품 찾기
            context.push('/resale/browse').then((_) => _loadShopData());
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

  Future<void> _removeResaleProduct(String productId) async {
    if (_currentShop == null) return;

    try {
      final success = await _shopService.removeResaleProduct(
        shopId: _currentShop!.id,
        productId: productId,
      );

      if (success) {
        await _loadShopData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('대신팔기 상품이 제거되었습니다')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('대신팔기 상품 제거에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _MyProductsTab extends StatelessWidget {
  final List<ProductModel> products;
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;

  const _MyProductsTab({
    required this.products,
    required this.stats,
    required this.onRefresh,
  });

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
                    title: '총 상품',
                    value: '${stats['own_product_count'] ?? 0}개',
                    textColor: Colors.white,
                    icon: Icons.inventory,
                  ),
                  _SummaryItem(
                    title: '판매중',
                    value:
                        '${products.where((p) => p.status == '판매중').length}개',
                    textColor: Colors.white,
                    icon: Icons.storefront,
                  ),
                  _SummaryItem(
                    title: '판매완료',
                    value:
                        '${products.where((p) => p.status == '판매완료').length}개',
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
                    context.push('/my-products');
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
          child: products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '등록된 상품이 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '첫 상품을 등록해보세요!',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => onRefresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductListItem(
                        product: product,
                        isResale: false,
                        onTap: () {
                          context.push('/product/detail/${product.id}');
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ResaleProductsTab extends StatelessWidget {
  final List<ProductModel> products;
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;
  final Function(String) onRemoveResale;

  const _ResaleProductsTab({
    required this.products,
    required this.stats,
    required this.onRefresh,
    required this.onRemoveResale,
  });

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
                    title: '대신팔기',
                    value: '${stats['resale_product_count'] ?? 0}개',
                    textColor: Colors.white,
                    icon: Icons.store,
                  ),
                  _SummaryItem(
                    title: '판매중',
                    value:
                        '${products.where((p) => p.status == '판매중').length}개',
                    textColor: Colors.white,
                    icon: Icons.storefront,
                  ),
                  _SummaryItem(
                    title: '판매완료',
                    value:
                        '${products.where((p) => p.status == '판매완료').length}개',
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
          child: products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '대신팔기 상품이 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '상품을 찾아서 대신팔기를 시작해보세요!',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => onRefresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductListItem(
                        product: product,
                        isResale: true,
                        onTap: () {
                          context.push('/product/detail/${product.id}');
                        },
                        onRemoveResale: () => onRemoveResale(product.id),
                      );
                    },
                  ),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          style: TextStyle(fontSize: 12, color: color),
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
  final ProductModel product;
  final bool isResale;
  final VoidCallback? onTap;
  final VoidCallback? onRemoveResale;

  const _ProductListItem({
    required this.product,
    this.isResale = false,
    this.onTap,
    this.onRemoveResale,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
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
                  image: product.images.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(product.images.first),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.images.isEmpty
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
                            product.title,
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
                            color: _getStatusColor(product.status, isResale),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isResale ? '대신팔기중' : product.status,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusTextColor(
                                product.status,
                                isResale,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isResale && onRemoveResale != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('대신팔기 제거'),
                                  content: const Text(
                                    '이 상품을 대신팔기 목록에서 제거하시겠습니까?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('취소'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        onRemoveResale!();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('제거'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.remove_circle_outline,
                                size: 16,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // 가격
                    Text(
                      '₩${product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // 설명 또는 원 판매자 정보
                    if (product.description?.isNotEmpty == true)
                      Text(
                        isResale && product.sellerName != null
                            ? '원 판매자: ${product.sellerName}님'
                            : product.description!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 8),

                    // 통계 정보
                    Row(
                      children: [
                        Icon(Icons.category, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatDate(product.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (isResale &&
                            product.resaleEnabled &&
                            product.resaleFeePercentage != null)
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
                              '수수료 ${product.resaleFeePercentage!.toStringAsFixed(1)}%',
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
      return Colors.green[100]!;
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
      return Colors.green[800]!;
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}

// 샵 앱바 위젯
// 샵 정보 수정 다이얼로그
class _ShopEditDialog extends StatefulWidget {
  final ShopModel shop;
  final Function(String name, String description) onSave;

  const _ShopEditDialog({required this.shop, required this.onSave});

  @override
  State<_ShopEditDialog> createState() => _ShopEditDialogState();
}

class _ShopEditDialogState extends State<_ShopEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shop.name);
    _descriptionController = TextEditingController(
      text: widget.shop.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('샵 정보 수정'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '샵 이름',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '샵 이름을 입력해주세요';
                }
                if (value.length > 50) {
                  return '샵 이름은 50자 이내로 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '샵 설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value != null && value.length > 500) {
                  return '샵 설명은 500자 이내로 입력해주세요';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              widget.onSave(
                _nameController.text.trim(),
                _descriptionController.text.trim(),
              );
            }
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
