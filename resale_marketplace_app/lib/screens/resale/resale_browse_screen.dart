import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common_app_bar.dart';

import '../../widgets/search_bar.dart' as custom;
import '../../theme/app_theme.dart';

class ResaleBrowseScreen extends StatefulWidget {
  const ResaleBrowseScreen({super.key});

  @override
  State<ResaleBrowseScreen> createState() => _ResaleBrowseScreenState();
}

class _ResaleBrowseScreenState extends State<ResaleBrowseScreen> {
  String _selectedCategory = '전체';
  String _searchQuery = '';
  final List<String> _categories = ['전체', '전자기기', '의류', '생활용품', '도서', '기타'];

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
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 20, // TODO: 실제 데이터로 교체
              itemBuilder: (context, index) {
                return _ResaleProductCard(
                  title: '갤럭시 S23 Ultra ${index + 1}',
                  price: '₩${(index + 1) * 50000}',
                  originalSeller: '김철수',
                  commissionRate: 10.0 + (index % 5),
                  imageUrl: null, // TODO: 실제 이미지 URL
                  onAddToShop: () => _showAddToShopDialog(context, index),
                );
              },
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

  void _showAddToShopDialog(BuildContext context, int productIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 샵에 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('갤럭시 S23 Ultra ${productIndex + 1}'),
            const SizedBox(height: 8),
            Text(
              '가격: ₩${(productIndex + 1) * 50000}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('수수료율: ${10.0 + (productIndex % 5)}%'),
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
              _addToMyShop(productIndex);
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

  void _addToMyShop(int productIndex) {
    // TODO: 실제 대신팔기 추가 로직 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('갤럭시 S23 Ultra ${productIndex + 1}이(가) 내 샵에 추가되었습니다'),
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
            // TODO: 내 샵 화면으로 이동하고 대신팔기 탭 선택
          },
        ),
      ),
    );
  }
}

class _ResaleProductCard extends StatelessWidget {
  final String title;
  final String price;
  final String originalSeller;
  final double commissionRate;
  final String? imageUrl;
  final VoidCallback onAddToShop;

  const _ResaleProductCard({
    required this.title,
    required this.price,
    required this.originalSeller,
    required this.commissionRate,
    this.imageUrl,
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
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl == null
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
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
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
                          '판매자: $originalSeller',
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
                          '수수료 ${commissionRate.toStringAsFixed(1)}%',
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