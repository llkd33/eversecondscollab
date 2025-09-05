import 'package:flutter/material.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen>
    with SingleTickerProviderStateMixin {
  final ReportService _reportService = ReportService();
  final UserService _userService = UserService();
  
  late TabController _tabController;
  List<ReportModel> _allReports = [];
  List<ReportModel> _filteredReports = [];
  Map<String, UserModel> _userCache = {};
  bool _isLoading = true;
  
  String _selectedStatus = 'pending'; // pending, reviewing, resolved, rejected
  String _selectedType = 'all'; // all, user, product, transaction, chat
  String _selectedPriority = 'all'; // all, low, medium, high, critical
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReports();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadReports() async {
    try {
      setState(() => _isLoading = true);
      
      // 실제 구현 시 서비스 메소드 사용
      // 여기서는 예시 데이터 생성
      await Future.delayed(const Duration(seconds: 1));
      
      final types = ['user', 'product', 'transaction', 'chat'];
      final statuses = ['pending', 'reviewing', 'resolved', 'rejected'];
      final priorities = ['low', 'medium', 'high', 'critical'];
      final reasons = [
        '허위 상품 정보',
        '사기 의심',
        '욕설/비방',
        '개인정보 노출',
        '스팸/광고',
        '거래 파기',
        '상품 상태 불일치',
        '배송 지연',
      ];
      
      _allReports = List.generate(50, (index) {
        return ReportModel(
          id: 'report_$index',
          reporterId: 'user_${index % 10}',
          targetId: 'target_$index',
          targetType: types[index % types.length],
          reason: reasons[index % reasons.length],
          description: '신고 상세 내용입니다. 문제가 발생한 상황을 자세히 설명합니다.',
          status: statuses[index % statuses.length],
          priority: priorities[index % priorities.length],
          evidence: index % 3 == 0 ? ['evidence1.jpg', 'evidence2.jpg'] : null,
          createdAt: DateTime.now().subtract(Duration(hours: index * 3)),
          updatedAt: DateTime.now().subtract(Duration(hours: index * 2)),
          reviewedBy: index % 2 == 0 ? 'admin_1' : null,
          reviewNote: index % 2 == 0 ? '검토 완료. 적절한 조치를 취했습니다.' : null,
        );
      });
      
      _applyFilters();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading reports: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _applyFilters() {
    _filteredReports = List.from(_allReports);
    
    // 상태 필터
    if (_selectedStatus != 'all') {
      _filteredReports = _filteredReports
          .where((r) => r.status == _selectedStatus)
          .toList();
    }
    
    // 타입 필터
    if (_selectedType != 'all') {
      _filteredReports = _filteredReports
          .where((r) => r.targetType == _selectedType)
          .toList();
    }
    
    // 우선순위 필터
    if (_selectedPriority != 'all') {
      _filteredReports = _filteredReports
          .where((r) => r.priority == _selectedPriority)
          .toList();
    }
    
    // 최신순 정렬 (우선순위 고려)
    _filteredReports.sort((a, b) {
      final priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
      final priorityCompare = (priorityOrder[a.priority] ?? 3)
          .compareTo(priorityOrder[b.priority] ?? 3);
      if (priorityCompare != 0) return priorityCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('신고 관리'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '대기중'),
            Tab(text: '검토중'),
            Tab(text: '해결됨'),
            Tab(text: '거부됨'),
          ],
          onTap: (index) {
            setState(() {
              switch (index) {
                case 0:
                  _selectedStatus = 'pending';
                  break;
                case 1:
                  _selectedStatus = 'reviewing';
                  break;
                case 2:
                  _selectedStatus = 'resolved';
                  break;
                case 3:
                  _selectedStatus = 'rejected';
                  break;
              }
              _applyFilters();
            });
          },
        ),
      ),
      body: Column(
        children: [
          // 필터
          _buildFilters(theme),
          // 신고 통계
          _buildStatistics(theme),
          // 신고 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = _filteredReports[index];
                          return _buildReportItem(theme, report);
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 타입 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  '신고 유형:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '전체', 'all', 'type'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '사용자', 'user', 'type'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '상품', 'product', 'type'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '거래', 'transaction', 'type'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '채팅', 'chat', 'type'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 우선순위 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  '우선순위:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '전체', 'all', 'priority'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '낮음', 'low', 'priority'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '보통', 'medium', 'priority'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '높음', 'high', 'priority'),
                const SizedBox(width: 8),
                _buildFilterChip(theme, '긴급', 'critical', 'priority'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(
    ThemeData theme,
    String label,
    String value,
    String filterType,
  ) {
    final isSelected = filterType == 'type'
        ? _selectedType == value
        : _selectedPriority == value;
    
    Color? chipColor;
    if (filterType == 'priority' && value != 'all') {
      switch (value) {
        case 'critical':
          chipColor = Colors.red;
          break;
        case 'high':
          chipColor = Colors.orange;
          break;
        case 'medium':
          chipColor = Colors.yellow;
          break;
        case 'low':
          chipColor = Colors.green;
          break;
      }
    }
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (filterType == 'type') {
            _selectedType = value;
          } else {
            _selectedPriority = value;
          }
          _applyFilters();
        });
      },
      selectedColor: chipColor?.withOpacity(0.3) ?? theme.colorScheme.primaryContainer,
      checkmarkColor: chipColor ?? theme.colorScheme.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected && chipColor != null ? chipColor : null,
      ),
    );
  }
  
  Widget _buildStatistics(ThemeData theme) {
    final pendingCount = _allReports.where((r) => r.status == 'pending').length;
    final criticalCount = _filteredReports.where((r) => r.priority == 'critical').length;
    final highCount = _filteredReports.where((r) => r.priority == 'high').length;
    
    if (pendingCount == 0 && criticalCount == 0 && highCount == 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pendingCount > 0)
                  Text(
                    '처리 대기중인 신고: $pendingCount건',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (criticalCount > 0)
                  Text(
                    '긴급 처리 필요: $criticalCount건',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (highCount > 0)
                  Text(
                    '높은 우선순위: $highCount건',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReportItem(ThemeData theme, ReportModel report) {
    final priorityColors = {
      'critical': Colors.red,
      'high': Colors.orange,
      'medium': Colors.yellow,
      'low': Colors.green,
    };
    
    final typeIcons = {
      'user': Icons.person,
      'product': Icons.shopping_bag,
      'transaction': Icons.receipt,
      'chat': Icons.chat,
    };
    
    final statusColors = {
      'pending': Colors.orange,
      'reviewing': Colors.blue,
      'resolved': Colors.green,
      'rejected': Colors.grey,
    };
    
    final statusLabels = {
      'pending': '대기중',
      'reviewing': '검토중',
      'resolved': '해결됨',
      'rejected': '거부됨',
    };
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: report.priority == 'critical'
              ? Colors.red.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _showReportDetails(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
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
                  // 타입 아이콘
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      typeIcons[report.targetType],
                      size: 20,
                      color: theme.colorScheme.primary,
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
                            Text(
                              report.reason,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
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
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColors[report.status],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${report.id.substring(0, 10)} | ${_formatTime(report.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 증거 표시
                  if (report.evidence != null && report.evidence!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.attach_file,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // 설명
              Text(
                report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // 액션 버튼 (대기중/검토중인 경우)
              if (report.status == 'pending' || report.status == 'reviewing') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (report.status == 'pending')
                      TextButton(
                        onPressed: () => _startReview(report),
                        child: const Text('검토 시작'),
                      ),
                    TextButton(
                      onPressed: () => _resolveReport(report),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                      child: const Text('해결'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _rejectReport(report),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('거부'),
                    ),
                  ],
                ),
              ],
              // 검토자 정보 (해결/거부된 경우)
              if (report.reviewedBy != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: statusColors[report.status],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '검토자: ${report.reviewedBy} | ${report.reviewNote ?? ""}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '신고가 없습니다',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '처리할 신고가 없습니다',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showReportDetails(ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportDetailsSheet(
        report: report,
        onAction: (action) {
          Navigator.pop(context);
          switch (action) {
            case 'review':
              _startReview(report);
              break;
            case 'resolve':
              _resolveReport(report);
              break;
            case 'reject':
              _rejectReport(report);
              break;
          }
        },
      ),
    );
  }
  
  void _startReview(ReportModel report) {
    setState(() {
      report.status = 'reviewing';
      _applyFilters();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('검토를 시작했습니다'),
      ),
    );
  }
  
  void _resolveReport(ReportModel report) {
    showDialog(
      context: context,
      builder: (context) => _ResolveReportDialog(
        onResolve: (note, action) {
          setState(() {
            report.status = 'resolved';
            report.reviewedBy = 'admin_current';
            report.reviewNote = note;
            report.updatedAt = DateTime.now();
            _applyFilters();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('신고가 해결되었습니다. 조치: $action'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
  
  void _rejectReport(ReportModel report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신고 거부'),
        content: const Text('이 신고를 거부하시겠습니까?\n신고가 부적절하거나 증거가 불충분한 경우 거부할 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                report.status = 'rejected';
                report.reviewedBy = 'admin_current';
                report.reviewNote = '증거 불충분으로 거부';
                report.updatedAt = DateTime.now();
                _applyFilters();
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('신고가 거부되었습니다'),
                ),
              );
            },
            child: const Text('거부'),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

// 신고 상세 정보 시트
class _ReportDetailsSheet extends StatelessWidget {
  final ReportModel report;
  final Function(String) onAction;
  
  const _ReportDetailsSheet({
    required this.report,
    required this.onAction,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final priorityLabels = {
      'critical': '긴급',
      'high': '높음',
      'medium': '보통',
      'low': '낮음',
    };
    
    final priorityColors = {
      'critical': Colors.red,
      'high': Colors.orange,
      'medium': Colors.yellow,
      'low': Colors.green,
    };
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '신고 상세 정보',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColors[report.priority]?.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${priorityLabels[report.priority]} 우선순위',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: priorityColors[report.priority],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // 상세 정보
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection(theme, '신고 정보', [
                    _buildInfoRow('신고 ID', report.id),
                    _buildInfoRow('신고 유형', _getTypeLabel(report.targetType)),
                    _buildInfoRow('신고 사유', report.reason),
                    _buildInfoRow('신고일시', _formatDateTime(report.createdAt)),
                  ]),
                  const SizedBox(height: 24),
                  _buildInfoSection(theme, '신고 내용', [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ]),
                  if (report.evidence != null && report.evidence!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildInfoSection(theme, '증거 자료', [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: report.evidence!.map((file) {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  file,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  _buildInfoSection(theme, '신고 대상', [
                    _buildInfoRow('대상 ID', report.targetId),
                    _buildInfoRow('신고자 ID', report.reporterId),
                  ]),
                  if (report.reviewedBy != null) ...[
                    const SizedBox(height: 24),
                    _buildInfoSection(theme, '처리 정보', [
                      _buildInfoRow('처리자', report.reviewedBy!),
                      _buildInfoRow('처리일시', _formatDateTime(report.updatedAt)),
                      if (report.reviewNote != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '처리 내용',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report.reviewNote!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          // 액션 버튼
          if (report.status == 'pending' || report.status == 'reviewing')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (report.status == 'pending')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onAction('review'),
                        child: const Text('검토 시작'),
                      ),
                    ),
                  if (report.status == 'pending')
                    const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onAction('resolve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('해결'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onAction('reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('거부'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  String _getTypeLabel(String type) {
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
  
  String _formatDateTime(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일 '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// 신고 해결 다이얼로그
class _ResolveReportDialog extends StatefulWidget {
  final Function(String note, String action) onResolve;
  
  const _ResolveReportDialog({required this.onResolve});
  
  @override
  State<_ResolveReportDialog> createState() => _ResolveReportDialogState();
}

class _ResolveReportDialogState extends State<_ResolveReportDialog> {
  final TextEditingController _noteController = TextEditingController();
  String _selectedAction = 'warning';
  
  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('신고 해결'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '조치 사항',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile(
              title: const Text('경고'),
              value: 'warning',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),
            RadioListTile(
              title: const Text('계정 정지'),
              value: 'suspend',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),
            RadioListTile(
              title: const Text('콘텐츠 삭제'),
              value: 'delete',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),
            RadioListTile(
              title: const Text('경고 + 삭제'),
              value: 'both',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '처리 내용',
                hintText: '처리 내용을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onResolve(
              _noteController.text.isEmpty
                  ? '관련 조치를 완료했습니다.'
                  : _noteController.text,
              _selectedAction,
            );
          },
          child: const Text('해결'),
        ),
      ],
    );
  }
}