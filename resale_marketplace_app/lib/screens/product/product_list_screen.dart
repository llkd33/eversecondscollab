import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../widgets/product_card.dart';

class ProductListScreen extends StatefulWidget {
  final String? category;
  final bool? resaleEnabled;
  final String title;
  
  const ProductListScreen({
    super.key,
    this.category,
    this.resaleEnabled,
    this.title = '상품 목록',
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductService _productService = ProductService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<ProductModel> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String _currentSearch = '';
  String? _selectedCategory;
  
  final List<String> _categories = [
    '전체',
    '의류',
    '전자기기',
    '생활용품',
    '가구/인테리어',
    '도서/문구',
    '스포츠/레저',
    '뷰티/미용',
    '식품',
    '반려동물용품',
    '기타'
  ];
  
  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _scrollController.addListener(_onScroll);
    _loadProducts();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_hasMore && !_isLoading) {
        _loadMoreProducts();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CommonAppBar(
        title: widget.title,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: Column(
          children: [
            // 검색바 (검색 중일 때만 표시)
            if (_currentSearch.isNotEmpty) _buildSearchBar(),
            
            // 카테고리 필터
            _buildCategoryFilter(),
            
            // 상품 목록
            Expanded(
              child: _buildProductList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '상품을 검색해보세요',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _currentSearch = '';
                      _refreshProducts();
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: _performSearch,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = (category == '전체' && _selectedCategory == null) ||
                           category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? 
                    (category == '전체' ? null : category) : null;
                });
                _refreshProducts();
              },
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildProductList() {
    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_products.isEmpty) {
      return _buildEmptyState();
    }
    
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _products.length + (_isLoading ? 2 : 0),
      itemBuilder: (context, index) {
        if (index < _products.length) {
          return ProductCard(
            product: _products[index],
            onTap: () => _navigateToProduct(_products[index]),
          );
        } else {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
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
            _currentSearch.isNotEmpty 
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
            _currentSearch.isNotEmpty
                ? '다른 키워드로 검색해보세요'
                : '첫 번째 상품을 등록해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (_currentSearch.isEmpty) ...[
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
  
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상품 검색'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '검색할 상품명을 입력하세요',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performSearch(_searchController.text);
            },
            child: const Text('검색'),
          ),
        ],
      ),
    );
  }
  
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '필터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '카테고리',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = (category == '전체' && _selectedCategory == null) ||
                                 category == _selectedCategory;
                
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? 
                        (category == '전체' ? null : category) : null;
                    });
                  },
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryColor,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                        _currentSearch = '';
                        _searchController.clear();
                      });
                      Navigator.pop(context);
                      _refreshProducts();
                    },
                    child: const Text('초기화'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _refreshProducts();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text(
                      '적용',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _performSearch(String query) {
    setState(() {
      _currentSearch = query.trim();
      _searchController.text = _currentSearch;
    });
    _refreshProducts();
  }
  
  Future<void> _loadProducts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final products = await _productService.getProducts(
        category: _selectedCategory,
        searchQuery: _currentSearch.isEmpty ? null : _currentSearch,
        resaleEnabled: widget.resaleEnabled,
        limit: 20,
        offset: _currentPage * 20,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상품을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
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
  
  void _navigateToProduct(ProductModel product) {
    context.push('/product/detail/${product.id}', extra: product);
  }
}