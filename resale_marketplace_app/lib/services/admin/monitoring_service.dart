import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';

class MonitoringService {
  final _supabase = Supabase.instance.client;

  // 스트림 컨트롤러들
  final _systemEventController = StreamController<SystemEvent>.broadcast();
  final _securityAlertController = StreamController<SecurityAlert>.broadcast();
  final _performanceMetricController =
      StreamController<PerformanceMetric>.broadcast();
  final _userActivityController = StreamController<UserActivity>.broadcast();

  // 타이머들
  Timer? _realTimeMonitoringTimer;
  Timer? _performanceCheckTimer;
  Timer? _securityScanTimer;

  bool _isMonitoring = false;

  // 임계값 설정
  static const Map<String, dynamic> _thresholds = {
    'cpu_usage': 80.0,
    'memory_usage': 85.0,
    'disk_usage': 90.0,
    'response_time': 3000, // ms
    'error_rate': 5.0, // %
    'concurrent_users': 1000,
    'failed_login_attempts': 5,
    'suspicious_activity_score': 70.0,
  };

  // 캐시된 메트릭 데이터
  final Map<String, dynamic> _cachedMetrics = {};
  final List<SystemEvent> _recentEvents = [];
  final List<SecurityAlert> _activeAlerts = [];

  // Getters for streams
  Stream<SystemEvent> get systemEvents => _systemEventController.stream;
  Stream<SecurityAlert> get securityAlerts => _securityAlertController.stream;
  Stream<PerformanceMetric> get performanceMetrics =>
      _performanceMetricController.stream;
  Stream<UserActivity> get userActivities => _userActivityController.stream;

  // 모니터링 시작
  Future<void> startMonitoring() async {
    try {
      if (_isMonitoring) return;
      _isMonitoring = true;
      print('🚀 모니터링 서비스 시작');

      // 실시간 모니터링 시작 (30초마다)
      _realTimeMonitoringTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _performRealTimeCheck(),
      );

      // 성능 메트릭 수집 (1분마다)
      _performanceCheckTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _collectPerformanceMetrics(),
      );

