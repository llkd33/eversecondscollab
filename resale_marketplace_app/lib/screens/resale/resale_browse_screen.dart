import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/search_bar.dart' as custom;
import '../../theme/app_theme.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/product_service.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';

class ResaleBrowseScreen extends StatefulWidget {
  const ResaleBrowseScreen({super.key});

  @override
  State<ResaleBrowseScreen> createState() => _ResaleBrowseScreenState();
}

class _ResaleBrowseScreenState extends State<ResaleBrowseScreen> {
  String _selectedCategory = '전체';
  String _searchQuery = '';
  final List<String> _categories = ['전체', '전자기기', '의류', '생활용품', '도서', '기타'];
  
  final ProductService _productService = ProductService();
  final ShopService _shopService = ShopService();
  final UserService _userService = UserService();
  
  List<ProductModel> _resaleProducts = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadResaleProducts();
  }
  
  Future<void> _loadResaleProducts() async {
    try {
      setState(() => _isLoading = true);
      
      // 현재 사용자 정보 가져오기
      _currentUser = await _userService.getCurrentUser();
      
      // 대신팔기 가능한 상품들 가져오기
      final products = await _productService.getResaleEnabledProducts(
        category: _selectedCategory == '전체' ? null : _selectedCategory,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
      
      setState(() {
        _resaleProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading resale products: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상품을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '대신팔기 상품 찾기',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.all(16),
            child: custom.CustomSearchBar(
              hintText: '대신팔기 가능한 상품을 검색하세요',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                // 검색어 변경 시 500ms 후 자동 검색
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchQuery == value) {
                    _loadResaleProducts();
                  }
                });
              },
            ),
          ),
          
          // 카테고리 필터
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                      _loadResaleProducts();
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryColor,
                  ),
                );
              },
            ),
          ),
          
          // 대신팔기 가능 상품 안내
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '대신팔기 가능한 상품만 표시됩니다. 상품을 선택하여 내 샵에 추가하세요!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 상품 리스트
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _resaleProducts.isEmpty
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
                              '대신팔기 가능한 상품이 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '다른 카테고리나 검색어를 시도해보세요',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadResaleProducts,
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _resaleProducts.length,
                          itemBuilder: (context, index) {
                            final product = _resaleProducts[index];
                            return _ResaleProductCard(
                              product: product,
                              onAddToShop: () => _showAddToShopDialog(context, product),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('필터 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('수수료율'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('5% 이상'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('10% 이상'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('가격대'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('10만원 이하'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('10만원 이상'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                ),
              ],
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
              // TODO: 필터 적용 로직
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  void _showAddToShopDialog(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 샵에 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '가격: ${product.formattedPrice}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('수수료율: ${product.resaleFeePercentage?.toStringAsFixed(1) ?? '0'}%'),
            Text('예상 수수료: ${product.formattedResaleFee}'),
            const SizedBox(height: 8),
            Text('원 판매자: ${product.sellerName ?? '알 수 없음'}'),
            const SizedBox(height: 16),
            const Text(
              '이 상품을 내 샵에 추가하시겠습니까?\n판매 성공 시 설정된 수수료를 받을 수 있습니다.',
              style: TextStyle(fontSize: 14),
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
              _addToMyShop(product);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('추가하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _addToMyShop(ProductModel product) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 사용자의 샵 정보 가져오기
      final userShop = await _shopService.getShopByOwnerId(_currentUser!.id);
      if (userShop == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('샵 정보를 찾을 수 없습니다'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 대신팔기 상품 추가
      final success = await _shopService.addResaleProduct(
        shopId: userShop.id,
        productId: product.id,
        commissionPercentage: product.resaleFeePercentage ?? 0,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${product.title}이(가) 내 샵에 추가되었습니다'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              action: SnackBarAction(
                label: '내 샵 보기',
                textColor: Colors.white,
                onPressed: () {
                  context.pop(); // 현재 화면 닫기
                  context.push('/shop/my'); // 내 샵으로 이동
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('상품 추가에 실패했습니다'),
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

class _ResaleProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onAddToShop;

  const _ResaleProductCard({
    required this.product,
    required this.onAddToShop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상품 이미지
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                image: product.images.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.images.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.images.isEmpty
                  ? Icon(
                      Icons.storefront,
                      color: Colors.grey[600],
                      size: 40,
                    )
                  : null,
            ),
          ),
          
          // 상품 정보
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.formattedPrice,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '판매자: ${product.sellerName ?? '알 수 없음'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
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
                          '수수료 ${product.resaleFeePercentage?.toStringAsFixed(1) ?? '0'}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: onAddToShop,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            '추가',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}