import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../widgets/auth_guard.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_bar.dart' as custom;
import '../../theme/app_theme.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/loading_widgets.dart';
import '../../widgets/common/error_widgets.dart';

/// 최적화된 홈 화면
/// Provider를 사용한 효율적인 상태 관리와 성능 최적화
class HomeScreenOptimized extends StatefulWidget {
  const HomeScreenOptimized({super.key});

  @override
  State<HomeScreenOptimized> createState() => _HomeScreenOptimizedState();
}

class _HomeScreenOptimizedState extends State<HomeScreenOptimized> 
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _isGridView = true;
  
  // 화면 상태 유지
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(refresh: true);
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ProductProvider>().loadMore();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: const HomeAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ProductProvider>().loadProducts(refresh: true);
        },
        child: Column(
          children: [
            // 검색바
            custom.CustomSearchBar(
              hintText: '상품명, 브랜드, 판매자명으로 검색',
              readOnly: true,
              onTap: () => context.push('/search'),
            ),
            
            // 카테고리 필터
            const _CategoryFilter(),
            
            // 뷰 전환 및 정렬 옵션
            _buildViewControls(),
            
            // 상품 리스트
            Expanded(
              child: Consumer<ProductProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.products.isEmpty) {
                    return const FullScreenLoading();
                  }
                  
                  if (provider.errorMessage != null && provider.products.isEmpty) {
                    return CommonErrorWidget(
                      message: provider.errorMessage!,
                      onRetry: () {
                        provider.loadProducts(refresh: true);
                      },
                    );
                  }
                  
                  if (provider.products.isEmpty) {
                    return Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        return EmptyStateWidget(
                          title: '등록된 상품이 없습니다',
                          subtitle: authProvider.isAuthenticated
                              ? '첫 번째 상품을 등록해보세요'
                              : '상품을 보려면 잠시만 기다려주세요',
                          icon: Icons.shopping_bag_outlined,
                          action: authProvider.isAuthenticated
                              ? ElevatedButton(
                                  onPressed: () => context.push('/product/create'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                  ),
                                  child: const Text(
                                    '상품 등록하기',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              : null,
                        );
                      },
                    );
                  }
                  
                  return _isGridView 
                      ? _buildOptimizedGridView(provider)
                      : _buildOptimizedListView(provider);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // 로그인한 사용자만 FAB 표시
          if (!authProvider.isAuthenticated) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () => context.push('/product/create'),
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }
  
  Widget _buildViewControls() {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '총 ${provider.products.length}개 상품',
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
      },
    );
  }
  
  /// 최적화된 그리드 뷰
  Widget _buildOptimizedGridView(ProductProvider provider) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      // 성능 최적화 옵션
      cacheExtent: 500, // 캐시 범위 설정
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: provider.products.length + (provider.isLoading ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.products.length) {
          return const LoadingGridItem();
        }
        
        final product = provider.products[index];
        // 고유 키 사용으로 위젯 재사용 최적화
        return ProductCard(
          key: ValueKey(product.id),
          product: product,
          onTap: () => context.push('/product/detail/${product.id}'),
        );
      },
    );
  }
  
  /// 최적화된 리스트 뷰
  Widget _buildOptimizedListView(ProductProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      // 성능 최적화 옵션
      cacheExtent: 500, // 캐시 범위 설정
      itemExtent: 120, // 고정 높이로 성능 향상
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: provider.products.length + (provider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.products.length) {
          return const LoadingListItem();
        }
        
        final product = provider.products[index];
        // 고유 키 사용으로 위젯 재사용 최적화
        return ProductListCard(
          key: ValueKey(product.id),
          product: product,
          onTap: () => context.push('/product/detail/${product.id}'),
        );
      },
    );
  }
}

/// 카테고리 필터 위젯 (최적화됨)
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter();
  
  static const List<Map<String, dynamic>> _categories = [
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
      child: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final sel = provider.selectedCategory;
              final isSelected = (sel == null && category['label'] == '전체')
                  || (sel != null && sel == category['label']);
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _CategoryChip(
                  label: category['label'],
                  icon: category['icon'],
                  isSelected: isSelected,
                  onSelected: (selected) {
                    provider.changeCategory(category['label']);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 카테고리 칩 위젯 (const 최적화)
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