      // 보안 스캔 (5분마다)
      _securityScanTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _performSecurityScan(),
      );

      // 초기 데이터 로드
      await _loadInitialData();
    } catch (e) {
      print('❌ 모니터링 서비스 시작 실패: $e');
      _isMonitoring = false;
      rethrow;
    }
  }

  // 모니터링 중지
  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    print('🛑 모니터링 서비스 중지');

    _realTimeMonitoringTimer?.cancel();
    _performanceCheckTimer?.cancel();
    _securityScanTimer?.cancel();
    _realTimeMonitoringTimer = null;
    _performanceCheckTimer = null;
    _securityScanTimer = null;
  }

  // 초기 데이터 로드
  Future<void> _loadInitialData() async {
    try {
      // 최근 시스템 이벤트 로드
      final eventsResponse = await _supabase
          .from('system_events')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      _recentEvents.clear();
      for (var event in eventsResponse) {
        _recentEvents.add(SystemEvent.fromMap(event));
      }

      // 활성 보안 경고 로드
      final alertsResponse = await _supabase
          .from('security_alerts')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      _activeAlerts.clear();
      for (var alert in alertsResponse) {
        _activeAlerts.add(SecurityAlert.fromMap(alert));
      }
    } catch (e) {
      print('❌ 초기 데이터 로드 실패: $e');
    }
  }

  // 실시간 체크
  Future<void> _performRealTimeCheck() async {
    try {
      // 현재 활성 사용자 수 확인
      final activeUsersCount = await _getActiveUsersCount();

      // 시스템 리소스 사용량 시뮬레이션 (실제 환경에서는 실제 메트릭 수집)
      final cpuUsage = _generateRealisticMetric('cpu', 0, 100);
      final memoryUsage = _generateRealisticMetric('memory', 0, 100);
      final diskUsage = _generateRealisticMetric('disk', 0, 100);

      // 응답 시간 확인
      final responseTime = await _measureResponseTime();

      // 에러율 계산
      final errorRate = await _calculateErrorRate();

      // 메트릭 캐시 업데이트
      _cachedMetrics.addAll({
        'active_users': activeUsersCount,
        'cpu_usage': cpuUsage,
        'memory_usage': memoryUsage,
        'disk_usage': diskUsage,
        'response_time': responseTime,
        'error_rate': errorRate,
        'last_update': DateTime.now().toIso8601String(),
      });

      // 임계값 확인 및 이벤트 생성
      await _checkThresholds();

      // 성능 메트릭 스트림으로 전송
      _performanceMetricController.add(
        PerformanceMetric(
          timestamp: DateTime.now(),
          cpuUsage: cpuUsage,
          memoryUsage: memoryUsage,
          diskUsage: diskUsage,
          responseTime: responseTime,
          errorRate: errorRate,
          activeUsers: activeUsersCount,
        ),
      );
    } catch (e) {
      print('❌ 실시간 체크 실패: $e');
    }
  }

  // 성능 메트릭 수집
  Future<void> _collectPerformanceMetrics() async {
    try {
      // 데이터베이스 성능 메트릭
      final dbMetrics = await _collectDatabaseMetrics();

      // API 성능 메트릭
      final apiMetrics = await _collectApiMetrics();

      // 사용자 세션 메트릭
      final sessionMetrics = await _collectSessionMetrics();

      // 메트릭 저장
      await _saveMetrics({
        'database': dbMetrics,
        'api': apiMetrics,
        'sessions': sessionMetrics,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ 성능 메트릭 수집 실패: $e');
    }
  }

  // 보안 스캔
  Future<void> _performSecurityScan() async {
    try {
      // 의심스러운 로그인 시도 확인
      await _checkSuspiciousLogins();

      // 비정상적인 사용자 활동 감지
      await _detectAnomalousActivity();

      // 실패한 거래 패턴 분석
      await _analyzeFailedTransactions();

      // IP 기반 위험 분석
      await _analyzeIpRisks();
    } catch (e) {
      print('❌ 보안 스캔 실패: $e');
    }
  }

  // 활성 사용자 수 조회
  Future<int> _getActiveUsersCount() async {
    try {
      final response = await _supabase
          .from('user_sessions')
          .select('user_id')
          .gte(
            'last_activity',
            DateTime.now()
                .subtract(const Duration(minutes: 30))
                .toIso8601String(),
          );

      return response.length;
    } catch (e) {
      print('❌ 활성 사용자 수 조회 실패: $e');
      return 0;
    }
  }

  // 응답 시간 측정
  Future<double> _measureResponseTime() async {
    try {
      final stopwatch = Stopwatch()..start();

      await _supabase.from('products').select('id').limit(1);

      stopwatch.stop();
      return stopwatch.elapsedMilliseconds.toDouble();
    } catch (e) {
      print('❌ 응답 시간 측정 실패: $e');
      return 0.0;
    }
  }

  // 에러율 계산
  Future<double> _calculateErrorRate() async {
    try {
      final totalRequests = await _supabase
          .from('api_logs')
          .select('id')
          .gte(
            'created_at',
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          );

      final errorRequests = await _supabase
          .from('api_logs')
          .select('id')
          .gte(
            'created_at',
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          )
          .gte('status_code', 400);

      if (totalRequests.isEmpty) return 0.0;

      return (errorRequests.length / totalRequests.length) * 100;
    } catch (e) {
      print('❌ 에러율 계산 실패: $e');
      return 0.0;
    }
  }

  // 임계값 확인
  Future<void> _checkThresholds() async {
    for (var entry in _cachedMetrics.entries) {
      final key = entry.key;
      final value = entry.value;

      if (_thresholds.containsKey(key) && value is num) {
        final threshold = _thresholds[key];

        if (value > threshold) {
          await _createSystemEvent(
            type: 'threshold_exceeded',
            severity: 'warning',
            message: '$key 임계값 초과: $value (임계값: $threshold)',
            metadata: {'metric': key, 'value': value, 'threshold': threshold},
          );
        }
      }
    }
  }

  // 의심스러운 로그인 확인
  Future<void> _checkSuspiciousLogins() async {
    try {
      // 1시간 내 실패한 로그인 시도가 많은 IP 확인
      final suspiciousIps = await _supabase
          .from('auth_logs')
          .select('ip_address')
          .eq('success', false)
          .gte(
            'created_at',
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          );

      final ipCounts = <String, int>{};
      for (var log in suspiciousIps) {
        final ip = log['ip_address'] as String;
        ipCounts[ip] = (ipCounts[ip] ?? 0) + 1;
      }

      for (var entry in ipCounts.entries) {
        if (entry.value >= _thresholds['failed_login_attempts']) {
          await _createSecurityAlert(
            type: 'suspicious_login_attempts',
            severity: 'high',
            message: 'IP ${entry.key}에서 ${entry.value}회의 로그인 실패',
            metadata: {'ip_address': entry.key, 'attempt_count': entry.value},
          );
        }
      }
    } catch (e) {
      print('❌ 의심스러운 로그인 확인 실패: $e');
    }
  }

  // 비정상적인 활동 감지
  Future<void> _detectAnomalousActivity() async {
    try {
      // 짧은 시간 내 많은 거래 시도
      final recentTransactions = await _supabase
          .from('transactions')
          .select('user_id, created_at')
          .gte(
            'created_at',
            DateTime.now()
                .subtract(const Duration(minutes: 30))
                .toIso8601String(),
          );

      final userTransactionCounts = <String, int>{};
      for (var transaction in recentTransactions) {
        final userId = transaction['user_id'] as String;
        userTransactionCounts[userId] =
            (userTransactionCounts[userId] ?? 0) + 1;
      }

      for (var entry in userTransactionCounts.entries) {
        if (entry.value > 10) {
          // 30분 내 10회 이상 거래
          await _createSecurityAlert(
            type: 'anomalous_user_activity',
            severity: 'medium',
            message: '사용자 ${entry.key}의 비정상적인 거래 활동 감지',
            metadata: {'user_id': entry.key, 'transaction_count': entry.value},
          );
        }
      }
    } catch (e) {
      print('❌ 비정상적인 활동 감지 실패: $e');
    }
  }

  // 실패한 거래 패턴 분석
  Future<void> _analyzeFailedTransactions() async {
    try {
      final failedTransactions = await _supabase
          .from('transactions')
          .select('*')
          .eq('status', 'failed')
          .gte(
            'created_at',
            DateTime.now()
                .subtract(const Duration(hours: 24))
                .toIso8601String(),
          );

      if (failedTransactions.length > 50) {
        // 24시간 내 50건 이상 실패
        await _createSystemEvent(
          type: 'high_failure_rate',
          severity: 'critical',
          message: '24시간 내 ${failedTransactions.length}건의 거래 실패',
          metadata: {'failed_count': failedTransactions.length},
        );
      }
    } catch (e) {
      print('❌ 실패한 거래 패턴 분석 실패: $e');
    }
  }

  // IP 위험도 분석
  Future<void> _analyzeIpRisks() async {
    try {
      // 여러 계정에서 접근하는 IP 확인
      final recentSessions = await _supabase
          .from('user_sessions')
          .select('ip_address, user_id')
          .gte(
            'created_at',
            DateTime.now()
                .subtract(const Duration(hours: 24))
                .toIso8601String(),
          );

      final ipUserCounts = <String, Set<String>>{};
      for (var session in recentSessions) {
        final ip = session['ip_address'] as String;
        final userId = session['user_id'] as String;

        ipUserCounts[ip] ??= <String>{};
        ipUserCounts[ip]!.add(userId);
      }

      for (var entry in ipUserCounts.entries) {
        if (entry.value.length > 10) {
          // 하나의 IP에서 10개 이상 계정 접근
          await _createSecurityAlert(
            type: 'multiple_accounts_per_ip',
            severity: 'medium',
            message: 'IP ${entry.key}에서 ${entry.value.length}개 계정 접근',
            metadata: {
              'ip_address': entry.key,
              'account_count': entry.value.length,
            },
          );
        }
      }
    } catch (e) {
      print('❌ IP 위험도 분석 실패: $e');
    }
  }

  // 시스템 이벤트 생성
  Future<void> _createSystemEvent({
    required String type,
    required String severity,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final event = SystemEvent(
        id: _generateId(),
        type: type,
        severity: severity,
        message: message,
        metadata: metadata ?? {},
        timestamp: DateTime.now(),
      );

      // 데이터베이스에 저장
      await _supabase.from('system_events').insert(event.toMap());

      // 로컬 캐시에 추가
      _recentEvents.insert(0, event);
      if (_recentEvents.length > 100) {
        _recentEvents.removeLast();
      }

      // 스트림으로 전송
      _systemEventController.add(event);

      print('📊 시스템 이벤트 생성: $type - $message');
    } catch (e) {
      print('❌ 시스템 이벤트 생성 실패: $e');
    }
  }

  // 보안 경고 생성
  Future<void> _createSecurityAlert({
    required String type,
    required String severity,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final alert = SecurityAlert(
        id: _generateId(),
        type: type,
        severity: severity,
        message: message,
        metadata: metadata ?? {},
        status: 'active',
        timestamp: DateTime.now(),
      );

      // 데이터베이스에 저장
      await _supabase.from('security_alerts').insert(alert.toMap());

      // 로컬 캐시에 추가
      _activeAlerts.insert(0, alert);

      // 스트림으로 전송
      _securityAlertController.add(alert);

      print('🚨 보안 경고 생성: $type - $message');
    } catch (e) {
      print('❌ 보안 경고 생성 실패: $e');
    }
  }

  // 데이터베이스 메트릭 수집
  Future<Map<String, dynamic>> _collectDatabaseMetrics() async {
    try {
      // 쿼리 성능 메트릭 시뮬레이션
      return {
        'connection_count': _generateRealisticMetric('db_connections', 0, 100),
        'query_time_avg': _generateRealisticMetric('query_time', 10, 1000),
        'active_queries': _generateRealisticMetric('active_queries', 0, 50),
        'cache_hit_ratio': _generateRealisticMetric('cache_hit', 70, 99),
      };
    } catch (e) {
      print('❌ 데이터베이스 메트릭 수집 실패: $e');
      return {};
    }
  }

  // API 메트릭 수집
  Future<Map<String, dynamic>> _collectApiMetrics() async {
    try {
      return {
        'requests_per_minute': _generateRealisticMetric(
          'api_requests',
          50,
          500,
        ),
        'avg_response_time': _generateRealisticMetric(
          'api_response',
          100,
          2000,
        ),
        'success_rate': _generateRealisticMetric('api_success', 90, 99.9),
        'concurrent_connections': _generateRealisticMetric(
          'api_connections',
          10,
          200,
        ),
      };
    } catch (e) {
      print('❌ API 메트릭 수집 실패: $e');
      return {};
    }
  }

  // 세션 메트릭 수집
  Future<Map<String, dynamic>> _collectSessionMetrics() async {
    try {
      final activeSessions = await _getActiveUsersCount();

      return {
        'active_sessions': activeSessions,
        'avg_session_duration': _generateRealisticMetric(
          'session_duration',
          300,
          3600,
        ),
        'new_sessions_per_hour': _generateRealisticMetric(
          'new_sessions',
          10,
          100,
        ),
        'bounce_rate': _generateRealisticMetric('bounce_rate', 20, 80),
      };
    } catch (e) {
      print('❌ 세션 메트릭 수집 실패: $e');
      return {};
    }
  }

  // 메트릭 저장
  Future<void> _saveMetrics(Map<String, dynamic> metrics) async {
    try {
      await _supabase.from('performance_metrics').insert({
        'id': _generateId(),
        'metrics': jsonEncode(metrics),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ 메트릭 저장 실패: $e');
    }
  }

  // 현재 시스템 상태 조회
  Map<String, dynamic> getSystemStatus() {
    return {
      'status': _determineSystemStatus(),
      'metrics': Map.from(_cachedMetrics),
      'recent_events': _recentEvents.take(10).map((e) => e.toMap()).toList(),
      'active_alerts': _activeAlerts.take(5).map((a) => a.toMap()).toList(),
      'last_update':
          _cachedMetrics['last_update'] ?? DateTime.now().toIso8601String(),
    };
  }

  // 시스템 상태 판단
  String _determineSystemStatus() {
    final cpuUsage = _cachedMetrics['cpu_usage'] ?? 0;
    final memoryUsage = _cachedMetrics['memory_usage'] ?? 0;
    final errorRate = _cachedMetrics['error_rate'] ?? 0;

    if (cpuUsage > 90 || memoryUsage > 90 || errorRate > 10) {
      return 'critical';
    } else if (cpuUsage > 80 || memoryUsage > 80 || errorRate > 5) {
      return 'warning';
    } else {
      return 'healthy';
    }
  }

  // 실제적인 메트릭 생성 (시뮬레이션)
  double _generateRealisticMetric(String type, double min, double max) {
    final random = math.Random();
    final baseValue = min + (max - min) * random.nextDouble();

    // 시간대별 패턴 적용
    final hour = DateTime.now().hour;
    double multiplier = 1.0;

    if (hour >= 9 && hour <= 18) {
      // 업무시간: 더 높은 사용량
      multiplier = 1.2;
    } else if (hour >= 22 || hour <= 6) {
      // 야간시간: 낮은 사용량
      multiplier = 0.7;
    }

    return (baseValue * multiplier).clamp(min, max);
  }

  // ID 생성
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        math.Random().nextInt(10000).toString().padLeft(4, '0');
  }

  // 리소스 정리
  void dispose() {
    stopMonitoring();
    _systemEventController.close();
    _securityAlertController.close();
    _performanceMetricController.close();
    _userActivityController.close();
  }
}

// 시스템 이벤트 모델
class SystemEvent {
  final String id;
  final String type;
  final String severity;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  SystemEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.metadata,
    required this.timestamp,
  });

  factory SystemEvent.fromMap(Map<String, dynamic> map) {
    return SystemEvent(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      severity: map['severity'] ?? '',
      message: map['message'] ?? '',
      metadata: map['metadata'] is String
          ? jsonDecode(map['metadata'])
          : map['metadata'] ?? {},
      timestamp: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'severity': severity,
      'message': message,
      'metadata': jsonEncode(metadata),
      'created_at': timestamp.toIso8601String(),
    };
  }
}

