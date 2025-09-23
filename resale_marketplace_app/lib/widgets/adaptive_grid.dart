import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'responsive_layout.dart';

/// 적응형 그리드 설정
class AdaptiveGridConfig {
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets padding;
  
  const AdaptiveGridConfig({
    required this.crossAxisCount,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.padding = const EdgeInsets.all(16),
  });
}

/// 적응형 그리드 위젯
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final AdaptiveGridConfig? mobileConfig;
  final AdaptiveGridConfig? tabletConfig;
  final AdaptiveGridConfig? desktopConfig;
  final AdaptiveGridConfig? largeDesktopConfig;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  
  const AdaptiveGrid({
    Key? key,
    required this.children,
    this.mobileConfig,
    this.tabletConfig,
    this.desktopConfig,
    this.largeDesktopConfig,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  }) : super(key: key);
  
  /// 기본 설정
  static AdaptiveGridConfig get defaultMobileConfig =>
      const AdaptiveGridConfig(crossAxisCount: 2);
  
  static AdaptiveGridConfig get defaultTabletConfig =>
      const AdaptiveGridConfig(crossAxisCount: 3);
  
  static AdaptiveGridConfig get defaultDesktopConfig =>
      const AdaptiveGridConfig(crossAxisCount: 4);
  
  static AdaptiveGridConfig get defaultLargeDesktopConfig =>
      const AdaptiveGridConfig(crossAxisCount: 5);
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, info) {
        final config = info.adaptive(
          mobile: mobileConfig ?? defaultMobileConfig,
          tablet: tabletConfig ?? defaultTabletConfig,
          desktop: desktopConfig ?? defaultDesktopConfig,
          largeDesktop: largeDesktopConfig ?? defaultLargeDesktopConfig,
        );
        
        return GridView.builder(
          controller: controller,
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: config.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: config.crossAxisCount,
            childAspectRatio: config.childAspectRatio,
            crossAxisSpacing: config.crossAxisSpacing,
            mainAxisSpacing: config.mainAxisSpacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Staggered 적응형 그리드 (Pinterest 스타일)
class AdaptiveStaggeredGrid extends StatelessWidget {
  final List<Widget> children;
  final List<StaggeredTile> staggeredTiles;
  final int mobileCrossAxisCount;
  final int tabletCrossAxisCount;
  final int desktopCrossAxisCount;
  final int largeDesktopCrossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  
  const AdaptiveStaggeredGrid({
    Key? key,
    required this.children,
    required this.staggeredTiles,
    this.mobileCrossAxisCount = 2,
    this.tabletCrossAxisCount = 3,
    this.desktopCrossAxisCount = 4,
    this.largeDesktopCrossAxisCount = 5,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, info) {
        final crossAxisCount = info.adaptive(
          mobile: mobileCrossAxisCount,
          tablet: tabletCrossAxisCount,
          desktop: desktopCrossAxisCount,
          largeDesktop: largeDesktopCrossAxisCount,
        );
        
        return StaggeredGrid.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          children: List.generate(
            children.length,
            (index) => StaggeredGridTile.count(
              crossAxisCellCount: _getAdaptiveCrossAxisCellCount(
                staggeredTiles[index],
                crossAxisCount,
              ),
              mainAxisCellCount: staggeredTiles[index].mainAxisCellCount!.toInt(),
              child: children[index],
            ),
          ),
        );
      },
    );
  }
  
  int _getAdaptiveCrossAxisCellCount(StaggeredTile tile, int maxCount) {
    final originalCount = tile.crossAxisCellCount!.toInt();
    return originalCount.clamp(1, maxCount);
  }
}

