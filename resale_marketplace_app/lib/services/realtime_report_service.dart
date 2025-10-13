import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report_model.dart';
import '../services/push_notification_service.dart';

/// 실시간 신고 관리 서비스
class RealtimeReportService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final PushNotificationService _pushService;
  
  RealtimeChannel? _reportsChannel;
  Function(ReportModel)? _onNewReport;
  Function(ReportModel)? _onReportUpdated;
  
  RealtimeReportService() {
    _pushService = PushNotificationService();
  }

  /// 실시간 신고 알림 구독 시작
  Future<void> startReportNotifications({
    required Function(ReportModel) onNewReport,
    required Function(ReportModel) onReportUpdated,
  }) async {
    _onNewReport = onNewReport;
    _onReportUpdated = onReportUpdated;
    
    _reportsChannel = _supabase
        .channel('reports_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reports',
          callback: _handleNewReport,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reports',
          callback: _handleReportUpdate,
        );
    
    await _reportsChannel?.subscribe();
  }

  /// 실시간 알림 구독 중지
  Future<void> stopReportNotifications() async {
    await _reportsChannel?.unsubscribe();
    _reportsChannel = null;
    _onNewReport = null;
    _onReportUpdated = null;
  }

  /// 새 신고 처리
  void _handleNewReport(PostgresChangePayload payload) {
    try {
      final reportData = payload.newRecord;
      final report = ReportModel.fromJson(reportData);
      
      _onNewReport?.call(report);
      
      // 관리자에게 푸시 알림 전송
      _sendAdminNotification(report);
    } catch (e) {
      print('Error handling new report: $e');
    }
  }

  /// 신고 업데이트 처리
  void _handleReportUpdate(PostgresChangePayload payload) {
    try {
      final reportData = payload.newRecord;
      final report = ReportModel.fromJson(reportData);
      
      _onReportUpdated?.call(report);
      
      // 신고자에게 상태 변경 알림
      _notifyReporter(report);
    } catch (e) {
      print('Error handling report update: $e');
    }
  }

  /// 관리자에게 새 신고 알림 전송
  Future<void> _sendAdminNotification(ReportModel report) async {
    try {
      // 관리자 권한을 가진 사용자들 조회
      final admins = await _supabase
          .from('users')
          .select('id, name, fcm_token')
          .eq('is_admin', true);

      for (final admin in admins) {
        final fcmToken = admin['fcm_token'] as String?;
        if (fcmToken != null) {
          await _pushService.sendNotificationToToken(
            token: fcmToken,
            title: '새로운 신고 접수',
            body: '${report.reason} - ${_getTargetTypeLabel(report.targetType)}',
            data: {
              'type': 'new_report',
              'report_id': report.id,
              'priority': report.priority,
              'target_type': report.targetType,
            },
          );
        }
      }
    } catch (e) {
      print('Error sending admin notification: $e');
    }
  }

  /// 신고자에게 상태 변경 알림
  Future<void> _notifyReporter(ReportModel report) async {
    try {
      // 신고자 정보 조회
      final reporter = await _supabase
          .from('users')
          .select('fcm_token')
          .eq('id', report.reporterId)
          .single();

      final fcmToken = reporter['fcm_token'] as String?;
      if (fcmToken != null) {
        String title = '';
        String body = '';

        switch (report.status) {
          case 'reviewing':
            title = '신고 검토 시작';
            body = '신고하신 내용이 검토 중입니다';
            break;
          case 'resolved':
            title = '신고 처리 완료';
            body = '신고하신 내용이 해결되었습니다';
            break;
          case 'rejected':
            title = '신고 처리 결과';
            body = '신고하신 내용이 검토되었으나 조치가 어려웠습니다';
            break;
        }

        if (title.isNotEmpty) {
          await _pushService.sendNotificationToToken(
            token: fcmToken,
            title: title,
            body: body,
            data: {
              'type': 'report_status_change',
              'report_id': report.id,
              'status': report.status,
            },
          );
        }
      }
    } catch (e) {
      print('Error notifying reporter: $e');
    }
  }

  /// 긴급 신고 즉시 알림
  Future<void> sendUrgentReportAlert(ReportModel report) async {
    if (report.priority != 'critical' && report.priority != 'high') return;

    try {
      // 모든 관리자에게 즉시 알림
      final admins = await _supabase
          .from('users')
          .select('id, name, fcm_token')
          .eq('is_admin', true);

      final notification = NotificationPayload(
        id: 'urgent_${report.id}',
        title: '🚨 긴급 신고',
        body: '${report.reason} - 즉시 확인이 필요합니다',
        type: NotificationType.system,
        data: {
          'type': 'urgent_report',
          'report_id': report.id,
          'priority': report.priority,
          'target_type': report.targetType,
          'reason': report.reason,
        },
        timestamp: DateTime.now(),
      );

      for (final admin in admins) {
        final fcmToken = admin['fcm_token'] as String?;
        if (fcmToken != null) {
          await _pushService.sendNotificationToToken(
            token: fcmToken,
            title: notification.title,
            body: notification.body,
            data: notification.data,
          );
        }
      }
    } catch (e) {
      print('Error sending urgent report alert: $e');
    }
  }

  /// 신고 통계 실시간 업데이트
  Stream<Map<String, int>> getReportStatsStream() {
    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .map((reports) {
          final stats = <String, int>{
            'total': reports.length,
            'pending': 0,
            'reviewing': 0,
            'resolved': 0,
            'rejected': 0,
            'critical': 0,
            'high': 0,
            'medium': 0,
            'low': 0,
          };

          for (final report in reports) {
            final status = report['status'] as String;
            final priority = report['priority'] as String;
            
            stats[status] = (stats[status] ?? 0) + 1;
            stats[priority] = (stats[priority] ?? 0) + 1;
          }

          return stats;
        });
  }

  /// 타입별 신고 통계
  Stream<Map<String, int>> getReportsByTypeStream() {
    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .map((reports) {
          final typeStats = <String, int>{
            'user': 0,
            'product': 0,
            'transaction': 0,
            'chat': 0,
          };

          for (final report in reports) {
            final targetType = report['target_type'] as String;
            typeStats[targetType] = (typeStats[targetType] ?? 0) + 1;
          }

          return typeStats;
        });
  }

  /// 최근 신고 목록 스트림
  Stream<List<ReportModel>> getRecentReportsStream({int limit = 10}) {
    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((reports) => 
            reports.map((json) => ReportModel.fromJson(json)).toList());
  }

  /// 미처리 신고 수 스트림
  Stream<int> getPendingReportsCountStream() {
    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .map((reports) => reports.length);
  }

  /// 자동 우선순위 설정
  String calculatePriority(String reason, String targetType, String description) {
    // 키워드 기반 우선순위 설정
    final criticalKeywords = ['사기', '금전', '개인정보', '위협', '협박'];
    final highKeywords = ['허위', '스팸', '도용', '무단'];
    
    final text = '$reason $description'.toLowerCase();
    
    if (criticalKeywords.any((keyword) => text.contains(keyword))) {
      return 'critical';
    } else if (highKeywords.any((keyword) => text.contains(keyword))) {
      return 'high';
    } else if (targetType == 'transaction') {
      return 'high'; // 거래 관련은 기본적으로 높은 우선순위
    } else {
      return 'medium';
    }
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
}