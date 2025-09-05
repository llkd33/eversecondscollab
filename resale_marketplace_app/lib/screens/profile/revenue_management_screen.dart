import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common_app_bar.dart';
import '../../theme/app_theme.dart';

class RevenueManagementScreen extends StatefulWidget {
  const RevenueManagementScreen({super.key});

  @override
  State<RevenueManagementScreen> createState() => _RevenueManagementScreenState();
}

class _RevenueManagementScreenState extends State<RevenueManagementScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '이번 달';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CommonAppBar(
        title: '수익 관리',
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // Export revenue data
              _showExportOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Revenue Summary Card
          _RevenueSummaryCard(),
          
          // Period Selector
          _PeriodSelector(
            selectedPeriod: _selectedPeriod,
            onPeriodChanged: (period) {
              setState(() {
                _selectedPeriod = period;
              });
            },
          ),
          
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: '전체'),
                Tab(text: '직접판매'),
                Tab(text: '대신팔기'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AllTransactionsList(),
                _DirectSalesList(),
                _ResaleSalesList(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _WithdrawalBottomBar(),
    );
  }
  
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '내보내기 형식 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('PDF 파일'),
              subtitle: const Text('인쇄 가능한 문서 형식'),
              onTap: () {
                Navigator.pop(context);
                // Export as PDF
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Excel 파일'),
              subtitle: const Text('스프레드시트 형식'),
              onTap: () {
                Navigator.pop(context);
                // Export as Excel
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('CSV 파일'),
              subtitle: const Text('쉼표로 구분된 데이터'),
              onTap: () {
                Navigator.pop(context);
                // Export as CSV
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '총 수익',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 14,
                      color: Colors.greenAccent[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+23.5%',
                      style: TextStyle(
                        color: Colors.greenAccent[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '₩ 1,245,000',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: '이번 달',
                  value: '₩ 385,000',
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryItem(
                  label: '출금 가능',
                  value: '₩ 156,000',
                  icon: Icons.account_balance_wallet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onPeriodChanged;
  
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    final periods = ['오늘', '이번 주', '이번 달', '3개월', '6개월', '1년'];
    
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final period = periods[index];
          final isSelected = selectedPeriod == period;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (_) => onPeriodChanged(period),
              selectedColor: AppTheme.primaryColor,
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AllTransactionsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _TransactionGroup(
          date: '2024년 3월',
          totalAmount: '₩ 385,000',
          transactions: [
            Transaction(
              type: TransactionType.directSale,
              productName: '나이키 운동화',
              amount: 85000,
              date: DateTime.now().subtract(const Duration(days: 2)),
              status: TransactionStatus.completed,
            ),
            Transaction(
              type: TransactionType.resale,
              productName: '아이패드 프로',
              amount: 45000,
              commission: 6750,
              date: DateTime.now().subtract(const Duration(days: 3)),
              status: TransactionStatus.completed,
            ),
            Transaction(
              type: TransactionType.directSale,
              productName: '캠핑 의자',
              amount: 35000,
              date: DateTime.now().subtract(const Duration(days: 5)),
              status: TransactionStatus.pending,
            ),
          ],
        ),
        _TransactionGroup(
          date: '2024년 2월',
          totalAmount: '₩ 520,000',
          transactions: [
            Transaction(
              type: TransactionType.resale,
              productName: '에어팟 프로',
              amount: 180000,
              commission: 27000,
              date: DateTime.now().subtract(const Duration(days: 15)),
              status: TransactionStatus.completed,
            ),
            Transaction(
              type: TransactionType.directSale,
              productName: '겨울 코트',
              amount: 120000,
              date: DateTime.now().subtract(const Duration(days: 18)),
              status: TransactionStatus.completed,
            ),
          ],
        ),
      ],
    );
  }
}

class _DirectSalesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _TransactionGroup(
          date: '2024년 3월',
          totalAmount: '₩ 255,000',
          transactions: [
            Transaction(
              type: TransactionType.directSale,
              productName: '나이키 운동화',
              amount: 85000,
              date: DateTime.now().subtract(const Duration(days: 2)),
              status: TransactionStatus.completed,
            ),
            Transaction(
              type: TransactionType.directSale,
              productName: '캠핑 의자',
              amount: 35000,
              date: DateTime.now().subtract(const Duration(days: 5)),
              status: TransactionStatus.pending,
            ),
            Transaction(
              type: TransactionType.directSale,
              productName: '노트북 가방',
              amount: 45000,
              date: DateTime.now().subtract(const Duration(days: 7)),
              status: TransactionStatus.completed,
            ),
          ],
        ),
      ],
    );
  }
}

