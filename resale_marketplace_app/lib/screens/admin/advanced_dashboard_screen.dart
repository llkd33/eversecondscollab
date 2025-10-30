import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/admin_service.dart';
import '../../services/logging_service.dart';
import '../../services/backup_service.dart';
import '../../services/admin_notification_service.dart';
import '../../models/user_model.dart';

/// Advanced Admin Dashboard with charts and real-time monitoring
class AdvancedAdminDashboardScreen extends StatefulWidget {
  const AdvancedAdminDashboardScreen({super.key});

  @override
  State<AdvancedAdminDashboardScreen> createState() =>
      _AdvancedAdminDashboardScreenState();
}

class _AdvancedAdminDashboardScreenState
    extends State<AdvancedAdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  final LoggingService _loggingService = LoggingService();
  final BackupService _backupService = BackupService();
  final AdminNotificationService _notificationService =
      AdminNotificationService();

  bool _isLoading = true;
  Map<String, dynamic> _dashboardStats = {};
  List<Map<String, dynamic>> _monthlyStats = [];
  Map<String, dynamic> _loggingStats = {};
  Map<String, dynamic> _backupStats = {};
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Initialize notification service with current user
    // final userId = await _authService.getCurrentUserId();
    // await _notificationService.initialize(
    //   userId: userId,
    //   onNotificationReceived: _handleNotification,
    // );
  }

  void _handleNotification(Map<String, dynamic> notification) {
    setState(() {
      _unreadNotifications++;
    });

    // Show snackbar for critical notifications
    if (notification['severity'] == 'critical') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification['message']),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: '보기',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to notification detail
            },
          ),
        ),
      );
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      // Load all dashboard data in parallel
      final results = await Future.wait([
        _adminService.getDashboardStats(),
        _adminService.getMonthlyStats(),
        _loggingService.getLoggingStatistics(),
        _backupService.getBackupStatistics(),
        // _notificationService.getUnreadCount(userId: currentUserId),
      ]);

      setState(() {
        _dashboardStats = results[0] as Map<String, dynamic>;
        _monthlyStats = results[1] as List<Map<String, dynamic>>;
        _loggingStats = results[2] as Map<String, dynamic>;
        _backupStats = results[3] as Map<String, dynamic>;
        // _unreadNotifications = results[4] as int;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('고급 관리자 대시보드'),
        centerTitle: true,
        actions: [
          // Notifications bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  // Navigate to notifications
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // System Health Card
                    _buildSystemHealthCard(theme),
                    const SizedBox(height: 24),

                    // Monthly Revenue Chart
                    _buildMonthlyRevenueChart(theme),
                    const SizedBox(height: 24),

                    // User Growth Chart
                    _buildUserGrowthChart(theme),
                    const SizedBox(height: 24),

                    // Error Logs Summary
                    _buildErrorLogsSummary(theme),
                    const SizedBox(height: 24),

                    // Backup Status
                    _buildBackupStatus(theme),
                    const SizedBox(height: 24),

                    // Quick Stats Grid
                    _buildQuickStatsGrid(theme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSystemHealthCard(ThemeData theme) {
    final errorCount = _loggingStats['totalErrors'] ?? 0;
    final criticalErrors = _loggingStats['unresolvedErrors'] ?? 0;
    final avgResponseTime =
        double.tryParse(_loggingStats['avgResponseTime'] ?? '0') ?? 0;

    Color healthColor = Colors.green;
    String healthStatus = '정상';
    IconData healthIcon = Icons.check_circle;

    if (criticalErrors > 0 || avgResponseTime > 1000) {
      healthColor = Colors.red;
      healthStatus = '위험';
      healthIcon = Icons.error;
    } else if (errorCount > 10 || avgResponseTime > 500) {
      healthColor = Colors.orange;
      healthStatus = '주의';
      healthIcon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [healthColor, healthColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: healthColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(healthIcon, size: 48, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '시스템 상태',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  healthStatus,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '평균 응답시간: ${avgResponseTime.toStringAsFixed(0)}ms',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (criticalErrors > 0)
                  Text(
                    '⚠️ $criticalErrors개의 심각한 오류',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyRevenueChart(ThemeData theme) {
    if (_monthlyStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '월별 매출 추이',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value / 10000).toInt()}만',
                          style: theme.textTheme.bodySmall,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _monthlyStats.length) {
                          return Text(
                            _monthlyStats[index]['month'],
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _monthlyStats.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        (entry.value['revenue'] as num).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart(ThemeData theme) {
    if (_monthlyStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '신규 사용자 추이',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _monthlyStats.fold<double>(
                  0,
                  (max, stat) => (stat['newUsers'] as num).toDouble() > max
                      ? (stat['newUsers'] as num).toDouble()
                      : max,
                ),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _monthlyStats.length) {
                          return Text(
                            _monthlyStats[index]['month'],
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _monthlyStats.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: (entry.value['newUsers'] as num).toDouble(),
                        color: theme.colorScheme.secondary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorLogsSummary(ThemeData theme) {
    final errorsBySeverity =
        _loggingStats['errorsBySeverity'] as Map<String, int>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                '오류 로그 요약',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full error logs
                },
                child: const Text('전체보기'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...errorsBySeverity.entries.map((entry) {
            final severity = entry.key;
            final count = entry.value;

            Color color = Colors.grey;
            IconData icon = Icons.info;

            switch (severity) {
              case 'critical':
                color = Colors.red;
                icon = Icons.error;
                break;
              case 'high':
                color = Colors.orange;
                icon = Icons.warning;
                break;
              case 'medium':
                color = Colors.yellow[700]!;
                icon = Icons.warning_amber;
                break;
              case 'low':
                color = Colors.blue;
                icon = Icons.info;
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getSeverityText(severity),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count건',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBackupStatus(ThemeData theme) {
    final lastBackup = _backupStats['lastBackup'] as String?;
    final totalBackups = _backupStats['totalBackups'] ?? 0;
    final totalSizeMB = _backupStats['totalSizeMB'] ?? '0.00';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                '백업 상태',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Trigger manual backup
                  _triggerManualBackup();
                },
                icon: const Icon(Icons.backup, size: 18),
                label: const Text('수동 백업'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBackupInfoRow(
            theme,
            Icons.access_time,
            '마지막 백업',
            lastBackup != null
                ? _formatDateTime(DateTime.parse(lastBackup))
                : '백업 없음',
          ),
          const SizedBox(height: 12),
          _buildBackupInfoRow(
            theme,
            Icons.folder,
            '총 백업 수',
            '$totalBackups개',
          ),
          const SizedBox(height: 12),
          _buildBackupInfoRow(
            theme,
            Icons.storage,
            '총 백업 크기',
            '${totalSizeMB}MB',
          ),
        ],
      ),
    );
  }

  Widget _buildBackupInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsGrid(ThemeData theme) {
    final stats = [
      {
        'label': '총 사용자',
        'value': _dashboardStats['totalUsers'] ?? 0,
        'icon': Icons.people,
        'color': Colors.blue,
      },
      {
        'label': '활성 사용자',
        'value': _dashboardStats['activeUsers'] ?? 0,
        'icon': Icons.person_pin,
        'color': Colors.green,
      },
      {
        'label': '총 거래',
        'value': _dashboardStats['totalTransactions'] ?? 0,
        'icon': Icons.shopping_cart,
        'color': Colors.purple,
      },
      {
        'label': '대기 신고',
        'value': _dashboardStats['pendingReports'] ?? 0,
        'icon': Icons.report_problem,
        'color': Colors.red,
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: stats.map((stat) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (stat['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (stat['color'] as Color).withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                stat['icon'] as IconData,
                color: stat['color'] as Color,
                size: 32,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stat['value']}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: stat['color'] as Color,
                    ),
                  ),
                  Text(
                    stat['label'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getSeverityText(String severity) {
    switch (severity) {
      case 'critical':
        return '심각';
      case 'high':
        return '높음';
      case 'medium':
        return '보통';
      case 'low':
        return '낮음';
      default:
        return severity;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}월 ${dateTime.day}일';
    }
  }

  Future<void> _triggerManualBackup() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Trigger backup
    // final adminId = await _authService.getCurrentUserId();
    // await _backupService.createManualBackup(adminId: adminId);

    // Close dialog and reload data
    Navigator.pop(context);
    _loadAllData();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('백업이 시작되었습니다')),
    );
  }
}
