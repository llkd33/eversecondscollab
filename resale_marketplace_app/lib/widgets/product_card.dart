import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../models/product_model.dart';
import 'common/optimized_image.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onFavoritePressed;
  final bool isFavorite;
  final bool showResaleBadge;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onFavoritePressed,
    this.isFavorite = false,
    this.showResaleBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.push('/product/detail/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 및 상태 배지
            Expanded(
              flex: 3,
              child: _buildImageSection(),
            ),
            
            // 상품 정보
            Expanded(
              flex: 2,
              child: _buildProductInfo(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSection() {
    return Stack(
      children: [
        // 메인 이미지
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            color: Colors.grey[100],
          ),
          child: product.images.isNotEmpty
              ? ProductImageOptimized(
                  imageUrl: product.images.first,
                  width: double.infinity,
                  height: double.infinity,
                )
              : _buildPlaceholderImage(),
        ),
        
        // 상태 배지들
        Positioned(
          top: 8,
          left: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대신팔기 배지
              if (showResaleBadge && product.resaleEnabled)
                _buildBadge(
                  '대신팔기',
                  AppTheme.primaryColor,
                  Colors.white,
                ),
              
              const SizedBox(height: 4),
              
              // 판매완료 배지
              if (product.status == '판매완료')
                _buildBadge(
                  '판매완료',
                  Colors.grey[600]!,
                  Colors.white,
                ),
            ],
          ),
        ),
        
        // 찜 버튼
        if (onFavoritePressed != null)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onFavoritePressed,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey[600],
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상품명
          Text(
            product.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const Spacer(),
          
          // 가격
          Text(
            _formatPrice(product.price),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // 부가 정보
          Row(
            children: [
              // 카테고리
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  product.category,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // 대신팔기 수수료 정보
              if (product.resaleEnabled && product.resaleFee > 0)
                Text(
                  '수수료 ${_formatPrice(product.resaleFee)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }
  
  Widget _buildBadge(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
  
  String _formatPrice(int price) {
    if (price >= 10000) {
      if (price % 10000 == 0) {
        return '${(price / 10000).toInt()}만원';
      } else {
        return '${(price / 10000).toStringAsFixed(1)}만원';
      }
    } else {
      return '${_numberWithCommas(price)}원';
    }
  }
  
  String _numberWithCommas(int number) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return number.toString().replaceAllMapped(
      formatter,
      (match) => '${match[1]},',
    );
  }
}

// 간단한 상품 카드 (리스트뷰용)
class ProductListCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductListCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.thumbnailImage != null
              ? OptimizedThumbnail(
                  imageUrl: product.thumbnailImage!,
                  size: 80,
                )
              : const Icon(Icons.image_outlined),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (product.resaleEnabled)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '대신팔기',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Text(
                  product.sellerName ?? '판매자',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  product.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(product.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onTap ?? () => context.push('/product/detail/${product.id}'),
      ),
    );
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