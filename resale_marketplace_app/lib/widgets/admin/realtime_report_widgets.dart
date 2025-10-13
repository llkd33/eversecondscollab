import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/realtime_provider.dart';
import '../../models/report_model.dart';
import '../../theme/app_theme.dart';
import '../../screens/admin/report_management_screen.dart';

/// 실시간 신고 현황 대시보드 위젯
class RealtimeReportDashboard extends StatelessWidget {
  const RealtimeReportDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '신고 현황',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('전체 보기'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 통계 카드들
            Row(
              children: [
                Expanded(
                  child: _ReportStatCard(
                    title: '미처리 신고',
                    count: realtimeProvider.pendingReportsCount,
                    color: Colors.orange,
                    icon: Icons.pending_actions,
                    isUrgent: realtimeProvider.pendingReportsCount > 10,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReportStatCard(
                    title: '긴급 신고',
                    count: realtimeProvider.reportStats['critical'] ?? 0,
                    color: Colors.red,
                    icon: Icons.warning_amber,
                    isUrgent: (realtimeProvider.reportStats['critical'] ?? 0) > 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReportStatCard(
                    title: '오늘 접수',
                    count: _getTodayReportsCount(realtimeProvider.recentReports),
                    color: Colors.blue,
                    icon: Icons.today,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 최근 신고 목록
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 신고',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (realtimeProvider.recentReports.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '실시간 업데이트',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (realtimeProvider.recentReports.isEmpty)
              _buildEmptyState()
            else
              _RecentReportsList(reports: realtimeProvider.recentReports.take(5).toList()),
          ],
        );
      },
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green[400],
            ),
            const SizedBox(height: 12),
            Text(
              '처리할 신고가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '새로운 신고가 접수되면 실시간으로 표시됩니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  int _getTodayReportsCount(List<ReportModel> reports) {
    final today = DateTime.now();
    return reports.where((report) {
      return report.createdAt.year == today.year &&
             report.createdAt.month == today.month &&
             report.createdAt.day == today.day;
    }).length;
  }
}

/// 신고 통계 카드
class _ReportStatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final bool isUrgent;

  const _ReportStatCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? color : color.withOpacity(0.3),
          width: isUrgent ? 2 : 1,
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
                size: 24,
              ),
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 최근 신고 목록
class _RecentReportsList extends StatelessWidget {
  final List<ReportModel> reports;

  const _RecentReportsList({required this.reports});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: reports.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final report = reports[index];
          return _ReportListItem(report: report);
        },
      ),
    );
  }
}

/// 신고 목록 아이템
class _ReportListItem extends StatelessWidget {
  final ReportModel report;

  const _ReportListItem({required this.report});

  @override
  Widget build(BuildContext context) {
    final priorityColors = {
      'critical': Colors.red,
      'high': Colors.orange,
      'medium': Colors.yellow[700],
      'low': Colors.green,
    };

    final statusColors = {
      'pending': Colors.orange,
      'reviewing': Colors.blue,
      'resolved': Colors.green,
      'rejected': Colors.grey,
    };

    final statusLabels = {
      'pending': '대기',
      'reviewing': '검토중',
      'resolved': '완료',
      'rejected': '거부',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 우선순위 표시
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: priorityColors[report.priority],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          
          // 신고 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.reason,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColors[report.status]?.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabels[report.status] ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColors[report.status],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  report.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _getTargetTypeLabel(report.targetType),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(report.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 액션 버튼
          if (report.status == 'pending') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTargetTypeLabel(String type) {
    switch (type) {
      case 'user':
        return '사용자';
      case 'product':
        return '상품';
      case 'transaction':
        return '거래';
      case 'chat':
        return '채팅';
      default:
        return type;
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 5) {
      return '방금';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

/// 신고 통계 차트 위젯
class ReportStatsChart extends StatelessWidget {
  const ReportStatsChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, child) {
        final stats = realtimeProvider.reportStats;
        final typeStats = realtimeProvider.reportTypeStats;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '신고 유형별 통계',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 유형별 통계
            ...typeStats.entries.map((entry) {
              final percentage = stats['total'] != null && stats['total']! > 0
                  ? entry.value / stats['total']! * 100
                  : 0.0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StatBar(
                  label: _getTypeLabel(entry.key),
                  count: entry.value,
                  percentage: percentage,
                  color: _getTypeColor(entry.key),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'user':
        return '사용자 신고';
      case 'product':
        return '상품 신고';
      case 'transaction':
        return '거래 신고';
      case 'chat':
        return '채팅 신고';
      default:
        return type;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'user':
        return Colors.blue;
      case 'product':
        return Colors.green;
      case 'transaction':
        return Colors.orange;
      case 'chat':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

/// 통계 바 위젯
class _StatBar extends StatelessWidget {
  final String label;
  final int count;
  final double percentage;
  final Color color;

  const _StatBar({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$count건 (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}