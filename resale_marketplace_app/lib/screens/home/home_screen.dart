import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_bar.dart' as custom;
import '../../theme/app_theme.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../widgets/common/loading_widgets.dart';
import '../../widgets/common/error_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProductService _productService = ProductService();
  final ScrollController _scrollController = ScrollController();
  
  String _selectedCategory = '전체';
  String _searchQuery = '';
  bool _isGridView = true;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  
  List<ProductModel> _products = [];

  static String _getLocation(int index) {
    final locations = ['강남구', '서초구', '송파구', '마포구', '용산구'];
    return locations[index % locations.length];
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _loadMoreProducts();
      }
    }
  }

  Future<void> _loadProducts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _productService.getProducts(
        category: _selectedCategory == '전체' ? null : _selectedCategory,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        status: '판매중',
        limit: 20,
        offset: _currentPage * 20,
        orderBy: 'created_at',
        ascending: false,
      );

      setState(() {
        if (_currentPage == 0) {
          _products = products;
        } else {
          _products.addAll(products);
        }
        
        _hasMore = products.length >= 20;
        _currentPage++;
      });
    } catch (e) {
      if (mounted) {
        CommonSnackBar.showError(
          context,
          '상품을 불러오는데 실패했습니다',
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    await _loadProducts();
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _products.clear();
      _currentPage = 0;
      _hasMore = true;
    });
    
    await _loadProducts();
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _refreshProducts();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HomeAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: Column(
          children: [
            // 검색바
            custom.CustomSearchBar(
              hintText: '상품명, 브랜드, 판매자명으로 검색',
              readOnly: true,
              onTap: () {
                Navigator.pushNamed(context, '/search');
              },
            ),
            
            // 카테고리 필터
            _CategoryFilter(
              selectedCategory: _selectedCategory,
              onCategoryChanged: _onCategoryChanged,
            ),
            
            // 뷰 전환 및 정렬 옵션
            _buildViewControls(),
            
            // 상품 리스트
            Expanded(
              child: _products.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : (_isGridView ? _buildGridView() : _buildListView()),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/product/create'),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildViewControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '총 ${_products.length}개 상품',
            style: AppStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.grid_view,
                  color: _isGridView ? AppTheme.primaryColor : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isGridView = true;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.list,
                  color: !_isGridView ? AppTheme.primaryColor : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isGridView = false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: _products.length + (_isLoading ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return _buildLoadingCard();
        }
        
        final product = _products[index];
        return ProductCard(
          product: product,
          onTap: () => context.push('/product/detail/${product.id}'),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _products.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return _buildLoadingListItem();
        }
        
        final product = _products[index];
        return ProductListCard(
          product: product,
          onTap: () => context.push('/product/detail/${product.id}'),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildLoadingListItem() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          title: Container(
            height: 16,
            color: Colors.grey[200],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                height: 12,
                width: 100,
                color: Colors.grey[200],
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                height: 12,
                width: 150,
                color: Colors.grey[200],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? '검색 결과가 없습니다'
                : '등록된 상품이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? '다른 키워드로 검색해보세요'
                : '첫 번째 상품을 등록해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/product/create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                '상품 등록하기',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  
  const _CategoryFilter({
    required this.selectedCategory,
    required this.onCategoryChanged,
  });
  
  final List<Map<String, dynamic>> _categories = const [
    {'label': '전체', 'icon': Icons.apps},
    {'label': '의류', 'icon': Icons.checkroom},
    {'label': '전자기기', 'icon': Icons.phone_android},
    {'label': '생활용품', 'icon': Icons.home},
    {'label': '도서/문구', 'icon': Icons.book},
    {'label': '스포츠/레저', 'icon': Icons.sports_soccer},
    {'label': '뷰티/미용', 'icon': Icons.face},
    {'label': '기타', 'icon': Icons.more_horiz},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = selectedCategory == category['label'];
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CategoryChip(
              label: category['label'],
              icon: category['icon'],
              isSelected: isSelected,
              onSelected: (selected) {
                onCategoryChanged(category['label']);
              },
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  
  const _CategoryChip({
    required this.label,
    required this.icon,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected?.call(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