// 보안 경고 모델
class SecurityAlert {
  final String id;
  final String type;
  final String severity;
  final String message;
  final Map<String, dynamic> metadata;
  final String status;
  final DateTime timestamp;

  SecurityAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.metadata,
    required this.status,
    required this.timestamp,
  });

  factory SecurityAlert.fromMap(Map<String, dynamic> map) {
    return SecurityAlert(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      severity: map['severity'] ?? '',
      message: map['message'] ?? '',
      metadata: map['metadata'] is String
          ? jsonDecode(map['metadata'])
          : map['metadata'] ?? {},
      status: map['status'] ?? '',
      timestamp: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'severity': severity,
      'message': message,
      'metadata': jsonEncode(metadata),
      'status': status,
      'created_at': timestamp.toIso8601String(),
    };
  }
}

// 성능 메트릭 모델
class PerformanceMetric {
  final DateTime timestamp;
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;
  final double responseTime;
  final double errorRate;
  final int activeUsers;

  PerformanceMetric({
    required this.timestamp,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
    required this.responseTime,
    required this.errorRate,
    required this.activeUsers,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'disk_usage': diskUsage,
      'response_time': responseTime,
      'error_rate': errorRate,
      'active_users': activeUsers,
    };
  }
}

// 사용자 활동 모델
class UserActivity {
  final String id;
  final String userId;
  final String action;
  final String? targetId;
  final String? targetType;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  UserActivity({
    required this.id,
    required this.userId,
    required this.action,
    this.targetId,
    this.targetType,
    required this.metadata,
    required this.timestamp,
  });

  factory UserActivity.fromMap(Map<String, dynamic> map) {
    return UserActivity(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      action: map['action'] ?? '',
      targetId: map['target_id'],
      targetType: map['target_type'],
      metadata: map['metadata'] is String
          ? jsonDecode(map['metadata'])
          : map['metadata'] ?? {},
      timestamp: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'target_id': targetId,
      'target_type': targetType,
      'metadata': jsonEncode(metadata),
      'created_at': timestamp.toIso8601String(),
    };
  }
}
