import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin/monitoring_service.dart';

class AdminDashboardProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _monitoringService = MonitoringService();
  
  // 로딩 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // 실시간 업데이트 관련
  Timer? _updateTimer;
  StreamSubscription? _systemEventSubscription;
  StreamSubscription? _securityAlertSubscription;
  StreamSubscription? _performanceMetricSubscription;
  
  // 기본 통계 데이터
  int _totalUsers = 0;
  int _activeTransactions = 0;
  String _totalRevenue = '0';
  int _totalProducts = 0;
  
  // 증감률 데이터
  double _userGrowthRate = 0.0;
  double _transactionGrowthRate = 0.0;
  double _revenueGrowthRate = 0.0;
  double _productGrowthRate = 0.0;
  
  // 트렌드 데이터
  List<double> _userTrend = [];
  List<double> _transactionTrend = [];
  List<double> _revenueTrend = [];
  List<double> _productTrend = [];
  
  // 실시간 사용자 활동 데이터
  List<Map<String, dynamic>> _realTimeUserData = [];
  
  // 최근 거래 데이터
  List<Map<String, dynamic>> _recentTransactions = [];
  
  // 시스템 상태 데이터
  Map<String, dynamic> _systemHealth = {};
  Map<String, dynamic> _serverStatus = {};
  Map<String, dynamic> _databaseStatus = {};
  
  // 차트 데이터
  List<Map<String, dynamic>> _revenueChartData = [];
  List<Map<String, dynamic>> _userGrowthChartData = [];
  List<Map<String, dynamic>> _categoryDistribution = [];
  
  // 활동 로그 데이터
  List<Map<String, dynamic>> _recentActivities = [];
  
  // 알림 데이터
  List<Map<String, dynamic>> _notifications = [];
  bool _hasUnreadAlerts = false;
  
  // 필터 상태
  String _currentPeriod = '오늘';
  String _currentMetric = '전체';
  
  // Getters
  int get totalUsers => _totalUsers;
  int get activeTransactions => _activeTransactions;
  String get totalRevenue => _totalRevenue;
  int get totalProducts => _totalProducts;
  
  double get userGrowthRate => _userGrowthRate;
  double get transactionGrowthRate => _transactionGrowthRate;
  double get revenueGrowthRate => _revenueGrowthRate;
  double get productGrowthRate => _productGrowthRate;
  
  List<double> get userTrend => _userTrend;
  List<double> get transactionTrend => _transactionTrend;
  List<double> get revenueTrend => _revenueTrend;
  List<double> get productTrend => _productTrend;
  
  List<Map<String, dynamic>> get realTimeUserData => _realTimeUserData;
  List<Map<String, dynamic>> get recentTransactions => _recentTransactions;
  
  Map<String, dynamic> get systemHealth => _systemHealth;
  Map<String, dynamic> get serverStatus => _serverStatus;
  Map<String, dynamic> get databaseStatus => _databaseStatus;
  
  List<Map<String, dynamic>> get revenueChartData => _revenueChartData;
  List<Map<String, dynamic>> get userGrowthChartData => _userGrowthChartData;
  List<Map<String, dynamic>> get categoryDistribution => _categoryDistribution;
  
  List<Map<String, dynamic>> get recentActivities => _recentActivities;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get hasUnreadAlerts => _hasUnreadAlerts;
  
  String get currentPeriod => _currentPeriod;
  String get currentMetric => _currentMetric;
  
  // 실시간 업데이트 시작
  Future<void> startRealTimeUpdates() async {
    try {
      print('🚀 관리자 대시보드 실시간 업데이트 시작');
      
      // 모니터링 서비스 시작
      await _monitoringService.startMonitoring();
      
      // 스트림 구독
      _subscribeToStreams();
      
      // 초기 데이터 로드
      await _loadInitialData();
      
      // 주기적 업데이트 (30초마다)
      _updateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _updateDashboardData(),
      );
      
    } catch (e) {
      print('❌ 실시간 업데이트 시작 실패: $e');
    }
  }
  
  // 실시간 업데이트 중지
  void stopRealTimeUpdates() {
    print('🛑 관리자 대시보드 실시간 업데이트 중지');
    
    _updateTimer?.cancel();
    _systemEventSubscription?.cancel();
    _securityAlertSubscription?.cancel();
    _performanceMetricSubscription?.cancel();
    
    _monitoringService.stopMonitoring();
  }
  
  // 스트림 구독
  void _subscribeToStreams() {
    // 시스템 이벤트 구독
    _systemEventSubscription = _monitoringService.systemEvents.listen((event) {
      _handleSystemEvent(event);
    });
    
    // 보안 경고 구독
    _securityAlertSubscription = _monitoringService.securityAlerts.listen((alert) {
      _handleSecurityAlert(alert);
    });
    
    // 성능 메트릭 구독
    _performanceMetricSubscription = _monitoringService.performanceMetrics.listen((metric) {
      _handlePerformanceMetric(metric);
    });
  }
  
  // 초기 데이터 로드
  Future<void> _loadInitialData() async {
    _setLoading(true);
    
    try {
      await Future.wait([
        _loadBasicStats(),
        _loadTrendData(),
        _loadRecentTransactions(),
        _loadSystemStatus(),
        _loadChartData(),
        _loadRecentActivities(),
        _loadNotifications(),
      ]);
    } catch (e) {
      print('❌ 초기 데이터 로드 실패: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 대시보드 데이터 업데이트
  Future<void> _updateDashboardData() async {
    try {
      await Future.wait([
        _loadBasicStats(),
        _updateRealTimeUserData(),
        _updateSystemStatus(),
      ]);
    } catch (e) {
      print('❌ 대시보드 데이터 업데이트 실패: $e');
    }
  }
  
  // 기본 통계 로드
  Future<void> _loadBasicStats() async {
    try {
      // 전체 사용자 수
      final usersResponse = await _supabase
          .from('users')
          .select('id')
          .count();
      _totalUsers = usersResponse.count;
      
      // 활성 거래 수
      final activeTransactionsResponse = await _supabase
          .from('transactions')
          .select('id')
          .in_('status', ['pending', 'processing'])
          .count();
      _activeTransactions = activeTransactionsResponse.count;
      
      // 총 매출 (완료된 거래)
      final revenueResponse = await _supabase
          .from('transactions')
          .select('amount')
          .eq('status', 'completed');
      
      double totalRevenue = 0;
      for (var transaction in revenueResponse) {
        totalRevenue += (transaction['amount'] as num?)?.toDouble() ?? 0;
      }
      _totalRevenue = _formatRevenue(totalRevenue);
      
      // 총 상품 수
      final productsResponse = await _supabase
          .from('products')
          .select('id')
          .count();
      _totalProducts = productsResponse.count;
      
      // 증감률 계산
      await _calculateGrowthRates();
      
    } catch (e) {
      print('❌ 기본 통계 로드 실패: $e');
    }
  }
  
  // 증감률 계산
  Future<void> _calculateGrowthRates() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final yesterdayEnd = yesterdayStart.add(const Duration(days: 1));
      
      // 어제 사용자 수
      final yesterdayUsersResponse = await _supabase
          .from('users')
          .select('id')
          .gte('created_at', yesterdayStart.toIso8601String())
          .lt('created_at', yesterdayEnd.toIso8601String())
          .count();
      
      final todayUsersResponse = await _supabase
          .from('users')
          .select('id')
          .gte('created_at', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
          .count();
      
      _userGrowthRate = _calculatePercentageChange(
        yesterdayUsersResponse.count.toDouble(),
        todayUsersResponse.count.toDouble(),
      );
      
      // 거래 증감률 (시뮬레이션)
      _transactionGrowthRate = _generateRealisticGrowthRate();
      _revenueGrowthRate = _generateRealisticGrowthRate();
      _productGrowthRate = _generateRealisticGrowthRate();
      
    } catch (e) {
      print('❌ 증감률 계산 실패: $e');
      // 시뮬레이션 데이터 사용
      _userGrowthRate = _generateRealisticGrowthRate();
      _transactionGrowthRate = _generateRealisticGrowthRate();
      _revenueGrowthRate = _generateRealisticGrowthRate();
      _productGrowthRate = _generateRealisticGrowthRate();
    }
  }
  
  // 트렌드 데이터 로드
  Future<void> _loadTrendData() async {
    try {
      // 7일간의 트렌드 데이터 생성 (시뮬레이션)
      _userTrend = _generateTrendData(7, 50, 200);
      _transactionTrend = _generateTrendData(7, 20, 100);
      _revenueTrend = _generateTrendData(7, 1000, 5000);
      _productTrend = _generateTrendData(7, 10, 50);
      
    } catch (e) {
      print('❌ 트렌드 데이터 로드 실패: $e');
    }
  }
  
  // 최근 거래 로드
  Future<void> _loadRecentTransactions() async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('''
            id,
            amount,
            status,
            created_at,
            product:products(name),
            buyer:users!buyer_id(name),
            seller:users!seller_id(name)
          ''')
          .order('created_at', ascending: false)
          .limit(10);
      
      _recentTransactions = response.map((transaction) {
        return {
          'id': transaction['id'],
          'product_name': transaction['product']?['name'] ?? '알 수 없는 상품',
          'buyer_name': transaction['buyer']?['name'] ?? '익명',
          'seller_name': transaction['seller']?['name'] ?? '익명',
          'amount': transaction['amount'],
          'status': transaction['status'],
          'created_at': transaction['created_at'],
        };
      }).toList();
      
    } catch (e) {
      print('❌ 최근 거래 로드 실패: $e');
      // 시뮬레이션 데이터 사용
      _recentTransactions = _generateMockTransactions();
    }
  }
  
  // 실시간 사용자 활동 업데이트
  Future<void> _updateRealTimeUserData() async {
    try {
      // 실시간 활동 데이터 시뮬레이션
      _realTimeUserData = _generateMockUserActivities();
      
    } catch (e) {
      print('❌ 실시간 사용자 활동 업데이트 실패: $e');
    }
  }
  
  // 시스템 상태 로드/업데이트
  Future<void> _loadSystemStatus() async {
    await _updateSystemStatus();
  }
  
  Future<void> _updateSystemStatus() async {
    try {
      final systemStatus = _monitoringService.getSystemStatus();
      
      _systemHealth = systemStatus['metrics'] ?? {};
      _serverStatus = {'status': systemStatus['status']};
      _databaseStatus = {'status': 'healthy'}; // 시뮬레이션
      
    } catch (e) {
      print('❌ 시스템 상태 업데이트 실패: $e');
      _systemHealth = _generateMockSystemHealth();
      _serverStatus = {'status': 'healthy'};
      _databaseStatus = {'status': 'healthy'};
    }
  }
  
  // 차트 데이터 로드
  Future<void> _loadChartData() async {
    try {
      _revenueChartData = _generateRevenueChartData(_currentPeriod);
      _userGrowthChartData = _generateUserGrowthChartData(_currentPeriod);
      _categoryDistribution = _generateCategoryDistribution();
      
    } catch (e) {
      print('❌ 차트 데이터 로드 실패: $e');
    }
  }
  
  // 최근 활동 로드
  Future<void> _loadRecentActivities() async {
    try {
      _recentActivities = _generateMockActivities();
      
    } catch (e) {
      print('❌ 최근 활동 로드 실패: $e');
    }
  }
  
  // 알림 로드
  Future<void> _loadNotifications() async {
    try {
      _notifications = _generateMockNotifications();
      _hasUnreadAlerts = _notifications.any((notif) => !(notif['is_read'] ?? false));
      
    } catch (e) {
      print('❌ 알림 로드 실패: $e');
    }
  }
  
  // 시스템 이벤트 처리
  void _handleSystemEvent(SystemEvent event) {
    // 새로운 시스템 이벤트를 활동 로그에 추가
    _recentActivities.insert(0, {
      'id': event.id,
      'type': event.type,
      'severity': event.severity,
      'message': event.message,
      'user': '시스템',
      'timestamp': event.timestamp.toIso8601String(),
      'metadata': event.metadata,
    });
    
    // 최대 100개만 유지
    if (_recentActivities.length > 100) {
      _recentActivities.removeAt(_recentActivities.length - 1);
    }
    
    notifyListeners();
  }
  
  // 보안 경고 처리
  void _handleSecurityAlert(SecurityAlert alert) {
    // 새로운 보안 경고를 알림에 추가
    _notifications.insert(0, {
      'id': alert.id,
      'type': 'security_alert',
      'title': '보안 경고',
      'message': alert.message,
      'is_read': false,
      'timestamp': alert.timestamp.toIso8601String(),
      'metadata': alert.metadata,
    });
    
    _hasUnreadAlerts = true;
    notifyListeners();
  }
  
  // 성능 메트릭 처리
  void _handlePerformanceMetric(PerformanceMetric metric) {
    // 시스템 상태 업데이트
    _systemHealth = {
      'cpu_usage': metric.cpuUsage,
      'memory_usage': metric.memoryUsage,
      'disk_usage': metric.diskUsage,
      'response_time': metric.responseTime,
      'error_rate': metric.errorRate,
      'active_users': metric.activeUsers,
      'overall': _determineOverallHealth(metric),
    };
    
    notifyListeners();
  }
  
  // 전체 시스템 상태 판단
  String _determineOverallHealth(PerformanceMetric metric) {
    if (metric.cpuUsage > 90 || metric.memoryUsage > 90 || metric.errorRate > 10) {
      return 'critical';
    } else if (metric.cpuUsage > 80 || metric.memoryUsage > 80 || metric.errorRate > 5) {
      return 'warning';
    } else {
      return 'healthy';
    }
  }
  
  // 데이터 새로고침
  Future<void> refreshData() async {
    await _loadInitialData();
  }
  
  // 기간 필터 업데이트
  void updatePeriod(String period) {
    _currentPeriod = period;
    _loadChartData();
    notifyListeners();
  }
  
  // 지표 필터 업데이트
  void updateMetric(String metric) {
    _currentMetric = metric;
    notifyListeners();
  }
  
  // 알림 읽음 처리
  void markNotificationAsRead(String notificationId) {
    final index = _notifications.indexWhere((notif) => notif['id'] == notificationId);
    if (index != -1) {
      _notifications[index]['is_read'] = true;
      _hasUnreadAlerts = _notifications.any((notif) => !(notif['is_read'] ?? false));
      notifyListeners();
    }
  }
  
  // 모든 알림 읽음 처리
  void markAllNotificationsAsRead() {
    for (var notification in _notifications) {
      notification['is_read'] = true;
    }
    _hasUnreadAlerts = false;
    notifyListeners();
  }
  
  // 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // 유틸리티 메서드들
  
  double _calculatePercentageChange(double oldValue, double newValue) {
    if (oldValue == 0) return newValue > 0 ? 100.0 : 0.0;
    return ((newValue - oldValue) / oldValue) * 100;
  }
  
  double _generateRealisticGrowthRate() {
    final random = math.Random();
    // -20% ~ +30% 범위의 성장률
    return (random.nextDouble() * 50) - 20;
  }
  
  List<double> _generateTrendData(int days, double min, double max) {
    final random = math.Random();
    final trend = <double>[];
    
    for (int i = 0; i < days; i++) {
      final value = min + (max - min) * random.nextDouble();
      trend.add(value);
    }
    
    return trend;
  }
  
  String _formatRevenue(double revenue) {
    if (revenue >= 1000000000) {
      return '${(revenue / 1000000000).toStringAsFixed(1)}B';
    } else if (revenue >= 1000000) {
      return '${(revenue / 1000000).toStringAsFixed(1)}M';
    } else if (revenue >= 1000) {
      return '${(revenue / 1000).toStringAsFixed(1)}K';
    } else {
      return revenue.toStringAsFixed(0);
    }
  }
  
  // 모의 데이터 생성 메서드들
  
  List<Map<String, dynamic>> _generateMockTransactions() {
    final random = math.Random();
    final products = ['iPhone 14', '맥북 프로', '에어팟', '아이패드', '애플워치'];
    final statuses = ['completed', 'pending', 'processing', 'failed'];
    
    return List.generate(10, (index) {
      return {
        'id': 'tx_${index + 1}',
        'product_name': products[random.nextInt(products.length)],
        'buyer_name': '구매자${index + 1}',
        'seller_name': '판매자${index + 1}',
        'amount': (random.nextInt(2000) + 100) * 1000,
        'status': statuses[random.nextInt(statuses.length)],
        'created_at': DateTime.now().subtract(Duration(hours: index)).toIso8601String(),
      };
    });
  }
  
  List<Map<String, dynamic>> _generateMockUserActivities() {
    final random = math.Random();
    final activities = [
      {'type': 'login', 'description': '사용자 로그인'},
      {'type': 'purchase', 'description': '상품 구매'},
      {'type': 'product_view', 'description': '상품 조회'},
      {'type': 'transaction', 'description': '거래 생성'},
    ];
    
    return List.generate(20, (index) {
      final activity = activities[random.nextInt(activities.length)];
      return {
        'id': 'activity_${index + 1}',
        'type': activity['type'],
        'description': activity['description'],
        'user': '사용자${random.nextInt(100) + 1}',
        'timestamp': DateTime.now().subtract(Duration(minutes: index * 5)).toIso8601String(),
      };
    });
  }
  
  Map<String, dynamic> _generateMockSystemHealth() {
    final random = math.Random();
    return {
      'cpu_usage': 20 + random.nextDouble() * 60,
      'memory_usage': 30 + random.nextDouble() * 50,
      'disk_usage': 40 + random.nextDouble() * 40,
      'response_time': 100 + random.nextDouble() * 200,
      'error_rate': random.nextDouble() * 5,
      'active_users': random.nextInt(200) + 50,
      'overall': 'healthy',
    };
  }
  
  List<Map<String, dynamic>> _generateRevenueChartData(String period) {
    final random = math.Random();
    final labels = _getPeriodLabels(period);
    
    return labels.map((label) {
      return {
        'label': label,
        'value': (random.nextDouble() * 5000000) + 1000000, // 1M ~ 6M
      };
    }).toList();
  }
  
  List<Map<String, dynamic>> _generateUserGrowthChartData(String period) {
    final random = math.Random();
    final labels = _getPeriodLabels(period);
    
    return labels.map((label) {
      return {
        'label': label,
        'value': random.nextInt(100) + 20,
      };
    }).toList();
  }
  
  List<Map<String, dynamic>> _generateCategoryDistribution() {
    final categories = [
      {'category': '전자제품', 'value': 1200, 'percentage': 35.5},
      {'category': '의류', 'value': 800, 'percentage': 23.7},
      {'category': '도서', 'value': 600, 'percentage': 17.8},
      {'category': '스포츠', 'value': 450, 'percentage': 13.3},
      {'category': '기타', 'value': 330, 'percentage': 9.7},
    ];
    
    return categories;
  }
  
  List<String> _getPeriodLabels(String period) {
    switch (period) {
      case '오늘':
        return ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'];
      case '어제':
        return ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'];
      case '7일':
        final now = DateTime.now();
        return List.generate(7, (index) {
          final date = now.subtract(Duration(days: 6 - index));
          return '${date.month}/${date.day}';
        });
      case '30일':
        final now = DateTime.now();
        return List.generate(6, (index) {
          final date = now.subtract(Duration(days: (5 - index) * 5));
          return '${date.month}/${date.day}';
        });
      case '90일':
        final now = DateTime.now();
        return List.generate(6, (index) {
          final date = now.subtract(Duration(days: (5 - index) * 15));
          return '${date.month}/${date.day}';
        });
      default:
        return ['데이터 없음'];
    }
  }
  
  List<Map<String, dynamic>> _generateMockActivities() {
    final random = math.Random();
    final severities = ['info', 'warning', 'critical', 'success'];
    final messages = [
      '새로운 사용자 가입',
      '거래가 완료되었습니다',
      '시스템 백업이 시작되었습니다',
      '보안 스캔이 완료되었습니다',
      '데이터베이스 최적화 완료',
    ];
    
    return List.generate(50, (index) {
      return {
        'id': 'activity_${index + 1}',
        'type': 'system_event',
        'severity': severities[random.nextInt(severities.length)],
        'message': messages[random.nextInt(messages.length)],
        'user': random.nextBool() ? '사용자${random.nextInt(100) + 1}' : '시스템',
        'timestamp': DateTime.now().subtract(Duration(hours: index)).toIso8601String(),
      };
    });
  }
  
  List<Map<String, dynamic>> _generateMockNotifications() {
    final random = math.Random();
    final types = ['security_alert', 'system_warning', 'user_report', 'transaction_issue'];
    final titles = ['보안 경고', '시스템 경고', '사용자 신고', '거래 문제'];
    
    return List.generate(20, (index) {
      final typeIndex = random.nextInt(types.length);
      return {
        'id': 'notif_${index + 1}',
        'type': types[typeIndex],
        'title': titles[typeIndex],
        'message': '중요한 알림이 있습니다. 확인해 주세요.',
        'is_read': random.nextBool(),
        'timestamp': DateTime.now().subtract(Duration(hours: index)).toIso8601String(),
      };
    });
  }
  
  @override
  void dispose() {
    stopRealTimeUpdates();
    super.dispose();
  }
}