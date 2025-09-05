import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common_app_bar.dart';
import '../../theme/app_theme.dart';

class ResaleManageScreen extends StatefulWidget {
  const ResaleManageScreen({super.key});

  @override
  State<ResaleManageScreen> createState() => _ResaleManageScreenState();
}

class _ResaleManageScreenState extends State<ResaleManageScreen> {
  String _selectedFilter = '전체';
  final List<String> _filters = ['전체', '판매중', '판매완료', '일시정지'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '대신팔기 관리',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/resale/browse'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 탭
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryColor,
                  ),
                );
              },
            ),
          ),
          
          // 대신팔기 현황 요약
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  title: '총 상품',
                  value: '8개',
                  icon: Icons.inventory,
                ),
                _SummaryItem(
                  title: '판매중',
                  value: '5개',
                  icon: Icons.trending_up,
                ),
                _SummaryItem(
                  title: '이번 달 수익',
                  value: '₩45,000',
                  icon: Icons.monetization_on,
                ),
              ],
            ),
          ),
          
          // 대신팔기 상품 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 8, // TODO: 실제 데이터로 교체
              itemBuilder: (context, index) {
                return _ResaleManageItem(
                  title: '갤럭시 S23 Ultra ${index + 1}',
                  price: '₩${(index + 1) * 50000}',
                  originalSeller: '김철수',
                  commissionRate: 10.0 + (index % 5),
                  status: index % 3 == 0 ? '판매완료' : '판매중',
                  addedDate: DateTime.now().subtract(Duration(days: index)),
                  viewCount: (index + 1) * 12,
                  likeCount: (index + 1) * 3,
                  onEdit: () => _showEditDialog(context, index),
                  onRemove: () => _showRemoveDialog(context, index),
                  onToggleStatus: () => _toggleStatus(index),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/resale/browse'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상품 설정 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('갤럭시 S23 Ultra ${index + 1}'),
            const SizedBox(height: 16),
            const Text('판매 상태'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('판매중'),
                    selected: true,
                    onSelected: (selected) {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('일시정지'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('알림 설정'),
            SwitchListTile(
              title: const Text('관심 표시 알림'),
              value: true,
              onChanged: (value) {},
              contentPadding: EdgeInsets.zero,
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
              // TODO: 설정 변경 로직
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상품 제거'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('갤럭시 S23 Ultra ${index + 1}'),
            const SizedBox(height: 8),
            const Text(
              '이 상품을 내 샵에서 제거하시겠습니까?\n제거 후에도 다시 추가할 수 있습니다.',
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
              _removeFromShop(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('제거'),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(int index) {
    // TODO: 상품 상태 토글 로직
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('상품 상태가 변경되었습니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeFromShop(int index) {
    // TODO: 실제 제거 로직 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('갤럭시 S23 Ultra ${index + 1}이(가) 내 샵에서 제거되었습니다'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ResaleManageItem extends StatelessWidget {
  final String title;
  final String price;
  final String originalSeller;
  final double commissionRate;
  final String status;
  final DateTime addedDate;
  final int viewCount;
  final int likeCount;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onToggleStatus;

  const _ResaleManageItem({
    required this.title,
    required this.price,
    required this.originalSeller,
    required this.commissionRate,
    required this.status,
    required this.addedDate,
    required this.viewCount,
    required this.likeCount,
    required this.onEdit,
    required this.onRemove,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 상품 이미지
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.storefront,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 상품 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                color: _getStatusTextColor(status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '원 판매자: $originalSeller',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 더보기 메뉴
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'toggle':
                        onToggleStatus();
                        break;
                      case 'remove':
                        onRemove();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('설정 변경'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            status == '판매중' ? Icons.pause : Icons.play_arrow,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(status == '판매중' ? '일시정지' : '판매 재개'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('제거', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 통계 및 수수료 정보
            Row(
              children: [
                Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 2),
                Text(
                  '$viewCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.favorite, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 2),
                Text(
                  '$likeCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '추가일: ${_formatDate(addedDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '판매중':
        return Colors.green[100]!;
      case '판매완료':
        return Colors.blue[100]!;
      case '일시정지':
        return Colors.orange[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case '판매중':
        return Colors.green[800]!;
      case '판매완료':
        return Colors.blue[800]!;
      case '일시정지':
        return Colors.orange[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}