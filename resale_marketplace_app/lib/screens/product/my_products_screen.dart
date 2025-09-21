import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../widgets/safe_network_image.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = '전체';
  final ProductService _productService = ProductService();

  final List<String> _filterOptions = ['전체', ...ProductStatus.all];

  List<ProductModel> _products = [];
  bool _isLoadingProducts = false;
  String? _loadError;
  final Set<String> _processingProductIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyProducts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProducts() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id ?? authProvider.userId;

    if (userId == null) {
      if (mounted) {
        setState(() {
          _loadError = '사용자 정보를 불러오지 못했습니다. 다시 로그인해주세요.';
          _products = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingProducts = true;
        _loadError = null;
      });
    }

    try {
      final products = await _productService.getMyProducts(userId);
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = '상품을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
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
        children: [_buildProductsTab(), _buildStatisticsTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/product/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_isLoadingProducts && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _products.isEmpty) {
      return _buildErrorState();
    }

    final filteredProducts = _selectedFilter == '전체'
        ? _products
        : _products
              .where((product) => product.status == _selectedFilter)
              .toList();

    return Column(
      children: [
        if (_isLoadingProducts) const LinearProgressIndicator(minHeight: 2),
        _buildFilterSection(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadMyProducts,
            child: filteredProducts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [const SizedBox(height: 120), _buildEmptyState()],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('상태별 필터:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      onSelected: (_) {
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
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _loadError ?? '알 수 없는 오류가 발생했습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMyProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final imageUrl = product.thumbnailImage;
    final isProcessing = _processingProductIds.contains(product.id);

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? SafeNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.formattedPrice,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatusChip(product.status),
                          const SizedBox(width: 8),
                          if (product.resaleEnabled)
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
                const SizedBox(width: 8),
                if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      await _handleProductAction(value, product);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('상세보기'),
                          ],
                        ),
                      ),
                      if (product.status == ProductStatus.onSale)
                        const PopupMenuItem(
                          value: 'mark_sold',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline),
                              SizedBox(width: 8),
                              Text('판매완료 처리'),
                            ],
                          ),
                        ),
                      if (product.status == ProductStatus.sold)
                        const PopupMenuItem(
                          value: 'mark_on_sale',
                          child: Row(
                            children: [
                              Icon(Icons.restart_alt),
                              SizedBox(width: 8),
                              Text('다시 판매하기'),
                            ],
                          ),
                        ),
                      const PopupMenuDivider(),
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
            if (product.description != null && product.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  product.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildMetaItem(Icons.category, product.category),
                _buildMetaItem(
                  Icons.calendar_today,
                  '등록 ${_formatDate(product.createdAt)}',
                ),
                if (product.resaleEnabled)
                  _buildMetaItem(
                    Icons.storefront,
                    '수수료 ${product.formattedResaleFee}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case ProductStatus.onSale:
        color = Colors.green;
        break;
      case ProductStatus.sold:
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildMetaItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '등록된 상품이 없습니다',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '첫 상품을 등록해보세요!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/product/create');
            },
            icon: const Icon(Icons.add),
            label: const Text('상품 등록하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    if (_isLoadingProducts && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _products.isEmpty) {
      return _buildErrorState();
    }

    final totalProducts = _products.length;
    final onSaleProducts = _products
        .where((p) => p.status == ProductStatus.onSale)
        .length;
    final soldProducts = _products
        .where((p) => p.status == ProductStatus.sold)
        .length;
    final resaleEnabledProducts = _products
        .where((p) => p.resaleEnabled)
        .length;
    final totalPrice = _products.fold<int>(
      0,
      (sum, product) => sum + product.price,
    );
    final averagePrice = totalProducts > 0
        ? (totalPrice / totalProducts).round()
        : 0;
    final successRate = totalProducts > 0
        ? '${((soldProducts / totalProducts) * 100).round()}%'
        : '0%';
    final latestUpdate = _products.isNotEmpty
        ? _products
              .map((product) => product.updatedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b)
        : null;
    final recentProducts = [..._products]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상품 통계',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '상품 현황',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          onSaleProducts.toString(),
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
                          soldProducts.toString(),
                          Icons.check_circle,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '판매 성공률',
                          successRate,
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '추가 지표',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '평균 가격',
                          totalProducts > 0
                              ? _formatCurrency(averagePrice)
                              : '0원',
                          Icons.attach_money,
                          Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '대신팔기 상품',
                          resaleEnabledProducts.toString(),
                          Icons.storefront,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '총 재고 가치',
                          _formatCurrency(totalPrice),
                          Icons.inventory,
                          Colors.brown,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '최근 업데이트',
                          latestUpdate != null
                              ? _formatDate(latestUpdate)
                              : '정보 없음',
                          Icons.access_time,
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '최근 등록 상품',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (recentProducts.isEmpty)
                    const Text(
                      '아직 등록된 상품이 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...recentProducts.take(5).map((product) {
                      final imageUrl = product.thumbnailImage;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[200],
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? SafeNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                        title: Text(
                          product.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatDate(product.createdAt)} • ${product.status}',
                        ),
                        trailing: Text(
                          product.formattedPrice,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
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
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleProductAction(String action, ProductModel product) async {
    switch (action) {
      case 'view':
        context.push('/product/${product.id}');
        break;
      case 'mark_sold':
        await _updateProductStatus(product, ProductStatus.sold);
        break;
      case 'mark_on_sale':
        await _updateProductStatus(product, ProductStatus.onSale);
        break;
      case 'delete':
        _showDeleteConfirmDialog(product);
        break;
    }
  }

  void _showDeleteConfirmDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상품 삭제'),
        content: Text('${product.title}을(를) 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteProduct(product);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProductStatus(ProductModel product, String status) async {
    setState(() {
      _processingProductIds.add(product.id);
    });

    final success = await _productService.updateProduct(
      productId: product.id,
      status: status,
    );

    if (!mounted) return;

    setState(() {
      _processingProductIds.remove(product.id);
      if (success) {
        final index = _products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          _products[index] = _products[index].copyWith(
            status: status,
            updatedAt: DateTime.now(),
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (status == ProductStatus.sold
                    ? '상품을 판매완료로 표시했습니다.'
                    : '상품을 다시 판매중으로 전환했습니다.')
              : '상품 상태를 업데이트하지 못했습니다. 잠시 후 다시 시도해주세요.',
        ),
      ),
    );
  }

  Future<void> _deleteProduct(ProductModel product) async {
    setState(() {
      _processingProductIds.add(product.id);
    });

    final success = await _productService.deleteProduct(product.id);

    if (!mounted) return;

    setState(() {
      _processingProductIds.remove(product.id);
      if (success) {
        _products.removeWhere((p) => p.id == product.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '상품이 삭제되었습니다.' : '상품 삭제에 실패했습니다. 다시 시도해주세요.'),
      ),
    );
  }

  String _formatCurrency(int value) {
    return '${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
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
