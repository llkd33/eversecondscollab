import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Logging Service for admin actions, access logs, and error logs
class LoggingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final LoggingService _instance = LoggingService._internal();

  factory LoggingService() => _instance;
  LoggingService._internal();

  String? _deviceInfo;
  String? _ipAddress;

  /// Initialize logging service
  Future<void> initialize() async {
    await _getDeviceInfo();
  }

  /// Get device information
  Future<void> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo =
            'Android ${androidInfo.version.release} - ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = 'iOS ${iosInfo.systemVersion} - ${iosInfo.model}';
      } else {
        _deviceInfo = 'Unknown Platform';
      }
    } catch (e) {
      _deviceInfo = 'Unknown Device';
    }
  }

  // ==================== Admin Action Logs ====================

  /// Log admin action
  Future<bool> logAdminAction({
    required String adminId,
    required String actionType,
    String? targetType,
    String? targetId,
    Map<String, dynamic>? actionDetails,
    String result = 'success',
    String? errorMessage,
  }) async {
    try {
      final logData = {
        'admin_id': adminId,
        'action_type': actionType,
        'target_type': targetType,
        'target_id': targetId,
        'action_details': actionDetails,
        'user_agent': _deviceInfo,
        'result': result,
        'error_message': errorMessage,
      };

      await _supabase.from('admin_action_logs').insert(logData);
      return true;
    } catch (e) {
      debugPrint('Error logging admin action: $e');
      return false;
    }
  }

  /// Get admin action logs
  Future<List<Map<String, dynamic>>> getAdminActionLogs({
    String? adminId,
    String? actionType,
    String? targetType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('admin_action_logs').select('''
        *,
        admin:users!admin_action_logs_admin_id_fkey(id, name, email)
      ''');

      if (adminId != null) {
        query = query.eq('admin_id', adminId);
      }

      if (actionType != null) {
        query = query.eq('action_type', actionType);
      }

      if (targetType != null) {
        query = query.eq('target_type', targetType);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching admin action logs: $e');
      return [];
    }
  }

  // ==================== Access Logs ====================

  /// Log access
  Future<bool> logAccess({
    String? userId,
    required String endpoint,
    required String method,
    int? statusCode,
    Map<String, dynamic>? requestBody,
    int? responseTime,
  }) async {
    try {
      final logData = {
        'user_id': userId,
        'endpoint': endpoint,
        'method': method,
        'status_code': statusCode,
        'user_agent': _deviceInfo,
        'request_body': requestBody,
        'response_time': responseTime,
      };

      await _supabase.from('access_logs').insert(logData);
      return true;
    } catch (e) {
      debugPrint('Error logging access: $e');
      return false;
    }
  }

  /// Get access logs
  Future<List<Map<String, dynamic>>> getAccessLogs({
    String? userId,
    String? endpoint,
    DateTime? startDate,
    DateTime? endDate,
    int? minStatusCode,
    int? maxStatusCode,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('access_logs').select('''
        *,
        user:users(id, name, email)
      ''');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (endpoint != null) {
        query = query.ilike('endpoint', '%$endpoint%');
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      if (minStatusCode != null) {
        query = query.gte('status_code', minStatusCode);
      }

      if (maxStatusCode != null) {
        query = query.lte('status_code', maxStatusCode);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching access logs: $e');
      return [];
    }
  }

  // ==================== Error Logs ====================

  /// Log error
  Future<bool> logError({
    String? userId,
    required String errorType,
    String? errorCode,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? context,
    String severity = 'medium',
  }) async {
    try {
      final logData = {
        'user_id': userId,
        'error_type': errorType,
        'error_code': errorCode,
        'error_message': errorMessage,
        'stack_trace': stackTrace,
        'context': context,
        'severity': severity,
      };

      await _supabase.from('error_logs').insert(logData);

      // Create notification for critical errors
      if (severity == 'critical') {
        await _createErrorNotification(errorType, errorMessage);
      }

      return true;
    } catch (e) {
      debugPrint('Error logging error: $e');
      return false;
    }
  }

  /// Get error logs
  Future<List<Map<String, dynamic>>> getErrorLogs({
    String? userId,
    String? errorType,
    String? severity,
    bool? resolved,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('error_logs').select('''
        *,
        user:users(id, name, email),
        resolver:users!error_logs_resolved_by_fkey(id, name, email)
      ''');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (errorType != null) {
        query = query.eq('error_type', errorType);
      }

      if (severity != null) {
        query = query.eq('severity', severity);
      }

      if (resolved != null) {
        query = query.eq('resolved', resolved);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching error logs: $e');
      return [];
    }
  }

  /// Resolve error
  Future<bool> resolveError({
    required String errorId,
    required String resolvedBy,
    String? resolutionNotes,
  }) async {
    try {
      await _supabase.from('error_logs').update({
        'resolved': true,
        'resolved_at': DateTime.now().toIso8601String(),
        'resolved_by': resolvedBy,
        'resolution_notes': resolutionNotes,
      }).eq('id', errorId);

      return true;
    } catch (e) {
      debugPrint('Error resolving error: $e');
      return false;
    }
  }

  // ==================== System Metrics ====================

  /// Record system metric
  Future<bool> recordMetric({
    required String metricType,
    required String metricName,
    required double metricValue,
    String? unit,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final metricData = {
        'metric_type': metricType,
        'metric_name': metricName,
        'metric_value': metricValue,
        'unit': unit,
        'metadata': metadata,
      };

      await _supabase.from('system_metrics').insert(metricData);
      return true;
    } catch (e) {
      debugPrint('Error recording metric: $e');
      return false;
    }
  }

  /// Get system metrics
  Future<List<Map<String, dynamic>>> getSystemMetrics({
    String? metricType,
    String? metricName,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      var query = _supabase.from('system_metrics').select();

      if (metricType != null) {
        query = query.eq('metric_type', metricType);
      }

      if (metricName != null) {
        query = query.eq('metric_name', metricName);
      }

      if (startDate != null) {
        query = query.gte('recorded_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('recorded_at', endDate.toIso8601String());
      }

      final response =
          await query.order('recorded_at', ascending: false).limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching system metrics: $e');
      return [];
    }
  }

  // ==================== Statistics ====================

  /// Get logging statistics
  Future<Map<String, dynamic>> getLoggingStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      // Get error logs count by severity
      final errorLogs = await _supabase
          .from('error_logs')
          .select('severity')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      final Map<String, int> errorsBySeverity = {};
      for (final log in errorLogs) {
        final severity = log['severity'] as String;
        errorsBySeverity[severity] = (errorsBySeverity[severity] ?? 0) + 1;
      }

      // Get total access logs
      final accessCount = await _supabase
          .from('access_logs')
          .select('id', const FetchOptions(count: CountOption.exact))
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .count();

      // Get admin action count
      final adminActionsCount = await _supabase
          .from('admin_action_logs')
          .select('id', const FetchOptions(count: CountOption.exact))
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .count();

      // Get average response time
      final avgResponseTime = await _supabase
          .from('access_logs')
          .select('response_time')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .not('response_time', 'is', null);

      double avgTime = 0;
      if (avgResponseTime.isNotEmpty) {
        final times = avgResponseTime
            .map((e) => (e['response_time'] as num).toDouble())
            .toList();
        avgTime = times.reduce((a, b) => a + b) / times.length;
      }

      return {
        'errorsBySeverity': errorsBySeverity,
        'totalErrors': errorsBySeverity.values.fold(0, (a, b) => a + b),
        'totalAccessLogs': accessCount.count,
        'totalAdminActions': adminActionsCount.count,
        'avgResponseTime': avgTime.toStringAsFixed(2),
        'unresolvedErrors': errorsBySeverity['critical'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error fetching logging statistics: $e');
      return {};
    }
  }

  // ==================== Helper Methods ====================

  /// Create notification for critical error
  Future<void> _createErrorNotification(
      String errorType, String errorMessage) async {
    try {
      await _supabase.from('system_notifications').insert({
        'notification_type': 'error',
        'severity': 'critical',
        'title': '심각한 오류 발생: $errorType',
        'message': errorMessage,
        'target_users': null, // Send to all admins
      });
    } catch (e) {
      debugPrint('Error creating error notification: $e');
    }
  }

  /// Clean up old logs (should be called periodically)
  Future<void> cleanupOldLogs() async {
    try {
      // This would typically be handled by a database function
      // For now, just log the intent
      debugPrint('Cleanup old logs initiated');
    } catch (e) {
      debugPrint('Error cleaning up old logs: $e');
    }
  }
}
