import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/admin/monitoring_service.dart';

// 통계 카드 위젯
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final double change;
  final IconData icon;
  final Color color;
  final List<double>? trend;

  const StatsCard({
    Key? key,
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
    this.trend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    final isPositive = change >= 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Container(
        padding: EdgeInsets.all(responsive.isMobile ? AppTheme.spacingMd : AppTheme.spacingLg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: responsive.isMobile ? 24 : 28,
                ),
                if (trend != null)
                  SizedBox(
                    width: 60,
                    height: 30,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: trend!.length.toDouble() - 1,
                        minY: trend!.reduce((a, b) => a < b ? a : b),
                        maxY: trend!.reduce((a, b) => a > b ? a : b),
                        lineBarsData: [
                          LineChartBarData(
                            spots: trend!.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), e.value);
                            }).toList(),
                            isCurved: true,
                            color: color,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: color.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: responsive.isMobile ? 8 : 12),
            
            Text(
              title,
              style: AppStyles.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontSize: responsive.isMobile ? 12 : 14,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              value,
              style: AppStyles.headingMedium.copyWith(
                fontSize: responsive.isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                  style: AppStyles.bodySmall.copyWith(
                    color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '전일 대비',
                  style: AppStyles.bodySmall.copyWith(
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 실시간 사용자 활동 위젯
class RealTimeUserActivity extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final bool isLoading;

  const RealTimeUserActivity({
    Key? key,
    required this.data,
    required this.isLoading,
  }) : super(key: key);

  @override
  State<RealTimeUserActivity> createState() => _RealTimeUserActivityState();
}

class _RealTimeUserActivityState extends State<RealTimeUserActivity>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '실시간 사용자 활동',
                  style: AppStyles.headingSmall,
                ),
                if (widget.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMd),
            
            if (widget.data.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingXl),
                  child: Text(
                    '활동 데이터가 없습니다.',
                    style: AppStyles.bodyMedium,
                  ),
                ),
              )
            else
              FadeTransition(
                opacity: _fadeAnimation,
                child: SizedBox(
                  height: 200,
                  child: ListView.separated(
                    itemCount: widget.data.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final activity = widget.data[index];
                      return _buildActivityItem(activity);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _getActivityColor(activity['type']),
            child: Icon(
              _getActivityIcon(activity['type']),
              size: 16,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['description'] ?? '알 수 없는 활동',
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  activity['user'] ?? '익명',
                  style: AppStyles.bodySmall.copyWith(
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ),
          
          Text(
            _formatTimestamp(activity['timestamp']),
            style: AppStyles.bodySmall.copyWith(
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(String? type) {
    switch (type) {
      case 'login':
        return AppTheme.successColor;
      case 'purchase':
        return AppTheme.primaryColor;
      case 'product_view':
        return AppTheme.secondaryColor;
      case 'transaction':
        return AppTheme.accentColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'login':
        return Icons.login;
      case 'purchase':
        return Icons.shopping_cart;
      case 'product_view':
        return Icons.visibility;
      case 'transaction':
        return Icons.swap_horiz;
      default:
        return Icons.info;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      final time = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(time);
      
      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else {
        return '${difference.inDays}일 전';
      }
    } catch (e) {
      return '';
    }
  }
}

// 최근 거래 목록 위젯
class RecentTransactionsList extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final Function(Map<String, dynamic>) onTransactionTap;

  const RecentTransactionsList({
    Key? key,
    required this.transactions,
    required this.onTransactionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '최근 거래',
                  style: AppStyles.headingSmall,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin/transactions');
                  },
                  child: const Text('전체 보기'),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMd),
            
            if (transactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingXl),
                  child: Text(
                    '최근 거래가 없습니다.',
                    style: AppStyles.bodyMedium,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.take(5).length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _buildTransactionItem(transaction);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(transaction['status']),
        child: Icon(
          _getStatusIcon(transaction['status']),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        transaction['product_name'] ?? '알 수 없는 상품',
        style: AppStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${transaction['buyer_name']} → ${transaction['seller_name']}',
        style: AppStyles.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₩${_formatAmount(transaction['amount'])}',
            style: AppStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.accentColor,
            ),
          ),
          Text(
            _formatStatus(transaction['status']),
            style: AppStyles.bodySmall.copyWith(
              color: _getStatusColor(transaction['status']),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      onTap: () => onTransactionTap(transaction),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'failed':
        return AppTheme.errorColor;
      case 'processing':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'failed':
        return Icons.error;
      case 'processing':
        return Icons.sync;
      default:
        return Icons.help;
    }
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'completed':
        return '완료';
      case 'pending':
        return '대기';
      case 'failed':
        return '실패';
      case 'processing':
        return '처리중';
      default:
        return '알 수 없음';
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

// 시스템 상태 카드
class SystemStatusCard extends StatelessWidget {
  final Map<String, dynamic> systemHealth;
  final Map<String, dynamic> serverStatus;
  final Map<String, dynamic> databaseStatus;

  const SystemStatusCard({
    Key? key,
    required this.systemHealth,
    required this.serverStatus,
    required this.databaseStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '시스템 상태',
              style: AppStyles.headingSmall,
            ),
            
            const SizedBox(height: AppTheme.spacingMd),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    '서버',
                    serverStatus['status'] ?? 'unknown',
                    Icons.dns,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '데이터베이스',
                    databaseStatus['status'] ?? 'unknown',
                    Icons.storage,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '전체',
                    systemHealth['overall'] ?? 'unknown',
                    Icons.health_and_safety,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMd),
            
            _buildMetricsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, String status, IconData icon) {
    final color = _getStatusColor(status);
    
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          title,
          style: AppStyles.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          ),
          child: Text(
            _formatStatus(status),
            style: AppStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMetricItem(
          'CPU',
          '${systemHealth['cpu_usage']?.toStringAsFixed(1) ?? '0'}%',
        ),
        _buildMetricItem(
          'Memory',
          '${systemHealth['memory_usage']?.toStringAsFixed(1) ?? '0'}%',
        ),
        _buildMetricItem(
          'Disk',
          '${systemHealth['disk_usage']?.toStringAsFixed(1) ?? '0'}%',
        ),
        _buildMetricItem(
          'Response',
          '${systemHealth['response_time']?.toStringAsFixed(0) ?? '0'}ms',
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppStyles.bodySmall.copyWith(
            color: AppTheme.textHint,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
      case 'online':
      case 'good':
        return AppTheme.successColor;
      case 'warning':
      case 'slow':
        return AppTheme.warningColor;
      case 'critical':
      case 'offline':
      case 'error':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return '정상';
      case 'warning':
        return '주의';
      case 'critical':
        return '위험';
      case 'online':
        return '온라인';
      case 'offline':
        return '오프라인';
      default:
        return status;
    }
  }
}

// 매출 차트 위젯
class RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String period;
  final bool isLoading;

  const RevenueChart({
    Key? key,
    required this.data,
    required this.period,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '매출 추이 ($period)',
                  style: AppStyles.headingSmall,
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingLg),
            
            SizedBox(
              height: 200,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : data.isEmpty
                      ? const Center(
                          child: Text(
                            '데이터가 없습니다.',
                            style: AppStyles.bodyMedium,
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: AppTheme.dividerColor,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${(value / 1000).toStringAsFixed(0)}K',
                                      style: AppStyles.bodySmall,
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < data.length) {
                                      return Text(
                                        data[value.toInt()]['label'] ?? '',
                                        style: AppStyles.bodySmall,
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                color: AppTheme.dividerColor,
                                width: 1,
                              ),
                            ),
                            minX: 0,
                            maxX: data.length.toDouble() - 1,
                            minY: 0,
                            maxY: data.isEmpty
                                ? 100
                                : data
                                    .map((e) => (e['value'] as num).toDouble())
                                    .reduce((a, b) => a > b ? a : b) *
                                1.2,
                            lineBarsData: [
                              LineChartBarData(
                                spots: data.asMap().entries.map((e) {
                                  return FlSpot(
                                    e.key.toDouble(),
                                    (e.value['value'] as num).toDouble(),
                                  );
                                }).toList(),
                                isCurved: true,
                                color: AppTheme.accentColor,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: AppTheme.accentColor,
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppTheme.accentColor.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// 사용자 증가 차트 위젯
class UserGrowthChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String period;
  final bool isLoading;

  const UserGrowthChart({
    Key? key,
    required this.data,
    required this.period,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '사용자 증가 ($period)',
              style: AppStyles.headingSmall,
            ),
            
            const SizedBox(height: AppTheme.spacingLg),
            
            SizedBox(
              height: 200,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : data.isEmpty
                      ? const Center(
                          child: Text(
                            '데이터가 없습니다.',
                            style: AppStyles.bodyMedium,
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: data.isEmpty
                                ? 100
                                : data
                                    .map((e) => (e['value'] as num).toDouble())
                                    .reduce((a, b) => a > b ? a : b) *
                                1.2,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                tooltipBgColor: AppTheme.textPrimary,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '${data[groupIndex]['label']}\n${rod.toY.round()}명',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < data.length) {
                                      return Text(
                                        data[value.toInt()]['label'] ?? '',
                                        style: AppStyles.bodySmall,
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: AppStyles.bodySmall,
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: data.asMap().entries.map((e) {
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: (e.value['value'] as num).toDouble(),
                                    color: AppTheme.primaryColor,
                                    width: 16,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: AppTheme.dividerColor,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// 카테고리별 분포 차트
class CategoryDistributionChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool isLoading;

  const CategoryDistributionChart({
    Key? key,
    required this.data,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '카테고리별 판매 분포',
              style: AppStyles.headingSmall,
            ),
            
            const SizedBox(height: AppTheme.spacingLg),
            
            SizedBox(
              height: 250,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : data.isEmpty
                      ? const Center(
                          child: Text(
                            '데이터가 없습니다.',
                            style: AppStyles.bodyMedium,
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: PieChart(
                                PieChartData(
                                  sections: data.asMap().entries.map((e) {
                                    final colors = [
                                      AppTheme.primaryColor,
                                      AppTheme.secondaryColor,
                                      AppTheme.accentColor,
                                      AppTheme.successColor,
                                      AppTheme.warningColor,
                                    ];
                                    
                                    return PieChartSectionData(
                                      value: (e.value['value'] as num).toDouble(),
                                      title: '${(e.value['percentage'] as num).toStringAsFixed(1)}%',
                                      color: colors[e.key % colors.length],
                                      radius: 60,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                  centerSpaceRadius: 40,
                                  sectionsSpace: 2,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: AppTheme.spacingMd),
                            
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: data.asMap().entries.map((e) {
                                  final colors = [
                                    AppTheme.primaryColor,
                                    AppTheme.secondaryColor,
                                    AppTheme.accentColor,
                                    AppTheme.successColor,
                                    AppTheme.warningColor,
                                  ];
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: colors[e.key % colors.length],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            e.value['category'] ?? '',
                                            style: AppStyles.bodySmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// 활동 로그 위젯
class ActivityLogWidget extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final Function(Map<String, dynamic>) onActivityTap;
  final bool isLoading;

  const ActivityLogWidget({
    Key? key,
    required this.activities,
    required this.onActivityTap,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '시스템 활동 로그',
              style: AppStyles.headingSmall,
            ),
            
            const SizedBox(height: AppTheme.spacingMd),
            
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingXl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (activities.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingXl),
                  child: Text(
                    '활동 로그가 없습니다.',
                    style: AppStyles.bodyMedium,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _buildActivityItem(activity);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _getSeverityColor(activity['severity']),
        child: Icon(
          _getSeverityIcon(activity['severity']),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        activity['message'] ?? '알 수 없는 활동',
        style: AppStyles.bodyMedium,
      ),
      subtitle: Text(
        '${activity['user'] ?? '시스템'} • ${_formatTimestamp(activity['timestamp'])}',
        style: AppStyles.bodySmall,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getSeverityColor(activity['severity']).withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        ),
        child: Text(
          _formatSeverity(activity['severity']),
          style: AppStyles.bodySmall.copyWith(
            color: _getSeverityColor(activity['severity']),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: () => onActivityTap(activity),
    );
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return AppTheme.errorColor;
      case 'warning':
        return AppTheme.warningColor;
      case 'info':
        return AppTheme.infoColor;
      case 'success':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getSeverityIcon(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.circle;
    }
  }

  String _formatSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return '심각';
      case 'warning':
        return '경고';
      case 'info':
        return '정보';
      case 'success':
        return '성공';
      default:
        return '기타';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      final time = DateTime.parse(timestamp.toString());
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

// 알림 센터 위젯
class NotificationCenterWidget extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final Function(Map<String, dynamic>) onNotificationTap;
  final Function(Map<String, dynamic>) onMarkAsRead;
  final VoidCallback onMarkAllAsRead;
  final bool isLoading;
  final ScrollController? scrollController;

  const NotificationCenterWidget({
    Key? key,
    required this.notifications,
    required this.onNotificationTap,
    required this.onMarkAsRead,
    required this.onMarkAllAsRead,
    required this.isLoading,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingXl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none,
                size: 64,
                color: AppTheme.textHint,
              ),
              SizedBox(height: AppTheme.spacingMd),
              Text(
                '알림이 없습니다.',
                style: AppStyles.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isUnread = !(notification['is_read'] ?? false);
    
    return Container(
      color: isUnread ? AppTheme.primaryColor.withOpacity(0.05) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification['type']),
          child: Icon(
            _getNotificationIcon(notification['type']),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification['title'] ?? '알림',
          style: AppStyles.bodyMedium.copyWith(
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'] ?? '',
              style: AppStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification['timestamp']),
              style: AppStyles.bodySmall.copyWith(
                color: AppTheme.textHint,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            IconButton(
              icon: Icon(
                isUnread ? Icons.mark_email_read : Icons.mark_email_read_outlined,
                size: 20,
              ),
              onPressed: () => onMarkAsRead(notification),
            ),
          ],
        ),
        onTap: () => onNotificationTap(notification),
      ),
    );
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'security_alert':
        return AppTheme.errorColor;
      case 'system_warning':
        return AppTheme.warningColor;
      case 'user_report':
        return AppTheme.accentColor;
      case 'transaction_issue':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'security_alert':
        return Icons.security;
      case 'system_warning':
        return Icons.warning;
      case 'user_report':
        return Icons.report;
      case 'transaction_issue':
        return Icons.swap_horiz;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      final time = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(time);
      
      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else {
        return '${difference.inDays}일 전';
      }
    } catch (e) {
      return '';
    }
  }
}