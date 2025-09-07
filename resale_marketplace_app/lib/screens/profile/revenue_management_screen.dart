import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';
import '../../services/auth_service.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';

class RevenueManagementScreen extends StatefulWidget {
  const RevenueManagementScreen({super.key});

  @override
  State<RevenueManagementScreen> createState() => _RevenueManagementScreenState();
}

class _RevenueManagementScreenState extends State<RevenueManagementScreen>
    with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  List<TransactionModel> _sellTransactions = [];
  List<TransactionModel> _resellTransactions = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _currentUserId;
  
  // 수익 통계
  int _totalSellRevenue = 0;
  int _totalResellRevenue = 0;
  int _thisMonthSellRevenue = 0;
  int _thisMonthResellRevenue = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRevenueData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadRevenueData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = await _authService.getCurrentUser();
      final userId = user?.id;
      if (userId == null) return;
      
      _currentUserId = userId;
      
      // 판매 거래 내역 조회
      final sellTransactions = await _transactionService.getMyTransactions(
        userId: userId,
        role: 'seller',
        status: TransactionStatus.completed,
      );
      
      // 대신판매 거래 내역 조회
      final resellTransactions = await _transactionService.getMyTransactions(
        userId: userId,
        role: 'reseller',
        status: TransactionStatus.completed,
      );
      
      // 거래 통계 조회
      final stats = await _transactionService.getTransactionStats(userId);
      
      if (mounted) {
        setState(() {
          _sellTransactions = sellTransactions;
          _resellTransactions = resellTransactions;
          _stats = stats;
        });
        
        _calculateRevenue();
      }
    } catch (e) {
      print('Error loading revenue data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _calculateRevenue() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    
    // 판매 수익 계산
    _totalSellRevenue = _sellTransactions.fold(0, (sum, transaction) {
      return sum + transaction.sellerAmount;
    });
    
    _thisMonthSellRevenue = _sellTransactions
        .where((transaction) => transaction.completedAt?.isAfter(thisMonth) == true)
        .fold(0, (sum, transaction) => sum + transaction.sellerAmount);
    
    // 대신판매 수익 계산
    _totalResellRevenue = _resellTransactions.fold(0, (sum, transaction) {
      return sum + transaction.resellerCommission;
    });
    
    _thisMonthResellRevenue = _resellTransactions
        .where((transaction) => transaction.completedAt?.isAfter(thisMonth) == true)
        .fold(0, (sum, transaction) => sum + transaction.resellerCommission);
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('수익 관리'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '판매 수익'),
            Tab(text: '대신판매 수익'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 수익 요약
                _buildRevenueSummary(theme),
                // 탭 뷰
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSellRevenueTab(theme),
                      _buildResellRevenueTab(theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildRevenueSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // 총 수익
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRevenueCard(
                theme: theme,
                title: '총 수익',
                amount: _totalSellRevenue + _totalResellRevenue,
                color: theme.colorScheme.primary,
                icon: Icons.account_balance_wallet,
              ),
              _buildRevenueCard(
                theme: theme,
                title: '이번 달',
                amount: _thisMonthSellRevenue + _thisMonthResellRevenue,
                color: Colors.green,
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 세부 수익
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRevenueCard(
                theme: theme,
                title: '판매 수익',
                amount: _totalSellRevenue,
                color: Colors.blue,
                icon: Icons.store,
                isSmall: true,
              ),
              _buildRevenueCard(
                theme: theme,
                title: '대신판매 수익',
                amount: _totalResellRevenue,
                color: Colors.orange,
                icon: Icons.support_agent,
                isSmall: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueCard({
    required ThemeData theme,
    required String title,
    required int amount,
    required Color color,
    required IconData icon,
    bool isSmall = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: isSmall ? 20 : 24,
          ),
          SizedBox(height: isSmall ? 4 : 8),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmall ? 2 : 4),
          Text(
            _formatPrice(amount),
            style: (isSmall 
                ? theme.textTheme.titleSmall 
                : theme.textTheme.titleMedium)?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSellRevenueTab(ThemeData theme) {
    if (_sellTransactions.isEmpty) {
      return _buildEmptyState(
        theme: theme,
        icon: Icons.store_outlined,
        message: '판매 완료된 거래가 없습니다',
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadRevenueData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sellTransactions.length,
        itemBuilder: (context, index) {
          final transaction = _sellTransactions[index];
          return _buildRevenueTransactionCard(
            theme: theme,
            transaction: transaction,
            revenueAmount: transaction.sellerAmount,
            revenueType: '판매 수익',
            revenueColor: Colors.blue,
          );
        },
      ),
    );
  }
  
  Widget _buildResellRevenueTab(ThemeData theme) {
    if (_resellTransactions.isEmpty) {
      return _buildEmptyState(
        theme: theme,
        icon: Icons.support_agent_outlined,
        message: '대신판매 완료된 거래가 없습니다',
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadRevenueData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _resellTransactions.length,
        itemBuilder: (context, index) {
          final transaction = _resellTransactions[index];
          return _buildRevenueTransactionCard(
            theme: theme,
            transaction: transaction,
            revenueAmount: transaction.resellerCommission,
            revenueType: '대신판매 수수료',
            revenueColor: Colors.orange,
          );
        },
      ),
    );
  }
  
  Widget _buildRevenueTransactionCard({
    required ThemeData theme,
    required TransactionModel transaction,
    required int revenueAmount,
    required String revenueType,
    required Color revenueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 수익 타입 및 금액
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: revenueColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    revenueType,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: revenueColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '+${_formatPrice(revenueAmount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: revenueColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 상품 정보
            Row(
              children: [
                // 상품 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: transaction.productImage != null
                      ? Image.network(
                          transaction.productImage!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: theme.colorScheme.surfaceVariant,
                              child: Icon(
                                Icons.image,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: theme.colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.image,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                        '판매가: ${transaction.formattedPrice}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (transaction.isResaleTransaction) ...[
                        const SizedBox(height: 2),
                        Text(
                          '수수료: ${transaction.formattedResaleFee}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
                      '구매자',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      transaction.buyerName ?? '알 수 없음',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                // 완료 날짜
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '완료일',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      transaction.completedAt != null
                          ? _formatDate(transaction.completedAt!)
                          : '알 수 없음',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            
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
                    const Icon(
                      Icons.security,
                      size: 16,
                      color: Colors.green,
                    ),
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
    );
  }
  
  Widget _buildEmptyState({
    required ThemeData theme,
    required IconData icon,
    required String message,
  }) {
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
  
  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}