/// 적응형 상품 그리드
class AdaptiveProductGrid extends StatelessWidget {
  final List<ProductGridItem> products;
  final Function(ProductGridItem)? onTap;
  final Function(ProductGridItem)? onFavorite;
  final bool showFavorite;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  
  const AdaptiveProductGrid({
    Key? key,
    required this.products,
    this.onTap,
    this.onFavorite,
    this.showFavorite = true,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AdaptiveGrid(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      mobileConfig: const AdaptiveGridConfig(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        padding: EdgeInsets.all(12),
      ),
      tabletConfig: const AdaptiveGridConfig(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        padding: EdgeInsets.all(16),
      ),
      desktopConfig: const AdaptiveGridConfig(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        padding: EdgeInsets.all(20),
      ),
      largeDesktopConfig: const AdaptiveGridConfig(
        crossAxisCount: 5,
        childAspectRatio: 0.85,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        padding: EdgeInsets.all(24),
      ),
      children: products.map((product) {
        return ProductGridCard(
          product: product,
          onTap: onTap != null ? () => onTap!(product) : null,
          onFavorite: onFavorite != null ? () => onFavorite!(product) : null,
          showFavorite: showFavorite,
        );
      }).toList(),
    );
  }
}

/// 상품 그리드 아이템 모델
class ProductGridItem {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final bool isFavorite;
  final String? badge;
  final int? viewCount;
  final DateTime? createdAt;
  
  const ProductGridItem({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.isFavorite = false,
    this.badge,
    this.viewCount,
    this.createdAt,
  });
}

/// 상품 그리드 카드
class ProductGridCard extends StatelessWidget {
  final ProductGridItem product;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool showFavorite;
  
  const ProductGridCard({
    Key? key,
    required this.product,
    this.onTap,
    this.onFavorite,
    this.showFavorite = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = ResponsiveInfo.of(context);
    
    final imageHeight = info.adaptive(
      mobile: 120.0,
      tablet: 140.0,
      desktop: 160.0,
      largeDesktop: 180.0,
    );
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이미지 영역
            Stack(
              children: [
                Container(
                  height: imageHeight,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(product.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // 배지
                if (product.badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // 찜 버튼
                if (showFavorite)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(
                        product.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: product.isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: onFavorite,
                    ),
                  ),
              ],
            ),
            // 정보 영역
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      product.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // 가격
                    Text(
                      '₩${product.price.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 메타 정보
                    Row(
                      children: [
                        if (product.viewCount != null) ...[
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.viewCount.toString(),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        if (product.createdAt != null) ...[
                          const Spacer(),
                          Text(
                            _getTimeAgo(product.createdAt!),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}달 전';
    } else if (difference.inDays > 0) {
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

/// 적응형 카테고리 그리드
class AdaptiveCategoryGrid extends StatelessWidget {
  final List<CategoryGridItem> categories;
  final Function(CategoryGridItem)? onTap;
  
  const AdaptiveCategoryGrid({
    Key? key,
    required this.categories,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AdaptiveGrid(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mobileConfig: const AdaptiveGridConfig(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      tabletConfig: const AdaptiveGridConfig(
        crossAxisCount: 4,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      desktopConfig: const AdaptiveGridConfig(
        crossAxisCount: 6,
        childAspectRatio: 1.2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      largeDesktopConfig: const AdaptiveGridConfig(
        crossAxisCount: 8,
        childAspectRatio: 1.2,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      children: categories.map((category) {
        return CategoryGridCard(
          category: category,
          onTap: onTap != null ? () => onTap!(category) : null,
        );
      }).toList(),
    );
  }
}

/// 카테고리 그리드 아이템 모델
class CategoryGridItem {
  final String id;
  final String name;
  final IconData icon;
  final Color? color;
  final int? itemCount;
  
  const CategoryGridItem({
    required this.id,
    required this.name,
    required this.icon,
    this.color,
    this.itemCount,
  });
}

/// 카테고리 그리드 카드
class CategoryGridCard extends StatelessWidget {
  final CategoryGridItem category;
  final VoidCallback? onTap;
  
  const CategoryGridCard({
    Key? key,
    required this.category,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = ResponsiveInfo.of(context);
    
    final iconSize = info.adaptive(
      mobile: 32.0,
      tablet: 36.0,
      desktop: 40.0,
      largeDesktop: 44.0,
    );
    
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                category.icon,
                size: iconSize,
                color: category.color ?? theme.primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (category.itemCount != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${category.itemCount}개',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}