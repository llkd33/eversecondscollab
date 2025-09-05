import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/transaction_service.dart';
import '../../services/product_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import 'user_management_screen.dart';
import 'transaction_monitoring_screen.dart';
import 'report_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final TransactionService _transactionService = TransactionService();
  final ProductService _productService = ProductService();
  
  UserModel? _currentUser;
  bool _isLoading = true;
  
  // 통계 데이터
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalProducts = 0;
  int _totalTransactions = 0;
  int _pendingReports = 0;
  double _totalRevenue = 0;
  
  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }
  
  Future<void> _checkAdminAccess() async {
    final user = await _authService.getCurrentUser();
    
    if (user == null || !user.isAdmin) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('관리자 권한이 필요합니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    setState(() {
      _currentUser = user;
    });
    
    await _loadStatistics();
  }
  
  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);
      
      // 통계 데이터 로드 (실제 구현 시 서비스 메소드 사용)
      // 여기서는 예시 데이터 사용
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _totalUsers = 1234;
        _activeUsers = 856;
        _totalProducts = 5678;
        _totalTransactions = 2345;
        _pendingReports = 12;
        _totalRevenue = 45678900;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_currentUser == null || !_currentUser!.isAdmin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 대시보드'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 관리자 정보
                    _buildAdminInfo(theme),
                    const SizedBox(height: 24),
                    
                    // 주요 통계
                    _buildStatisticsGrid(theme),
                    const SizedBox(height: 24),
                    
                    // 빠른 액션
                    _buildQuickActions(theme),
                    const SizedBox(height: 24),
                    
                    // 최근 활동
                    _buildRecentActivity(theme),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildAdminInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              _currentUser!.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser!.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '시스템 관리자',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  _currentUser!.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatisticsGrid(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주요 통계',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              theme,
              '전체 사용자',
              _totalUsers.toString(),
              Icons.people,
              Colors.blue,
            ),
            _buildStatCard(
              theme,
              '활성 사용자',
              _activeUsers.toString(),
              Icons.person_pin,
              Colors.green,
            ),
            _buildStatCard(
              theme,
              '등록 상품',
              _totalProducts.toString(),
              Icons.inventory,
              Colors.orange,
            ),
            _buildStatCard(
              theme,
              '거래 건수',
              _totalTransactions.toString(),
              Icons.shopping_cart,
              Colors.purple,
            ),
            _buildStatCard(
              theme,
              '대기중 신고',
              _pendingReports.toString(),
              Icons.report_problem,
              Colors.red,
              highlight: _pendingReports > 0,
            ),
            _buildStatCard(
              theme,
              '총 거래액',
              _formatCurrency(_totalRevenue),
              Icons.attach_money,
              Colors.teal,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? color.withOpacity(0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? color
              : theme.colorScheme.outline.withOpacity(0.2),
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              if (highlight)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'NEW',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: highlight ? color : null,
                ),
              ),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '빠른 액션',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
          children: [
            _buildActionButton(
              theme,
              '사용자\n관리',
              Icons.group,
              () => _navigateToUserManagement(),
            ),
            _buildActionButton(
              theme,
              '거래\n모니터링',
              Icons.monitor,
              () => _navigateToTransactionMonitoring(),
            ),
            _buildActionButton(
              theme,
              '신고\n처리',
              Icons.flag,
              () => _navigateToReportManagement(),
              badge: _pendingReports > 0 ? _pendingReports.toString() : null,
            ),
            _buildActionButton(
              theme,
              '상품\n관리',
              Icons.inventory_2,
              () => _showComingSoon(),
            ),
            _buildActionButton(
              theme,
              '통계\n분석',
              Icons.analytics,
              () => _showComingSoon(),
            ),
            _buildActionButton(
              theme,
              '시스템\n설정',
              Icons.settings,
              () => _showComingSoon(),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildActionButton(
    ThemeData theme,
    String label,
    IconData icon,
    VoidCallback onTap, {
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentActivity(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 활동',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // 예시 활동 목록
        ...[
          _buildActivityItem(
            theme,
            '새로운 사용자 가입',
            '홍길동님이 가입했습니다',
            Icons.person_add,
            Colors.blue,
            '5분 전',
          ),
          _buildActivityItem(
            theme,
            '신고 접수',
            '상품 허위 정보 신고',
            Icons.report,
            Colors.red,
            '10분 전',
          ),
          _buildActivityItem(
            theme,
            '거래 완료',
            '안전거래 1건 완료',
            Icons.check_circle,
            Colors.green,
            '30분 전',
          ),
          _buildActivityItem(
            theme,
            '대신판매 등록',
            '새로운 대신판매 상품',
            Icons.store,
            Colors.orange,
            '1시간 전',
          ),
        ],
      ],
    );
  }
  
  Widget _buildActivityItem(
    ThemeData theme,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String time,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  void _navigateToUserManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserManagementScreen(),
      ),
    );
  }
  
  void _navigateToTransactionMonitoring() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransactionMonitoringScreen(),
      ),
    );
  }
  
  void _navigateToReportManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportManagementScreen(),
      ),
    );
  }
  
  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('준비 중인 기능입니다'),
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
}