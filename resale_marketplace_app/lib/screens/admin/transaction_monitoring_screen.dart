import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';
import '../../services/user_service.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class TransactionMonitoringScreen extends StatefulWidget {
  const TransactionMonitoringScreen({super.key});

  @override
  State<TransactionMonitoringScreen> createState() => _TransactionMonitoringScreenState();
}

class _TransactionMonitoringScreenState extends State<TransactionMonitoringScreen>
    with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final UserService _userService = UserService();
  
  late TabController _tabController;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  Map<String, UserModel> _userCache = {};
  bool _isLoading = true;
  
  String _selectedStatus = 'all'; // all, pending, processing, completed, cancelled, dispute
  String _selectedType = 'all'; // all, normal, safe, resale
  DateTime? _startDate;
  DateTime? _endDate;
  
  // 통계
  int _totalTransactions = 0;
  int _pendingCount = 0;
  int _processingCount = 0;
  int _completedCount = 0;
  int _disputeCount = 0;
  double _totalAmount = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTransactions();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTransactions() async {
    try {
      setState(() => _isLoading = true);
      
      // 실제 구현 시 서비스 메소드 사용
      // 여기서는 예시 데이터 생성
      await Future.delayed(const Duration(seconds: 1));
      
      _allTransactions = List.generate(100, (index) {
        final statuses = ['pending', 'processing', 'completed', 'cancelled', 'dispute'];
        final types = ['normal', 'safe', 'resale'];
        
        return TransactionModel(
          id: 'trans_$index',
          productId: 'product_$index',
          sellerId: 'seller_$index',
          buyerId: 'buyer_$index',
          type: types[index % types.length],
          status: statuses[index % statuses.length],
          amount: 10000 + (index * 1000),
          createdAt: DateTime.now().subtract(Duration(hours: index * 2)),
          updatedAt: DateTime.now().subtract(Duration(hours: index)),
        );
      });
      
      // 통계 계산
      _calculateStatistics();
      
      // 필터 적용
      _applyFilters();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading transactions: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _calculateStatistics() {
    _totalTransactions = _allTransactions.length;
    _pendingCount = _allTransactions.where((t) => t.status == 'pending').length;
    _processingCount = _allTransactions.where((t) => t.status == 'processing').length;
    _completedCount = _allTransactions.where((t) => t.status == 'completed').length;
    _disputeCount = _allTransactions.where((t) => t.status == 'dispute').length;
    _totalAmount = _allTransactions.fold(0, (sum, t) => sum + t.amount);
  }
  
  void _applyFilters() {
    _filteredTransactions = List.from(_allTransactions);
    
    // 상태 필터
    if (_selectedStatus != 'all') {
      _filteredTransactions = _filteredTransactions
          .where((t) => t.status == _selectedStatus)
          .toList();
    }
    
    // 타입 필터
    if (_selectedType != 'all') {
      _filteredTransactions = _filteredTransactions
          .where((t) => t.type == _selectedType)
          .toList();
    }
    
    // 날짜 필터
    if (_startDate != null) {
      _filteredTransactions = _filteredTransactions
          .where((t) => t.createdAt.isAfter(_startDate!))
          .toList();
    }
    if (_endDate != null) {
      _filteredTransactions = _filteredTransactions
          .where((t) => t.createdAt.isBefore(_endDate!.add(const Duration(days: 1))))
          .toList();
    }
    
    // 최신순 정렬
    _filteredTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 모니터링'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '전체 거래'),
            Tab(text: '진행중'),
            Tab(text: '분쟁'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 통계 카드
          _buildStatisticsCards(theme),
          // 필터
          _buildFilters(theme),
          // 거래 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionList(theme, null),
                      _buildTransactionList(theme, ['pending', 'processing']),
                      _buildTransactionList(theme, ['dispute']),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatisticsCards(ThemeData theme) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard(
            theme,
            '전체 거래',
            _totalTransactions.toString(),
            Icons.receipt_long,
            theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            theme,
            '대기중',
            _pendingCount.toString(),
            Icons.hourglass_empty,
            Colors.orange,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            theme,
            '진행중',
            _processingCount.toString(),
            Icons.sync,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            theme,
            '완료',
            _completedCount.toString(),
            Icons.check_circle,
            Colors.green,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            theme,
            '분쟁',
            _disputeCount.toString(),
            Icons.warning,
            Colors.red,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            theme,
            '총 거래액',
            _formatCurrency(_totalAmount),
            Icons.attach_money,
            Colors.teal,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 상태 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(theme, '전체', 'all', 'status'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '대기', 'pending', 'status'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '진행', 'processing', 'status'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '완료', 'completed', 'status'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '취소', 'cancelled', 'status'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '분쟁', 'dispute', 'status'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 타입 및 날짜 필터
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(theme, '전체', 'all', 'type'),
                      const SizedBox(width: 8),
                      _buildFilterChip(theme, '일반', 'normal', 'type'),
                      const SizedBox(width: 8),
                      _buildFilterChip(theme, '안전', 'safe', 'type'),
                      const SizedBox(width: 8),
                      _buildFilterChip(theme, '대신', 'resale', 'type'),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _selectDateRange,
                tooltip: '날짜 선택',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(
    ThemeData theme,
    String label,
    String value,
    String type,
  ) {
    final isSelected = type == 'status'
        ? _selectedStatus == value
        : _selectedType == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (type == 'status') {
            _selectedStatus = value;
          } else {
            _selectedType = value;
          }
          _applyFilters();
        });
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  Widget _buildTransactionList(ThemeData theme, List<String>? statusFilter) {
    final transactions = statusFilter != null
        ? _filteredTransactions.where((t) => statusFilter.contains(t.status)).toList()
        : _filteredTransactions;
    
    if (transactions.isEmpty) {
      return _buildEmptyState(theme);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionItem(theme, transaction);
      },
    );
  }
  
  Widget _buildTransactionItem(ThemeData theme, TransactionModel transaction) {
    final statusColors = {
      'pending': Colors.orange,
      'processing': Colors.blue,
      'completed': Colors.green,
      'cancelled': Colors.grey,
      'dispute': Colors.red,
    };
    
    final statusLabels = {
      'pending': '대기중',
      'processing': '진행중',
      'completed': '완료',
      'cancelled': '취소됨',
      'dispute': '분쟁중',
    };
    
    final typeLabels = {
      'normal': '일반거래',
      'safe': '안전거래',
      'resale': '대신팔기',
    };
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: transaction.status == 'dispute'
              ? Colors.red.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColors[transaction.status]?.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabels[transaction.status] ?? '',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColors[transaction.status],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabels[transaction.type] ?? '',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    transaction.id.substring(0, 10),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 거래 정보
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatCurrency(transaction.amount)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '판매자 ${transaction.sellerId.substring(0, 8)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '구매자 ${transaction.buyerId.substring(0, 8)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDate(transaction.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatTime(transaction.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 액션 버튼 (분쟁 중인 경우)
              if (transaction.status == 'dispute') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _resolveDispute(transaction),
                      child: const Text('분쟁 해결'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _viewDisputeDetails(transaction),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('상세 보기'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '거래가 없습니다',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '필터를 변경해보세요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyFilters();
      });
    }
  }
  
  void _showTransactionDetails(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailsSheet(transaction: transaction),
    );
  }
  
  void _resolveDispute(TransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('분쟁 해결'),
        content: const Text('이 분쟁을 어떻게 해결하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 구매자 승소 처리
              _updateTransactionStatus(transaction, 'completed');
            },
            child: const Text('구매자 승소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 판매자 승소 처리
              _updateTransactionStatus(transaction, 'cancelled');
            },
            child: const Text('판매자 승소'),
          ),
        ],
      ),
    );
  }
  
  void _viewDisputeDetails(TransactionModel transaction) {
    _showTransactionDetails(transaction);
  }
  
  void _updateTransactionStatus(TransactionModel transaction, String newStatus) {
    setState(() {
      transaction.status = newStatus;
      _calculateStatistics();
      _applyFilters();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('거래 상태가 변경되었습니다'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  String _formatCurrency(double amount) {
    if (amount >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(1)}억';
    } else if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(0)}만원';
    } else {
      return '${amount.toStringAsFixed(0)}원';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
  
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// 거래 상세 정보 시트
class _TransactionDetailsSheet extends StatelessWidget {
  final TransactionModel transaction;
  
  const _TransactionDetailsSheet({required this.transaction});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '거래 상세 정보',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // 상세 정보
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection(theme, '거래 정보', [
                    _buildInfoRow('거래 ID', transaction.id),
                    _buildInfoRow('거래 유형', _getTypeLabel(transaction.type)),
                    _buildInfoRow('거래 상태', _getStatusLabel(transaction.status)),
                    _buildInfoRow('거래 금액', '${transaction.amount.toStringAsFixed(0)}원'),
                  ]),
                  const SizedBox(height: 24),
                  _buildInfoSection(theme, '거래 당사자', [
                    _buildInfoRow('판매자 ID', transaction.sellerId),
                    _buildInfoRow('구매자 ID', transaction.buyerId),
                  ]),
                  const SizedBox(height: 24),
                  _buildInfoSection(theme, '거래 일시', [
                    _buildInfoRow('생성일', _formatDateTime(transaction.createdAt)),
                    _buildInfoRow('수정일', _formatDateTime(transaction.updatedAt)),
                  ]),
                  if (transaction.status == 'dispute') ...[
                    const SizedBox(height: 24),
                    _buildInfoSection(theme, '분쟁 정보', [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '분쟁 사유',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '상품 상태 불일치 신고',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  String _getTypeLabel(String type) {
    switch (type) {
      case 'normal':
        return '일반거래';
      case 'safe':
        return '안전거래';
      case 'resale':
        return '대신팔기';
      default:
        return type;
    }
  }
  
  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'processing':
        return '진행중';
      case 'completed':
        return '완료';
      case 'cancelled':
        return '취소됨';
      case 'dispute':
        return '분쟁중';
      default:
        return status;
    }
  }
  
  String _formatDateTime(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일 '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}