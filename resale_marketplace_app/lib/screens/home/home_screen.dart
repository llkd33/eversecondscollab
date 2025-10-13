import 'package:flutter/material.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_bar.dart' as custom;
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/product_card.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = '전체';
  String _searchQuery = '';
  bool _isGridView = true;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // 임시 상품 데이터
  final List<Map<String, dynamic>> _products = List.generate(20, (index) => {
    'id': 'product_$index',
    'title': _getProductTitle(index),
    'price': (index + 1) * 15000 + (index % 3) * 5000,
    'sellerName': '판매자${index + 1}',
    'sellerLevel': (index % 5) + 1,
    'isResaleEnabled': index % 3 == 0,
    'location': _getLocation(index),
    'createdAt': DateTime.now().subtract(Duration(hours: index * 2)),
    'isFavorite': index % 7 == 0,
  });

  static String _getProductTitle(int index) {
    final titles = [
      '아이폰 14 Pro 256GB',
      '나이키 에어맥스 270',
      '맥북 프로 13인치',
      '삼성 갤럭시 버즈',
      '아디다스 후드티',
      '다이슨 헤어드라이어',
      '애플워치 시리즈 8',
      '루이비통 가방',
      '캐논 DSLR 카메라',
      '플레이스테이션 5',
    ];
    return '${titles[index % titles.length]} $index';
  }

  static String _getLocation(int index) {
    final locations = ['강남구', '서초구', '송파구', '마포구', '용산구'];
    return locations[index % locations.length];
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _loadMoreProducts() {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    // 임시 로딩 시뮬레이션
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // TODO: 실제 데이터 로드
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HomeAppBar(),
      body: Column(
        children: [
          // 검색바
          CustomSearchBar(
            hintText: '상품명, 브랜드, 판매자명으로 검색',
            onChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            onSubmitted: (query) {
              // TODO: 검색 실행
            },
          ),
          
          // 카테고리 필터
          const _CategoryFilter(),
          
          // 뷰 전환 및 정렬 옵션
          _buildViewControls(),
          
          // 상품 리스트
          Expanded(
            child: _isGridView ? _buildGridView() : _buildListView(),
          ),
        ],
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
          id: product['id'],
          title: product['title'],
          price: product['price'],
          sellerName: product['sellerName'],
          sellerLevel: product['sellerLevel'],
          isResaleEnabled: product['isResaleEnabled'],
          location: product['location'],
          createdAt: product['createdAt'],
          isFavorite: product['isFavorite'],
          onFavoritePressed: () {
            setState(() {
              product['isFavorite'] = !product['isFavorite'];
            });
          },
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
          id: product['id'],
          title: product['title'],
          price: product['price'],
          sellerName: product['sellerName'],
          sellerLevel: product['sellerLevel'],
          isResaleEnabled: product['isResaleEnabled'],
          location: product['location'],
          createdAt: product['createdAt'],
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
}

class _CategoryFilter extends StatefulWidget {
  const _CategoryFilter();

  @override
  State<_CategoryFilter> createState() => _CategoryFilterState();
}

class _CategoryFilterState extends State<_CategoryFilter> {
  String _selectedCategory = '전체';
  
  final List<Map<String, dynamic>> _categories = [
    {'label': '전체', 'icon': Icons.apps},
    {'label': '의류', 'icon': Icons.checkroom},
    {'label': '전자기기', 'icon': Icons.phone_android},
    {'label': '생활용품', 'icon': Icons.home},
    {'label': '도서', 'icon': Icons.book},
    {'label': '스포츠', 'icon': Icons.sports_soccer},
    {'label': '뷰티', 'icon': Icons.face},
    {'label': '기타', 'icon': Icons.more_horiz},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['label'];
          
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _CategoryChip(
              label: category['label'],
              icon: category['icon'],
              isSelected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category['label'];
                });
                // TODO: 카테고리 필터링 구현
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

