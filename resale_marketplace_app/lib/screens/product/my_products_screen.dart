import 'package:flutter/material.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = '전체';
  
  final List<String> _filterOptions = [
    '전체',
    '판매중',
    '거래중',
    '판매완료',
    '숨김',
  ];

  // Mock data for demonstration
  final List<Map<String, dynamic>> _mockProducts = [
    {
      'id': '1',
      'title': '아이폰 14 Pro 128GB',
      'price': 950000,
      'status': '판매중',
      'images': ['image1.jpg'],
      'views': 45,
      'likes': 12,
      'chats': 3,
      'createdAt': DateTime.now().subtract(const Duration(days: 2)),
      'resaleEnabled': true,
      'resaleCount': 5,
    },
    {
      'id': '2',
      'title': '맥북 프로 M2',
      'price': 1800000,
      'status': '거래중',
      'images': ['image2.jpg'],
      'views': 78,
      'likes': 23,
      'chats': 8,
      'createdAt': DateTime.now().subtract(const Duration(days: 5)),
      'resaleEnabled': false,
      'resaleCount': 0,
    },
    {
      'id': '3',
      'title': '에어팟 프로 2세대',
      'price': 180000,
      'status': '판매완료',
      'images': ['image3.jpg'],
      'views': 32,
      'likes': 8,
      'chats': 2,
      'createdAt': DateTime.now().subtract(const Duration(days: 10)),
      'resaleEnabled': true,
      'resaleCount': 2,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 상품 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '내 상품'),
            Tab(text: '통계'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildStatisticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/product/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductsTab() {
    final filteredProducts = _selectedFilter == '전체'
        ? _mockProducts
        : _mockProducts.where((product) => product['status'] == _selectedFilter).toList();

    return Column(
      children: [
        // 필터 섹션
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '상태별 필터:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((filter) {
                      final isSelected = _selectedFilter == filter;
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
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 상품 리스트
        Expanded(
          child: filteredProducts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _buildProductCard(product);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상품 이미지
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.image,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 상품 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        '₩${product['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          _buildStatusChip(product['status']),
                          const SizedBox(width: 8),
                          if (product['resaleEnabled'])
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '대신팔기',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 액션 버튼
                PopupMenuButton<String>(
                  onSelected: (value) => _handleProductAction(value, product),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('수정'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'hide',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off),
                          SizedBox(width: 8),
                          Text('숨기기'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('삭제', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 통계 정보
            Row(
              children: [
                _buildStatItem(Icons.visibility, '조회', product['views']),
                const SizedBox(width: 16),
                _buildStatItem(Icons.favorite, '관심', product['likes']),
                const SizedBox(width: 16),
                _buildStatItem(Icons.chat, '채팅', product['chats']),
                if (product['resaleEnabled']) ...[
                  const SizedBox(width: 16),
                  _buildStatItem(Icons.store, '대신팔기', product['resaleCount']),
                ],
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '등록일: ${_formatDate(product['createdAt'])}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case '판매중':
        color = Colors.green;
        break;
      case '거래중':
        color = Colors.orange;
        break;
      case '판매완료':
        color = Colors.blue;
        break;
      case '숨김':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 상품이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '첫 상품을 등록해보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/product/create');
            },
            icon: const Icon(Icons.add),
            label: const Text('상품 등록하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final totalProducts = _mockProducts.length;
    final activeProducts = _mockProducts.where((p) => p['status'] == '판매중').length;
    final completedProducts = _mockProducts.where((p) => p['status'] == '판매완료').length;
    final totalViews = _mockProducts.fold<int>(0, (sum, p) => sum + (p['views'] as int));
    final totalLikes = _mockProducts.fold<int>(0, (sum, p) => sum + (p['likes'] as int));
    final totalResales = _mockProducts.fold<int>(0, (sum, p) => sum + (p['resaleCount'] as int));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상품 통계',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 상품 현황
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '상품 현황',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '전체 상품',
                          totalProducts.toString(),
                          Icons.inventory_2,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '판매중',
                          activeProducts.toString(),
                          Icons.store,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '판매완료',
                          completedProducts.toString(),
                          Icons.check_circle,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '성공률',
                          totalProducts > 0 
                              ? '${((completedProducts / totalProducts) * 100).toInt()}%'
                              : '0%',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 활동 통계
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '활동 통계',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '총 조회수',
                          totalViews.toString(),
                          Icons.visibility,
                          Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '총 관심수',
                          totalLikes.toString(),
                          Icons.favorite,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '대신팔기',
                          totalResales.toString(),
                          Icons.people,
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '평균 조회',
                          totalProducts > 0 
                              ? (totalViews / totalProducts).toInt().toString()
                              : '0',
                          Icons.analytics,
                          Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 최근 활동
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '최근 활동',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  ..._mockProducts.take(3).map((product) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                      title: Text(
                        product['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_formatDate(product['createdAt'])} • ${product['status']}',
                      ),
                      trailing: Text(
                        '조회 ${product['views']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleProductAction(String action, Map<String, dynamic> product) {
    switch (action) {
      case 'edit':
        // TODO: Navigate to edit screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product['title']} 수정 기능 구현 예정')),
        );
        break;
      case 'hide':
        setState(() {
          product['status'] = product['status'] == '숨김' ? '판매중' : '숨김';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              product['status'] == '숨김' 
                  ? '상품을 숨겼습니다' 
                  : '상품을 다시 표시합니다'
            ),
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmDialog(product);
        break;
    }
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상품 삭제'),
        content: Text('${product['title']}을(를) 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _mockProducts.removeWhere((p) => p['id'] == product['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('상품이 삭제되었습니다')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
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