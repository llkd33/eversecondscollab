import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/transaction_service.dart';
import '../../services/product_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive.dart';

class WebAdminDashboard extends StatefulWidget {
  const WebAdminDashboard({super.key});

  @override
  State<WebAdminDashboard> createState() => _WebAdminDashboardState();
}

class _WebAdminDashboardState extends State<WebAdminDashboard> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final TransactionService _transactionService = TransactionService();
  final ProductService _productService = ProductService();

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
  final List<Map<String, dynamic>> _monthlyData = [];
  final List<Map<String, dynamic>> _categoryData = [];

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
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
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);

      // TODO: 실제 데이터 로드 구현
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
                value: _totalUsers.toString(),
                icon: Icons.people,
                color: Colors.blue,
                trend: '+12%',
              ),
              _buildStatCard(
                title: '활성 사용자',
                value: _activeUsers.toString(),
                icon: Icons.person_pin,
                color: Colors.green,
                trend: '+8%',
              ),
              _buildStatCard(
                title: '총 상품',
                value: _totalProducts.toString(),
                icon: Icons.inventory,
                color: Colors.orange,
                trend: '+23%',
              ),
              _buildStatCard(
                title: '총 거래',
                value: _totalTransactions.toString(),
                icon: Icons.receipt_long,
                color: Colors.purple,
                trend: '+15%',
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
                  child: Container(
                    height: 300,
                    child: const Center(
                      child: Text('차트 구현 예정'),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // 카테고리별 판매
              Expanded(
                child: _buildChartCard(
                  title: '카테고리별 판매',
                  child: Container(
                    height: 300,
                    child: const Center(
                      child: Text('파이 차트 구현 예정'),
                    ),
                  ),
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
          const Text(
            '최근 활동',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(5, (index) => _buildActivityItem(index)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(int index) {
    final activities = [
      {'type': '신규 가입', 'user': '김민수', 'time': '5분 전'},
      {'type': '상품 등록', 'user': '이영희', 'time': '12분 전'},
      {'type': '거래 완료', 'user': '박철수', 'time': '30분 전'},
      {'type': '신고 접수', 'user': '정미경', 'time': '1시간 전'},
      {'type': '리뷰 작성', 'user': '홍길동', 'time': '2시간 전'},
    ];
    
    final activity = activities[index];
    
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
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              activity['user']!.substring(0, 1),
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
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: activity['user'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '님이 '),
                      TextSpan(text: activity['type']),
                      const TextSpan(text: '했습니다'),
                    ],
                  ),
                ),
                Text(
                  activity['time']!,
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
    return const Center(
      child: Text('시스템 설정 페이지'),
    );
  }

  Widget _buildHelp() {
    return const Center(
      child: Text('도움말 페이지'),
    );
  }
}