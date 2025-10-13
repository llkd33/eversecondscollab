import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../services/auth_service.dart';
import '../models/report_model.dart';
import '../theme/app_theme.dart';

/// 신고 버튼 위젯 - 모든 화면에서 재사용 가능
class ReportButton extends StatelessWidget {
  final String targetId;
  final String targetType; // user, product, transaction, chat
  final String? targetTitle; // 신고 대상 제목
  final Widget? child; // 커스텀 버튼 위젯
  final VoidCallback? onReported; // 신고 완료 후 콜백

  const ReportButton({
    super.key,
    required this.targetId,
    required this.targetType,
    this.targetTitle,
    this.child,
    this.onReported,
  });

  @override
  Widget build(BuildContext context) {
    return child ??
        IconButton(
          icon: const Icon(Icons.flag_outlined),
          onPressed: () => _showReportDialog(context),
          tooltip: '신고하기',
        );
  }

  void _showReportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportBottomSheet(
        targetId: targetId,
        targetType: targetType,
        targetTitle: targetTitle,
        onReported: onReported,
      ),
    );
  }
}

class _ReportBottomSheet extends StatefulWidget {
  final String targetId;
  final String targetType;
  final String? targetTitle;
  final VoidCallback? onReported;

  const _ReportBottomSheet({
    required this.targetId,
    required this.targetType,
    this.targetTitle,
    this.onReported,
  });

  @override
  State<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<_ReportBottomSheet> {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService();
  final TextEditingController _descriptionController = TextEditingController();
  
  String _selectedReason = '';
  bool _isSubmitting = false;
  
  final List<Map<String, String>> _reasons = [
    {'value': '허위 정보', 'label': '허위 정보', 'description': '잘못된 정보나 거짓 내용'},
    {'value': '사기 의심', 'label': '사기 의심', 'description': '의심스러운 거래나 행위'},
    {'value': '욕설/비방', 'label': '욕설/비방', 'description': '부적절한 언어 사용'},
    {'value': '스팸/광고', 'label': '스팸/광고', 'description': '무관한 광고나 스팸'},
    {'value': '개인정보 노출', 'label': '개인정보 노출', 'description': '개인정보 무단 공개'},
    {'value': '부적절한 콘텐츠', 'label': '부적절한 콘텐츠', 'description': '음란, 폭력 등 부적절한 내용'},
    {'value': '저작권 침해', 'label': '저작권 침해', 'description': '무단 사용이나 도용'},
    {'value': '기타', 'label': '기타', 'description': '위에 해당하지 않는 문제'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                      '신고하기',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.targetTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.targetTitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
          // 신고 사유 선택
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '신고 사유',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._reasons.map((reason) => _buildReasonCard(theme, reason)),
                  const SizedBox(height: 20),
                  Text(
                    '상세 설명',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: '신고 사유에 대해 자세히 설명해주세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '허위 신고는 제재될 수 있습니다. 신중하게 신고해주세요.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 제출 버튼
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
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_selectedReason.isNotEmpty && !_isSubmitting)
                        ? _submitReport
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('신고하기'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard(ThemeData theme, Map<String, String> reason) {
    final isSelected = _selectedReason == reason['value'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedReason = reason['value']!;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? theme.colorScheme.primaryContainer 
                : theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? theme.colorScheme.primary 
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: reason['value']!,
                groupValue: _selectedReason,
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value!;
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason['label']!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                            ? theme.colorScheme.onPrimaryContainer 
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason['description']!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected 
                            ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedReason.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final description = _descriptionController.text.trim();
      if (description.isEmpty) {
        throw Exception('상세 설명을 입력해주세요');
      }

      // 우선순위 자동 설정
      String priority = 'medium';
      if (_selectedReason == '사기 의심' || _selectedReason == '개인정보 노출') {
        priority = 'high';
      } else if (_selectedReason == '허위 정보') {
        priority = 'critical';
      }

      final report = await _reportService.createReport(
        reporterId: currentUser.id,
        targetId: widget.targetId,
        targetType: widget.targetType,
        reason: _selectedReason,
        description: description,
        priority: priority,
      );

      if (report != null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('신고가 접수되었습니다'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: '확인',
                onPressed: () {},
              ),
            ),
          );
          
          widget.onReported?.call();
        }
      } else {
        throw Exception('신고 접수에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신고 접수 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}