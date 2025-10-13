import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/app_settings_service.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/user_service.dart';
import '../../services/transaction_service.dart';
import '../../services/product_service.dart';
import '../../models/app_download_config.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../utils/responsive.dart';
import '../../widgets/admin/chart_widgets.dart';
import '../../widgets/admin/realtime_report_widgets.dart';

class WebAdminDashboard extends StatefulWidget {
  const WebAdminDashboard({super.key});

  @override
  State<WebAdminDashboard> createState() => _WebAdminDashboardState();
}

class _WebAdminDashboardState extends State<WebAdminDashboard> {
  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();
  final UserService _userService = UserService();
  final TransactionService _transactionService = TransactionService();
  final ProductService _productService = ProductService();
  final AppSettingsService _appSettingsService = AppSettingsService();

  AppDownloadConfig _appDownloadConfig = AppDownloadConfig.defaults();
  bool _isLoadingAppConfig = true;
  bool _isSavingAppConfig = false;

  final TextEditingController _playStoreController = TextEditingController();
  final TextEditingController _appStoreController = TextEditingController();
  final TextEditingController _universalLinkController = TextEditingController();
  final TextEditingController _qrImageController = TextEditingController();

  UserModel? _currentUser;
  bool _isLoading = true;
  int _selectedIndex = 0;

  // 통계 데이터
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalProducts = 0;
  int _totalTransactions = 0;
  int _pendingReports = 0;
  double _totalRevenue = 0;
  
  // 차트 데이터
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _categoryData = [];
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _playStoreController.dispose();
    _appStoreController.dispose();
    _universalLinkController.dispose();
    _qrImageController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final user = await _authService.getCurrentUser();