class _ResaleSalesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _TransactionGroup(
          date: '2024년 3월',
          totalAmount: '₩ 130,000 (수수료 ₩ 19,500)',
          transactions: [
            Transaction(
              type: TransactionType.resale,
              productName: '아이패드 프로',
              amount: 45000,
              commission: 6750,
              date: DateTime.now().subtract(const Duration(days: 3)),
              status: TransactionStatus.completed,
              originalSeller: '판매자A',
            ),
            Transaction(
              type: TransactionType.resale,
              productName: '다이슨 청소기',
              amount: 85000,
              commission: 12750,
              date: DateTime.now().subtract(const Duration(days: 6)),
              status: TransactionStatus.completed,
              originalSeller: '판매자B',
            ),
          ],
        ),
      ],
    );
  }
}

enum TransactionType { directSale, resale }
enum TransactionStatus { pending, completed, cancelled }

class Transaction {
  final TransactionType type;
  final String productName;
  final int amount;
  final int? commission;
  final DateTime date;
  final TransactionStatus status;
  final String? originalSeller;
  
  Transaction({
    required this.type,
    required this.productName,
    required this.amount,
    this.commission,
    required this.date,
    required this.status,
    this.originalSeller,
  });
}

class _TransactionGroup extends StatelessWidget {
  final String date;
  final String totalAmount;
  final List<Transaction> transactions;
  
  const _TransactionGroup({
    required this.date,
    required this.totalAmount,
    required this.transactions,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalAmount,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          ...transactions.map((transaction) => _TransactionItem(
            transaction: transaction,
          )),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;
  
  const _TransactionItem({required this.transaction});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: transaction.type == TransactionType.directSale
                ? Colors.blue[50]
                : Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.type == TransactionType.directSale
                ? Icons.sell
                : Icons.storefront,
              size: 20,
              color: transaction.type == TransactionType.directSale
                ? Colors.blue
                : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatDate(transaction.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (transaction.originalSeller != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${transaction.originalSeller}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                if (transaction.commission != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '수수료 ₩${_formatNumber(transaction.commission!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₩${_formatNumber(transaction.amount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(transaction.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(transaction.status),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(transaction.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return '오늘';
    if (difference == 1) return '어제';
    if (difference < 7) return '$difference일 전';
    if (difference < 30) return '${(difference / 7).floor()}주 전';
    return '${(difference / 30).floor()}개월 전';
  }
  
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
  
  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.cancelled:
        return Colors.red;
    }
  }
  
  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return '완료';
      case TransactionStatus.pending:
        return '대기중';
      case TransactionStatus.cancelled:
        return '취소됨';
    }
  }
}

class _WithdrawalBottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '출금 가능 금액',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '₩ 156,000',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _showAccountManagement(context);
                    },
                    icon: const Icon(Icons.account_balance, size: 18),
                    label: const Text('계좌 관리'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _showWithdrawalBottomSheet(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('출금하기'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '최소 출금 금액은 10,000원입니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showAccountManagement(BuildContext context) {
    // Show account management screen
    context.push('/account-management');
  }
  
  void _showWithdrawalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '출금 신청',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '출금 금액',
                  prefixText: '₩ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: '최대: ₩156,000',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '국민은행',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          Text(
                            '123-456789-00-123',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Process withdrawal
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('출금 신청이 완료되었습니다. 1-2 영업일 내에 입금됩니다.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '출금 신청하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}