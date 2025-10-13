import 'package:flutter/material.dart';
import '../../widgets/common_app_bar.dart';
import '../../theme/app_theme.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '상품 상세',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공유 기능 준비중입니다')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('찜하기 기능 준비중입니다')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상품 이미지
                  _buildImageSection(),
                  
                  // 상품 정보
                  _buildProductInfo(),
                  
                  // 판매자 정보
                  _buildSellerInfo(),
                  
                  // 상품 설명
                  _buildProductDescription(),
                ],
              ),
            ),
          ),
          
          // 하단 버튼
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 100,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '아이폰 14 Pro 128GB 딥퍼플',
            style: AppStyles.headingMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '₩850,000',
            style: AppStyles.priceText.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // 대신팔기 정보
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.store, color: AppTheme.successColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '대신팔기 가능',
                        style: AppStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                      Text(
                        '수수료: 판매가의 10%',
                        style: AppStyles.bodySmall.copyWith(
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('대신팔기 기능 준비중입니다')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 36),
                  ),
                  child: const Text('대신팔기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '김판매자',
                      style: AppStyles.headingSmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lv.5',
                        style: AppStyles.levelBadge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.orange),
                    Text(' 4.8', style: AppStyles.bodySmall),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '거래 25회',
                      style: AppStyles.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('프로필 보기 기능 준비중입니다')),
              );
            },
            child: const Text('프로필'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDescription() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '상품 설명',
            style: AppStyles.headingSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '아이폰 14 Pro 128GB 딥퍼플 색상입니다.\n'
            '작년 11월에 구매해서 약 1년 정도 사용했습니다.\n'
            '케이스와 필름을 붙여서 사용해서 상태는 매우 좋습니다.\n'
            '박스, 충전기 모두 포함되어 있습니다.\n\n'
            '직거래 가능하며, 택배 발송도 가능합니다.\n'
            '궁금한 점 있으시면 채팅 주세요!',
            style: AppStyles.bodyMedium.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('채팅하기 기능 준비중입니다')),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
              child: const Text('채팅하기'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('구매하기 기능 준비중입니다')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
              ),
              child: const Text('구매하기'),
            ),
          ),
        ],
      ),
    );
  }
}