    if (user == null || !user.isAdmin) {
      if (mounted) {
        context.go('/login');
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
    await _loadAppDownloadConfig();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);

      // Load dashboard statistics
      final stats = await _adminService.getDashboardStats();
      
      // Load monthly data for charts
      final monthlyStats = await _adminService.getMonthlyStats();
      
      // Load category data
      final categoryStats = await _adminService.getCategoryStats();
      
      // Load recent activities
      final activities = await _adminService.getRecentActivities(limit: 10);

      setState(() {
        _totalUsers = stats['totalUsers'] ?? 0;
        _activeUsers = stats['activeUsers'] ?? 0;
        _totalProducts = stats['totalProducts'] ?? 0;
        _totalTransactions = stats['totalTransactions'] ?? 0;
        _pendingReports = stats['pendingReports'] ?? 0;
        _totalRevenue = (stats['totalRevenue'] ?? 0.0).toDouble();
        _monthlyData = monthlyStats;
        _categoryData = categoryStats;
        _recentActivities = activities;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAppDownloadConfig() async {
    try {
      final config = await _appSettingsService.fetchAppDownloadConfig();
      if (!mounted) return;

      setState(() {
        _appDownloadConfig = config;
        _playStoreController.text = config.playStoreUrl ?? '';
        _appStoreController.text = config.appStoreUrl ?? '';
        _universalLinkController.text = config.universalLink ?? '';
        _qrImageController.text = config.qrImageUrl ?? '';
        _isLoadingAppConfig = false;
      });
    } catch (e) {
      debugPrint('앱 다운로드 설정 불러오기 실패: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingAppConfig = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('앱 다운로드 설정을 불러오지 못했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveAppDownloadConfig() async {
    setState(() {
      _isSavingAppConfig = true;
    });

    final updatedConfig = AppDownloadConfig(
      id: _appDownloadConfig.id ?? 'default',
      playStoreUrl: _playStoreController.text.trim().isEmpty
          ? null
          : _playStoreController.text.trim(),
      appStoreUrl: _appStoreController.text.trim().isEmpty
          ? null
          : _appStoreController.text.trim(),
      universalLink: _universalLinkController.text.trim().isEmpty
          ? null
          : _universalLinkController.text.trim(),
      qrImageUrl: _qrImageController.text.trim().isEmpty
          ? null
          : _qrImageController.text.trim(),
    );

    final success = await _appSettingsService.upsertAppDownloadConfig(updatedConfig);

    if (!mounted) return;

    setState(() {
      _isSavingAppConfig = false;
      if (success) {
        _appDownloadConfig = updatedConfig.copyWith(updatedAt: DateTime.now());
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '앱 다운로드 설정이 저장되었습니다' : '앱 다운로드 설정 저장에 실패했습니다'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _resetAppDownloadConfigToDefault() {
    final defaults = AppDownloadConfig.defaults();
    setState(() {
      _appDownloadConfig = defaults;
      _playStoreController.text = defaults.playStoreUrl ?? '';
      _appStoreController.text = defaults.appStoreUrl ?? '';
      _universalLinkController.text = defaults.universalLink ?? '';
      _qrImageController.text = defaults.qrImageUrl ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null || !_currentUser!.isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 웹/데스크톱 환경 체크
    final isWeb = MediaQuery.of(context).size.width > 1024;
    
    if (!isWeb) {
      // 모바일/태블릿은 기존 관리자 화면으로 리다이렉트
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/admin');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // 사이드바
          _buildSidebar(),
          
          // 메인 콘텐츠
          Expanded(
            child: Column(
              children: [
                // 상단 헤더
                _buildHeader(),
                
                // 콘텐츠 영역
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 로고 영역
          Container(
            height: 80,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '관리자 패널',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // 사용자 정보
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    _currentUser?.name.substring(0, 1) ?? 'A',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.name ?? '관리자',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '최고 관리자',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 메뉴 아이템들
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard,
                  title: '대시보드',
                  index: 0,
                  badge: null,
                ),
                _buildMenuItem(
                  icon: Icons.people,
                  title: '사용자 관리',
                  index: 1,
                  badge: _totalUsers > 0 ? '$_totalUsers' : null,
                ),
                _buildMenuItem(
                  icon: Icons.inventory,
                  title: '상품 관리',
                  index: 2,
                  badge: _totalProducts > 0 ? '$_totalProducts' : null,
                ),
                _buildMenuItem(
                  icon: Icons.receipt_long,
                  title: '거래 관리',
                  index: 3,
                  badge: _totalTransactions > 0 ? '$_totalTransactions' : null,
                ),
                _buildMenuItem(
                  icon: Icons.report_problem,
                  title: '신고 관리',
                  index: 4,
                  badge: _pendingReports > 0 ? '$_pendingReports' : null,
                  badgeColor: Colors.red,
                ),
                _buildMenuItem(
                  icon: Icons.analytics,
                  title: '통계 분석',
                  index: 5,
                  badge: null,
                ),
                _buildMenuItem(
                  icon: Icons.settings,
                  title: '시스템 설정',
                  index: 6,
                  badge: null,
                ),
                const Divider(),
                _buildMenuItem(
                  icon: Icons.help,
                  title: '도움말',
                  index: 7,
                  badge: null,
                ),
              ],
            ),
          ),
          
          // 로그아웃 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.black87,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : Colors.grey[800],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor?.withOpacity(0.1) ?? Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 12,
                        color: badgeColor ?? Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 페이지 제목
          Text(
            _getPageTitle(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // 검색바
          Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: '검색...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // 알림 버튼
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              if (_pendingReports > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return '대시보드';
      case 1: return '사용자 관리';
      case 2: return '상품 관리';
      case 3: return '거래 관리';
      case 4: return '신고 관리';
      case 5: return '통계 분석';
      case 6: return '시스템 설정';
      case 7: return '도움말';
      default: return '대시보드';
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildUserManagement();
      case 2:
        return _buildProductManagement();
      case 3:
        return _buildTransactionManagement();
      case 4:
        return _buildReportManagement();
      case 5:
        return _buildAnalytics();
      case 6:
        return _buildSettings();
      case 7:
        return _buildHelp();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 통계 카드들
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            childAspectRatio: 1.5,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            children: [
              _buildStatCard(
                title: '총 사용자',
                value: _formatStatValue(_totalUsers),
                icon: Icons.people,
                color: Colors.blue,
                trend: _calculateTrend(_totalUsers, _activeUsers),
              ),
              _buildStatCard(
                title: '활성 사용자',
                value: _formatStatValue(_activeUsers),
                icon: Icons.person_pin,
                color: Colors.green,
                trend: _calculateActiveUserTrend(),
              ),
              _buildStatCard(
                title: '총 상품',
                value: _formatStatValue(_totalProducts),
                icon: Icons.inventory,
                color: Colors.orange,
                trend: _calculateProductTrend(),
              ),
              _buildStatCard(
                title: '총 거래',
                value: _formatStatValue(_totalTransactions),
                icon: Icons.receipt_long,
                color: Colors.purple,
                trend: _calculateTransactionTrend(),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // 차트 섹션
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 거래 추이 차트
              Expanded(
                flex: 2,
                child: _buildChartCard(
                  title: '월별 거래 추이',
                  child: SizedBox(
                    height: 300,
                    child: _monthlyData.isEmpty 
                      ? const Center(child: CircularProgressIndicator())
                      : MonthlyRevenueChart(data: _monthlyData),
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // 카테고리별 판매
              Expanded(
                child: _buildChartCard(
                  title: '카테고리별 판매',
                  child: SizedBox(
                    height: 300,
                    child: _categoryData.isEmpty 
                      ? const Center(child: CircularProgressIndicator())
                      : CategoryPieChart(data: _categoryData),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // 신고 현황 섹션
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 실시간 신고 대시보드
              Expanded(
                flex: 2,
                child: _buildChartCard(
                  title: '실시간 신고 현황',
                  child: const RealtimeReportDashboard(),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // 신고 통계 차트
              Expanded(
                child: _buildChartCard(
                  title: '신고 통계',
                  child: const ReportStatsChart(),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // 최근 활동
          _buildRecentActivityCard(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 활동',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _loadStatistics,
                child: const Text('새로고침'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_recentActivities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('최근 활동이 없습니다'),
              ),
            )
          else
            ...(_recentActivities.take(10).map((activity) => 
              _buildActivityItemFromData(activity)).toList()),
        ],
      ),
    );
  }

  Widget _buildActivityItemFromData(Map<String, dynamic> activity) {
    IconData icon;
    Color iconColor;
    
    switch (activity['type']) {
      case '신규 가입':
        icon = Icons.person_add;
        iconColor = Colors.green;
        break;
      case '상품 등록':
        icon = Icons.inventory;
        iconColor = Colors.blue;
        break;
      case '거래 완료':
        icon = Icons.check_circle;
        iconColor = Colors.purple;
        break;
      case '거래 생성':
        icon = Icons.shopping_cart;
        iconColor = Colors.orange;
        break;
      case '거래 취소':
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: activity['user'] ?? '알 수 없음',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '님이 '),
                      TextSpan(text: activity['type']),
                      if (activity['productTitle'] != null) ...[
                        const TextSpan(text: ' - '),
                        TextSpan(
                          text: activity['productTitle'],
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  activity['displayTime'] ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (activity['type'] == '상품 등록')
            IconButton(
              icon: const Icon(Icons.visibility, size: 18),
              onPressed: () {
                // Navigate to product detail
                context.push('/product/${activity['productId']}');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUserManagement() {
    return const Center(
      child: Text('사용자 관리 페이지'),
    );
  }

  Widget _buildProductManagement() {
    return const Center(
      child: Text('상품 관리 페이지'),
    );
  }

  Widget _buildTransactionManagement() {
    return const Center(
      child: Text('거래 관리 페이지'),
    );
  }

  Widget _buildReportManagement() {
    return const Center(
      child: Text('신고 관리 페이지'),
    );
  }

  Widget _buildAnalytics() {
    return const Center(
      child: Text('통계 분석 페이지'),
    );
  }

  Widget _buildSettings() {
    if (_isLoadingAppConfig) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시스템 설정',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '앱 다운로드 및 QR 코드 설정을 관리하세요. 변경 사항은 즉시 사용자에게 반영됩니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildAppDownloadSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildAppDownloadSettingsCard() {
    final lastUpdated = _appDownloadConfig.updatedAt;
    final lastUpdatedText = lastUpdated != null
        ? '마지막 수정: ${lastUpdated.toLocal().toString().split('.').first}'
        : '마지막 수정 정보가 없습니다';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '앱 다운로드 설정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastUpdatedText,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _isSavingAppConfig ? null : _resetAppDownloadConfigToDefault,
                icon: const Icon(Icons.restore),
                label: const Text('기본값 불러오기'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsField(
            label: 'Google Play 링크',
            controller: _playStoreController,
            hint: 'https://play.google.com/store/apps/details?id=...',
          ),
          _buildSettingsField(
            label: 'App Store 링크',
            controller: _appStoreController,
            hint: 'https://apps.apple.com/app/...',
          ),
          _buildSettingsField(
            label: '앱 다운로드 링크 (QR 생성용)',
            controller: _universalLinkController,
            hint: 'https://www.everseconds.com/app',
          ),
          _buildSettingsField(
            label: 'QR 이미지 URL (선택)',
            controller: _qrImageController,
            hint: '직접 생성한 QR 이미지 URL (선택사항)',
            helper: '입력하지 않으면 링크로 QR 코드를 자동 생성합니다.',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSavingAppConfig ? null : _saveAppDownloadConfig,
              icon: _isSavingAppConfig
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSavingAppConfig ? '저장중...' : '저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 6),
            Text(
              helper,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHelp() {
    return const Center(
      child: Text('도움말 페이지'),
    );
  }

  // Helper methods for formatting and calculations
  String _formatStatValue(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toString();
    }
  }

  String _calculateTrend(int total, int active) {
    if (total == 0) return '0%';
    final percentage = (active / total * 100).toStringAsFixed(1);
    return '+$percentage%';
  }

  String _calculateActiveUserTrend() {
    if (_monthlyData.length >= 2) {
      final lastMonth = _monthlyData[_monthlyData.length - 1]['newUsers'] ?? 0;
      final previousMonth = _monthlyData[_monthlyData.length - 2]['newUsers'] ?? 0;
      if (previousMonth > 0) {
        final change = ((lastMonth - previousMonth) / previousMonth * 100).toStringAsFixed(1);
        return lastMonth >= previousMonth ? '+$change%' : '$change%';
      }
    }
    return '+0%';
  }

  String _calculateProductTrend() {
    // Calculate based on monthly data if available
    if (_monthlyData.isNotEmpty) {
      final thisMonth = _monthlyData.last['transactions'] ?? 0;
      if (thisMonth > 0) {
        return '+${(thisMonth / 10).toStringAsFixed(0)}%'; // Rough estimate
      }
    }
    return '+0%';
  }

  String _calculateTransactionTrend() {
    if (_monthlyData.length >= 2) {
      final lastMonth = _monthlyData[_monthlyData.length - 1]['transactions'] ?? 0;
      final previousMonth = _monthlyData[_monthlyData.length - 2]['transactions'] ?? 0;
      if (previousMonth > 0) {
        final change = ((lastMonth - previousMonth) / previousMonth * 100).toStringAsFixed(1);
        return lastMonth >= previousMonth ? '+$change%' : '$change%';
      }
    }
    return '+0%';
  }
}
