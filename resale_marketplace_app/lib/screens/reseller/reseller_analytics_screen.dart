import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/reseller_analytics_service.dart';
import '../../models/reseller_analytics_model.dart';
import '../../widgets/common/loading_widget.dart';
import '../../utils/error_handler.dart';
import '../../utils/app_logger.dart';
import '../../config/supabase_config.dart';

/// 📊 대신판매 분석 대시보드 - Enhanced with better performance
class ResellerAnalyticsScreen extends StatefulWidget {
  const ResellerAnalyticsScreen({super.key});

  @override
  State<ResellerAnalyticsScreen> createState() => _ResellerAnalyticsScreenState();
}

class _ResellerAnalyticsScreenState extends State<ResellerAnalyticsScreen>
    with ErrorHandlerMixin, SingleTickerProviderStateMixin {
  final _logger = AppLogger.scoped('ResellerAnalytics');
  final _analyticsService = ResellerAnalyticsService();

  ResellerAnalytics? _analytics;
  bool _isLoading = true;
  String _selectedPeriod = '월간';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadAnalytics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) throw Exception('로그인이 필요합니다');

      final analytics = await _analyticsService.getAnalytics(userId);

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (error) {
      _logger.e('Failed to load analytics', error);
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, error, onRetry: _loadAnalytics);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('대신판매 분석'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget.center(message: '분석 데이터 로딩 중...')
          : _analytics == null
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOverviewCards(),
                          const SizedBox(height: AppTheme.spacingLg),
                          _EarningsChartCard(
                            analytics: _analytics!,
                            selectedPeriod: _selectedPeriod,
                            onPeriodChanged: (period) =>
                                setState(() => _selectedPeriod = period),
                          ),
                          const SizedBox(height: AppTheme.spacingLg),
                          _SalesChartCard(analytics: _analytics!),
                          const SizedBox(height: AppTheme.spacingLg),
                          _buildPerformanceMetrics(),
                          const SizedBox(height: AppTheme.spacingLg),
                          _buildTopProducts(),
                          const SizedBox(height: AppTheme.spacingLg),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '분석 데이터가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '상품을 등록하고 판매를 시작해보세요',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '총 상품',
            value: '${_analytics!.totalProducts}',
            unit: '개',
            icon: Icons.inventory_2_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            subtitle: '활성 ${_analytics!.activeProducts}개',
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: _StatCard(
            title: '판매 완료',
            value: '${_analytics!.soldProducts}',
            unit: '개',
            icon: Icons.check_circle_outline,
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            subtitle: '${_analytics!.conversionRate.toStringAsFixed(1)}% 전환율',
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '성과 지표',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          _MetricRow(
            label: '전환율',
            value: '${_analytics!.conversionRate.toStringAsFixed(1)}%',
            icon: Icons.trending_up,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          _MetricRow(
            label: '고유 구매자',
            value: '${_analytics!.uniqueBuyers}명',
            icon: Icons.people_outline,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          _MetricRow(
            label: '평균 주문 금액',
            value: '₩${_formatNumber(_analytics!.avgOrderValue.toInt())}',
            icon: Icons.attach_money,
            color: const Color(0xFF9C27B0),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          _MetricRow(
            label: '재구매율',
            value: '${(_analytics!.repeatCustomerRate * 100).toStringAsFixed(1)}%',
            icon: Icons.repeat,
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '상위 성과 상품',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (_analytics!.topPerformingProducts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_analytics!.topPerformingProducts.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          if (_analytics!.topPerformingProducts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      '상품 데이터가 없습니다',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._analytics!.topPerformingProducts.map((product) {
              return _ProductPerformanceCard(product: product);
            }),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Stat card with gradient background
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Gradient gradient;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.gradient,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 28),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Earnings chart card - separated for performance
class _EarningsChartCard extends StatelessWidget {
  final ResellerAnalytics analytics;
  final String selectedPeriod;
  final Function(String) onPeriodChanged;

  const _EarningsChartCard({
    required this.analytics,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                '수익 분석',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              _PeriodSelector(
                selectedPeriod: selectedPeriod,
                onChanged: onPeriodChanged,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          _EarningsStats(analytics: analytics),
          const SizedBox(height: AppTheme.spacingXl),
          SizedBox(
            height: 200,
            child: _EarningsLineChart(analytics: analytics),
          ),
        ],
      ),
    );
  }
}

/// Period selector component
class _PeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onChanged;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  static const _periods = ['일간', '주간', '월간'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _periods.map((period) {
          final isSelected = selectedPeriod == period;
          return GestureDetector(
            onTap: () => onChanged(period),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Earnings statistics row
class _EarningsStats extends StatelessWidget {
  final ResellerAnalytics analytics;

  const _EarningsStats({required this.analytics});

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EarningStat(
            label: '총 수익',
            value: '₩${_formatNumber(analytics.totalEarnings)}',
            color: const Color(0xFF2196F3),
          ),
        ),
        Expanded(
          child: _EarningStat(
            label: '총 수수료',
            value: '₩${_formatNumber(analytics.totalCommissions)}',
            color: const Color(0xFF4CAF50),
          ),
        ),
        Expanded(
          child: _EarningStat(
            label: '대기 중',
            value: '₩${_formatNumber(analytics.pendingCommissions)}',
            color: const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }
}

/// Single earning stat component
class _EarningStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EarningStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Earnings line chart - separated for better performance
class _EarningsLineChart extends StatelessWidget {
  final ResellerAnalytics analytics;

  const _EarningsLineChart({required this.analytics});

  @override
  Widget build(BuildContext context) {
    if (analytics.earningsByMonth.isEmpty) {
      return Center(
        child: Text(
          '수익 데이터가 없습니다',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final sortedEntries = analytics.earningsByMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = sortedEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 50000,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey[100]!,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedEntries.length) return const Text('');
                final month = sortedEntries[value.toInt()].key.split('-')[1];
                return Text(
                  '${month}월',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 50000,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                '${(value ~/ 1000)}k',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sortedEntries.length - 1).toDouble(),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: AppTheme.primaryColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.3),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sales chart card - separated for performance
class _SalesChartCard extends StatelessWidget {
  final ResellerAnalytics analytics;

  const _SalesChartCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '월별 판매량',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          SizedBox(
            height: 200,
            child: _SalesBarChart(analytics: analytics),
          ),
        ],
      ),
    );
  }
}

/// Sales bar chart - separated for better performance
class _SalesBarChart extends StatelessWidget {
  final ResellerAnalytics analytics;

  const _SalesBarChart({required this.analytics});

  @override
  Widget build(BuildContext context) {
    if (analytics.salesByMonth.isEmpty) {
      return Center(
        child: Text(
          '판매 데이터가 없습니다',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final sortedEntries = analytics.salesByMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.primaryColor,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}건',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedEntries.length) return const Text('');
                final month = sortedEntries[value.toInt()].key.split('-')[1];
                return Text(
                  '${month}월',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: sortedEntries.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF1976D2)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Metric row component
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Product performance card
class _ProductPerformanceCard extends StatelessWidget {
  final ProductPerformance product;

  const _ProductPerformanceCard({required this.product});

  Color _getPerformanceColor(String level) {
    switch (level) {
      case '우수':
        return const Color(0xFF4CAF50);
      case '양호':
        return const Color(0xFF2196F3);
      case '보통':
        return const Color(0xFFFF9800);
      case '저조':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final performanceColor = _getPerformanceColor(product.performanceLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: performanceColor.withValues(alpha: 0.03),
        border: Border.all(color: performanceColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: product.productImage != null
                ? Image.network(
                    product.productImage!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStat(Icons.visibility_outlined, '${product.views}'),
                    const SizedBox(width: 12),
                    _buildStat(Icons.favorite_border, '${product.favorites}'),
                    const SizedBox(width: 12),
                    _buildStat(Icons.chat_bubble_outline, '${product.inquiries}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: performanceColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: performanceColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              product.performanceLevel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 28),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
