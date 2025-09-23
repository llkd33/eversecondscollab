import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/dashboard_widgets.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../utils/responsive.dart';

class EnhancedDashboardScreen extends StatefulWidget {
  const EnhancedDashboardScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedDashboardScreen> createState() => _EnhancedDashboardScreenState();
}

class _EnhancedDashboardScreenState extends State<EnhancedDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '오늘';
  String _selectedMetric = '전체';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // 실시간 데이터 업데이트 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminDashboardProvider>().startRealTimeUpdates();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    context.read<AdminDashboardProvider>().stopRealTimeUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Consumer<AdminDashboardProvider>(
        builder: (context, provider, child) {
          return CustomScrollView(
            slivers: [
              // 상단 필터 섹션
              SliverToBoxAdapter(
                child: _buildFilterSection(responsive),
              ),
              
              // 주요 통계 카드들
              SliverToBoxAdapter(
                child: _buildStatsSection(provider, responsive),
              ),
              
              // 탭 콘텐츠
              SliverFillRemaining(
                child: _buildTabContent(provider, responsive),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Text(
              '관리자',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('실시간 대시보드'),
        ],
      ),
      actions: [
        // 새로고침 버튼
        Consumer<AdminDashboardProvider>(
          builder: (context, provider, child) {
            return Stack(
              children: [
                IconButton(
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: provider.isLoading ? null : () {
                    provider.refreshData();
                  },
                ),
                if (provider.hasUnreadAlerts)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // 알림 센터
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showNotificationCenter(),
        ),
        // 설정
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download),
                  SizedBox(width: 8),
                  Text('데이터 내보내기'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text('설정'),
                ],
              ),
            ),
          ],
          onSelected: (value) => _handleMenuAction(value),
        ),
      ],
    );
  }

  Widget _buildFilterSection(Responsive responsive) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow,
      ),
      child: responsive.isMobile
          ? Column(
              children: [
                _buildPeriodFilter(),
                const SizedBox(height: AppTheme.spacingSm),
                _buildMetricFilter(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildPeriodFilter()),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(child: _buildMetricFilter()),
              ],
            ),
    );
  }

  Widget _buildPeriodFilter() {
    final periods = ['오늘', '어제', '7일', '30일', '90일'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기간',
          style: AppStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Wrap(
          spacing: AppTheme.spacingXs,
          children: periods.map((period) {
            final isSelected = _selectedPeriod == period;
            return FilterChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedPeriod = period;
                });
                context.read<AdminDashboardProvider>().updatePeriod(period);
              },
              backgroundColor: isSelected ? AppTheme.primaryColor : null,
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricFilter() {
    final metrics = ['전체', '사용자', '거래', '상품', '매출'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '지표',
          style: AppStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Wrap(
          spacing: AppTheme.spacingXs,
          children: metrics.map((metric) {
            final isSelected = _selectedMetric == metric;
            return FilterChip(
              label: Text(metric),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedMetric = metric;
                });
                context.read<AdminDashboardProvider>().updateMetric(metric);
              },
              backgroundColor: isSelected ? AppTheme.secondaryColor : null,
              selectedColor: AppTheme.secondaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatsSection(AdminDashboardProvider provider, Responsive responsive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: responsive.isMobile
          ? Column(
              children: _buildStatsCards(provider),
            )
          : responsive.isTablet
              ? Wrap(
                  spacing: AppTheme.spacingMd,
                  runSpacing: AppTheme.spacingMd,
                  children: _buildStatsCards(provider)
                      .map((card) => SizedBox(
                            width: (MediaQuery.of(context).size.width - 48) / 2,
                            child: card,
                          ))
                      .toList(),
                )
              : Row(
                  children: _buildStatsCards(provider)
                      .map((card) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: AppTheme.spacingMd),
                              child: card,
                            ),
                          ))
                      .toList(),
                ),
    );
  }

  List<Widget> _buildStatsCards(AdminDashboardProvider provider) {
    return [
      StatsCard(
        title: '전체 사용자',
        value: provider.totalUsers.toString(),
        change: provider.userGrowthRate,
        icon: Icons.people,
        color: AppTheme.primaryColor,
        trend: provider.userTrend,
      ),
      StatsCard(
        title: '활성 거래',
        value: provider.activeTransactions.toString(),
        change: provider.transactionGrowthRate,
        icon: Icons.trending_up,
        color: AppTheme.secondaryColor,
        trend: provider.transactionTrend,
      ),
      StatsCard(
        title: '총 매출',
        value: '₩${provider.totalRevenue}',
        change: provider.revenueGrowthRate,
        icon: Icons.monetization_on,
        color: AppTheme.accentColor,
        trend: provider.revenueTrend,
      ),
      StatsCard(
        title: '등록 상품',
        value: provider.totalProducts.toString(),
        change: provider.productGrowthRate,
        icon: Icons.inventory,
        color: AppTheme.successColor,
        trend: provider.productTrend,
      ),
    ];
  }

  Widget _buildTabContent(AdminDashboardProvider provider, Responsive responsive) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.cardShadow,
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '개요', icon: Icon(Icons.dashboard)),
              Tab(text: '차트', icon: Icon(Icons.bar_chart)),
              Tab(text: '활동', icon: Icon(Icons.timeline)),
              Tab(text: '알림', icon: Icon(Icons.notifications)),
            ],
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(provider, responsive),
              _buildChartsTab(provider, responsive),
              _buildActivityTab(provider, responsive),
              _buildNotificationsTab(provider, responsive),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(AdminDashboardProvider provider, Responsive responsive) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          // 실시간 사용자 활동
          RealTimeUserActivity(
            data: provider.realTimeUserData,
            isLoading: provider.isLoading,
          ),
          
          const SizedBox(height: AppTheme.spacingLg),
          
          // 최근 거래 목록
          RecentTransactionsList(
            transactions: provider.recentTransactions,
            onTransactionTap: (transaction) => _viewTransactionDetails(transaction),
          ),
          
          const SizedBox(height: AppTheme.spacingLg),
          
          // 시스템 상태
          SystemStatusCard(
            systemHealth: provider.systemHealth,
            serverStatus: provider.serverStatus,
            databaseStatus: provider.databaseStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsTab(AdminDashboardProvider provider, Responsive responsive) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          // 매출 추이 차트
          RevenueChart(
            data: provider.revenueChartData,
            period: _selectedPeriod,
            isLoading: provider.isLoading,
          ),
          
          const SizedBox(height: AppTheme.spacingLg),
          
          // 사용자 증가 차트
          UserGrowthChart(
            data: provider.userGrowthChartData,
            period: _selectedPeriod,
            isLoading: provider.isLoading,
          ),
          
          const SizedBox(height: AppTheme.spacingLg),
          
          // 카테고리별 판매 분포
          CategoryDistributionChart(
            data: provider.categoryDistribution,
            isLoading: provider.isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(AdminDashboardProvider provider, Responsive responsive) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: ActivityLogWidget(
        activities: provider.recentActivities,
        onActivityTap: (activity) => _viewActivityDetails(activity),
        isLoading: provider.isLoading,
      ),
    );
  }

  Widget _buildNotificationsTab(AdminDashboardProvider provider, Responsive responsive) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: NotificationCenterWidget(
        notifications: provider.notifications,
        onNotificationTap: (notification) => _handleNotification(notification),
        onMarkAsRead: (notification) => provider.markNotificationAsRead(notification.id),
        onMarkAllAsRead: () => provider.markAllNotificationsAsRead(),
        isLoading: provider.isLoading,
      ),
    );
  }

  void _showNotificationCenter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.dividerColor),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '알림 센터',
                        style: AppStyles.headingSmall,
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<AdminDashboardProvider>().markAllNotificationsAsRead();
                          Navigator.pop(context);
                        },
                        child: const Text('모두 읽음'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<AdminDashboardProvider>(
                    builder: (context, provider, child) {
                      return NotificationCenterWidget(
                        notifications: provider.notifications,
                        onNotificationTap: (notification) {
                          _handleNotification(notification);
                          Navigator.pop(context);
                        },
                        onMarkAsRead: (notification) => 
                            provider.markNotificationAsRead(notification.id),
                        onMarkAllAsRead: () => provider.markAllNotificationsAsRead(),
                        isLoading: provider.isLoading,
                        scrollController: scrollController,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportData();
        break;
      case 'settings':
        _openSettings();
        break;
    }
  }

  void _exportData() {
    // 데이터 내보내기 로직
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('데이터 내보내기가 시작되었습니다.'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _openSettings() {
    // 설정 화면으로 이동
    Navigator.pushNamed(context, '/admin/settings');
  }

  void _viewTransactionDetails(dynamic transaction) {
    // 거래 상세 화면으로 이동
    Navigator.pushNamed(context, '/admin/transaction/${transaction.id}');
  }

  void _viewActivityDetails(dynamic activity) {
    // 활동 상세 화면으로 이동
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('활동 상세'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('유형: ${activity.type}'),
            Text('사용자: ${activity.userId}'),
            Text('시간: ${activity.timestamp}'),
            Text('상세: ${activity.details}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _handleNotification(dynamic notification) {
    // 알림 처리 로직
    switch (notification.type) {
      case 'security_alert':
        _handleSecurityAlert(notification);
        break;
      case 'system_warning':
        _handleSystemWarning(notification);
        break;
      case 'user_report':
        _handleUserReport(notification);
        break;
      default:
        _showDefaultNotificationDialog(notification);
    }
  }

  void _handleSecurityAlert(dynamic notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            const Text('보안 경고'),
          ],
        ),
        content: Text(notification.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 보안 대응 화면으로 이동
              Navigator.pushNamed(context, '/admin/security');
            },
            child: const Text('조치하기'),
          ),
        ],
      ),
    );
  }

  void _handleSystemWarning(dynamic notification) {
    // 시스템 경고 처리
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notification.message),
        backgroundColor: AppTheme.warningColor,
        action: SnackBarAction(
          label: '자세히',
          onPressed: () {
            Navigator.pushNamed(context, '/admin/system-status');
          },
        ),
      ),
    );
  }

  void _handleUserReport(dynamic notification) {
    // 사용자 신고 처리
    Navigator.pushNamed(context, '/admin/reports/${notification.reportId}');
  }

  void _showDefaultNotificationDialog(dynamic notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Text(notification.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}