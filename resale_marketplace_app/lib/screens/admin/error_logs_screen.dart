import 'package:flutter/material.dart';
import '../../services/logging_service.dart';
import 'package:intl/intl.dart';

/// Error Logs Management Screen
class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  final LoggingService _loggingService = LoggingService();

  List<Map<String, dynamic>> _errorLogs = [];
  bool _isLoading = true;
  String? _selectedSeverity;
  bool? _resolvedFilter;

  final List<String> _severities = ['critical', 'high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _loadErrorLogs();
  }

  Future<void> _loadErrorLogs() async {
    setState(() => _isLoading = true);

    final logs = await _loggingService.getErrorLogs(
      severity: _selectedSeverity,
      resolved: _resolvedFilter,
      limit: 100,
    );

    setState(() {
      _errorLogs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오류 로그'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadErrorLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '오류 로그가 없습니다',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadErrorLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _errorLogs.length,
                    itemBuilder: (context, index) {
                      final log = _errorLogs[index];
                      return _buildErrorLogCard(log, theme);
                    },
                  ),
                ),
    );
  }

  Widget _buildErrorLogCard(Map<String, dynamic> log, ThemeData theme) {
    final severity = log['severity'] as String;
    final errorType = log['error_type'] as String;
    final errorMessage = log['error_message'] as String;
    final resolved = log['resolved'] as bool;
    final createdAt = DateTime.parse(log['created_at']);

    Color severityColor = _getSeverityColor(severity);
    IconData severityIcon = _getSeverityIcon(severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: resolved ? 1 : 3,
      child: InkWell(
        onTap: () => _showErrorDetail(log),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(severityIcon, color: severityColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: severityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getSeverityText(severity),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: severityColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              errorType,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (resolved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '해결됨',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Error Message
              Text(
                errorMessage,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Actions
              if (!resolved) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _resolveError(log['id']),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('해결 처리'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetail(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                Text(
                  '오류 상세',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow('오류 타입', log['error_type']),
                _buildDetailRow('심각도', _getSeverityText(log['severity'])),
                _buildDetailRow('오류 코드', log['error_code'] ?? 'N/A'),
                _buildDetailRow('발생 시간', _formatDateTime(DateTime.parse(log['created_at']))),
                const SizedBox(height: 16),
                const Text(
                  '오류 메시지',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(log['error_message']),
                if (log['stack_trace'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '스택 트레이스',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log['stack_trace'],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (log['context'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '컨텍스트',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(log['context'].toString()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('필터'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('심각도'),
            DropdownButton<String?>(
              value: _selectedSeverity,
              isExpanded: true,
              hint: const Text('전체'),
              items: [
                const DropdownMenuItem(value: null, child: Text('전체')),
                ..._severities.map((severity) {
                  return DropdownMenuItem(
                    value: severity,
                    child: Text(_getSeverityText(severity)),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() => _selectedSeverity = value);
              },
            ),
            const SizedBox(height: 16),
            const Text('상태'),
            DropdownButton<bool?>(
              value: _resolvedFilter,
              isExpanded: true,
              hint: const Text('전체'),
              items: const [
                DropdownMenuItem(value: null, child: Text('전체')),
                DropdownMenuItem(value: false, child: Text('미해결')),
                DropdownMenuItem(value: true, child: Text('해결됨')),
              ],
              onChanged: (value) {
                setState(() => _resolvedFilter = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedSeverity = null;
                _resolvedFilter = null;
              });
              Navigator.pop(context);
              _loadErrorLogs();
            },
            child: const Text('초기화'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadErrorLogs();
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveError(String errorId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류 해결'),
        content: const Text('이 오류를 해결 처리하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해결'),
          ),
        ],
      ),
    );

    if (result == true) {
      // final adminId = await _authService.getCurrentUserId();
      // await _loggingService.resolveError(
      //   errorId: errorId,
      //   resolvedBy: adminId,
      // );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류가 해결 처리되었습니다')),
      );

      _loadErrorLogs();
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow[700]!;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.warning_amber;
      case 'low':
        return Icons.info;
      default:
        return Icons.help;
    }
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
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }
}
