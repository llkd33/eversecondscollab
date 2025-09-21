import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/transaction_service.dart';
import '../../services/auth_service.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/safe_network_image.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen>
    with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  String? _selectedStatus;
  String _selectedRole = 'all'; // all, buyer, seller, reseller
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _updateRoleFilter();
      }
    });
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 탭 변경 시 역할 필터 업데이트
  void _updateRoleFilter() {
    setState(() {
      switch (_tabController.index) {
        case 0:
          _selectedRole = 'all';
          break;
        case 1:
          _selectedRole = 'buyer';
          break;
        case 2:
          _selectedRole = 'seller';
          break;
        case 3:
          _selectedRole = 'reseller';
          break;
      }
    });
    _loadTransactions();
  }

  // 거래 목록 로드
  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.getCurrentUser();
      final userId = user?.id;
      if (userId == null) return;

      _currentUserId = userId;

      final transactions = await _transactionService.getMyTransactions(
        userId: userId,
        status: _selectedStatus,
        role: _selectedRole == 'all' ? null : _selectedRole,
      );

      if (mounted) {
        setState(() {
          _transactions = transactions;
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 내역'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '구매'),
            Tab(text: '판매'),
            Tab(text: '대신판매'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 상태 필터
          _buildStatusFilter(theme),
          // 거래 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? _buildEmptyState(theme)
                : _buildTransactionList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(ThemeData theme) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            theme: theme,
            label: '전체',
            value: null,
            isSelected: _selectedStatus == null,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            theme: theme,
            label: '거래중',
            value: TransactionStatus.ongoing,
            isSelected: _selectedStatus == TransactionStatus.ongoing,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            theme: theme,
            label: '거래완료',
            value: TransactionStatus.completed,
            isSelected: _selectedStatus == TransactionStatus.completed,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            theme: theme,
            label: '거래취소',
            value: TransactionStatus.canceled,
            isSelected: _selectedStatus == TransactionStatus.canceled,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required ThemeData theme,
    required String label,
    required String? value,
    required bool isSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? value : null;
        });
        _loadTransactions();
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    String message;
    IconData icon;

    switch (_selectedRole) {
      case 'buyer':
        message = '구매 내역이 없습니다';
        icon = Icons.shopping_bag_outlined;
        break;
      case 'seller':
        message = '판매 내역이 없습니다';
        icon = Icons.store_outlined;
        break;
      case 'reseller':
        message = '대신판매 내역이 없습니다';
        icon = Icons.support_agent;
        break;
      default:
        message = '거래 내역이 없습니다';
        icon = Icons.receipt_long_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _buildTransactionCard(theme, transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(ThemeData theme, TransactionModel transaction) {
    final userId = _currentUserId;
    final isBuyer = transaction.buyerId == userId;
    final isSeller = transaction.sellerId == userId;
    final isReseller = transaction.resellerId == userId;

    // 역할 표시
    String roleText = '';
    Color roleColor = theme.colorScheme.primary;
    if (isBuyer) {
      roleText = '구매';
      roleColor = Colors.blue;
    } else if (isSeller) {
      roleText = '판매';
      roleColor = Colors.green;
    } else if (isReseller) {
      roleText = '대신판매';
      roleColor = Colors.orange;
    }

    // 상태 색상
    Color statusColor;
    switch (transaction.status) {
      case TransactionStatus.ongoing:
        statusColor = Colors.orange;
        break;
      case TransactionStatus.completed:
        statusColor = Colors.green;
        break;
      case TransactionStatus.canceled:
        statusColor = Colors.red;
        break;
      default:
        statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.pushNamed(
            'transaction-detail',
            pathParameters: {'id': transaction.id},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 역할 및 상태
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 역할 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      roleText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 상태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      transaction.status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 상품 정보
              Row(
                children: [
                  // 상품 이미지
                  SafeNetworkImage(
                    imageUrl: transaction.productImage,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 12),
                  // 상품 정보 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.productTitle ?? '상품명 없음',
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transaction.formattedPrice,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 거래 정보
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 거래 상대
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBuyer ? '판매자' : '구매자',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        isBuyer
                            ? transaction.sellerName ?? '알 수 없음'
                            : transaction.buyerName ?? '알 수 없음',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  // 거래 날짜
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '거래일',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatDate(transaction.createdAt),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),

              // 대신판매 정보 (있는 경우)
              if (transaction.isResaleTransaction) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.support_agent,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isReseller
                              ? '대신판매 수수료: ${transaction.formattedResaleFee}'
                              : '${transaction.resellerName}님이 대신판매 중',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 안전거래 표시 (있는 경우)
              if (transaction.isSafeTransaction) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '안전거래',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}분 전';
      }
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
  }
}
