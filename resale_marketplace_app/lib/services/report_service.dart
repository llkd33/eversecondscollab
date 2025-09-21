import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report_model.dart';
import '../utils/uuid.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 신고 생성
  Future<ReportModel?> createReport({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
    required String description,
    List<String>? evidence,
    String priority = 'medium',
  }) async {
    try {
      if (!UuidUtils.isValid(reporterId) || !UuidUtils.isValid(targetId)) {
        throw Exception('신고에 필요한 식별자가 올바르지 않습니다.');
      }
      final response = await _supabase
          .from('reports')
          .insert({
            'reporter_id': reporterId,
            'target_id': targetId,
            'target_type': targetType,
            'reason': reason,
            'description': description,
            'status': 'pending',
            'priority': priority,
            'evidence': evidence,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return ReportModel.fromJson(response);
    } catch (e) {
      print('Error creating report: $e');
      return null;
    }
  }

  // 신고 목록 조회
  Future<List<ReportModel>> getReports({
    String? status,
    String? targetType,
    String? priority,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ReportModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching reports: $e');
      return [];
    }
  }

  // 신고 상태 업데이트
  Future<bool> updateReportStatus({
    required String reportId,
    required String status,
    String? reviewedBy,
    String? reviewNote,
  }) async {
    try {
      if (!UuidUtils.isValid(reportId)) {
        print('updateReportStatus skipped: invalid UUID "$reportId"');
        return false;
      }
      await _supabase
          .from('reports')
          .update({
            'status': status,
            'reviewed_by': reviewedBy,
            'review_note': reviewNote,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);

      return true;
    } catch (e) {
      print('Error updating report status: $e');
      return false;
    }
  }

  // 특정 신고 조회
  Future<ReportModel?> getReportById(String reportId) async {
    try {
      if (!UuidUtils.isValid(reportId)) {
        print('getReportById skipped: invalid UUID "$reportId"');
        return null;
      }
      final response = await _supabase
          .from('reports')
          .select()
          .eq('id', reportId)
          .single();

      return ReportModel.fromJson(response);
    } catch (e) {
      print('Error fetching report: $e');
      return null;
    }
  }

  // 사용자의 신고 내역 조회
  Future<List<ReportModel>> getUserReports(String userId) async {
    try {
      if (!UuidUtils.isValid(userId)) {
        print('getUserReports skipped: invalid UUID "$userId"');
        return [];
      }
      final response = await _supabase
          .from('reports')
          .select()
          .eq('reporter_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user reports: $e');
      return [];
    }
  }

  // 대상에 대한 신고 내역 조회
  Future<List<ReportModel>> getTargetReports(String targetId) async {
    try {
      if (!UuidUtils.isValid(targetId)) {
        print('getTargetReports skipped: invalid UUID "$targetId"');
        return [];
      }
      final response = await _supabase
          .from('reports')
          .select()
          .eq('target_id', targetId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching target reports: $e');
      return [];
    }
  }

  // 대기중인 신고 수 조회
  Future<int> getPendingReportsCount() async {
    try {
      final response = await _supabase
          .from('reports')
          .select()
          .eq('status', 'pending');

      return (response as List).length;
    } catch (e) {
      print('Error fetching pending reports count: $e');
      return 0;
    }
  }

  // 우선순위별 신고 통계
  Future<Map<String, int>> getReportStatsByPriority() async {
    try {
      final response = await _supabase
          .from('reports')
          .select('priority')
          .eq('status', 'pending');

      final stats = <String, int>{
        'critical': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
      };

      for (final report in response as List) {
        final priority = report['priority'] as String;
        stats[priority] = (stats[priority] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error fetching report stats: $e');
      return {};
    }
  }
}
