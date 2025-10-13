import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// 📊 알림 분석 및 성능 모니터링 서비스
/// 알림 전송률, 읽음률, 클릭률 등의 지표를 수집하고 분석
class NotificationAnalyticsService {
  static final NotificationAnalyticsService _instance = 
      NotificationAnalyticsService._internal();
  factory NotificationAnalyticsService() => _instance;
  NotificationAnalyticsService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  /// 📈 알림 상태 업데이트 (전송완료, 읽음, 클릭)
  Future<void> updateNotificationStatus({
    required String notificationId,
    required String status, // 'delivered', 'read', 'clicked'
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
      };

      // 상태별 타임스탬프 설정
      switch (status) {
        case 'delivered':
          updateData['delivered_at'] = DateTime.now().toIso8601String();
          break;
        case 'read':
          updateData['read_at'] = DateTime.now().toIso8601String();
          break;
        case 'clicked':
          updateData['clicked_at'] = DateTime.now().toIso8601String();
          break;
      }

      // 메타데이터 추가
      if (metadata != null) {
        updateData['data'] = metadata;
      }

      await _supabase
          .from('notification_history')
          .update(updateData)
          .eq('id', notificationId);

      developer.log('알림 상태 업데이트: $notificationId -> $status');
    } catch (e) {
      developer.log('알림 상태 업데이트 실패: $e');
    }
  }

  /// 📊 일별 알림 통계 조회
  Future<Map<String, dynamic>> getDailyStats({
    DateTime? date,
    String? notificationType,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = targetDate.toIso8601String().split('T')[0];

      List<dynamic> results;
      if (notificationType != null) {
        results = await _supabase
            .from('notification_metrics')
            .select('*')
            .eq('metric_date', dateStr)
            .eq('notification_type', notificationType);
      } else {
        results = await _supabase
            .from('notification_metrics')
            .select('*')
            .eq('metric_date', dateStr);
      }

      // 통계 집계
      int totalSent = 0;
      int totalDelivered = 0;
      int totalRead = 0;
      int totalClicked = 0;
      int totalFailed = 0;

      for (final metric in results) {
        totalSent += (metric['total_sent'] as int? ?? 0);
        totalDelivered += (metric['total_delivered'] as int? ?? 0);
        totalRead += (metric['total_read'] as int? ?? 0);
        totalClicked += (metric['total_clicked'] as int? ?? 0);
        totalFailed += (metric['total_failed'] as int? ?? 0);
      }

      // 비율 계산
      final deliveryRate = totalSent > 0 ? (totalDelivered / totalSent * 100) : 0.0;
      final readRate = totalDelivered > 0 ? (totalRead / totalDelivered * 100) : 0.0;
      final clickRate = totalRead > 0 ? (totalClicked / totalRead * 100) : 0.0;
      final failureRate = totalSent > 0 ? (totalFailed / totalSent * 100) : 0.0;

      return {
        'date': dateStr,
        'total_sent': totalSent,
        'total_delivered': totalDelivered,
        'total_read': totalRead,
        'total_clicked': totalClicked,
        'total_failed': totalFailed,
        'delivery_rate': double.parse(deliveryRate.toStringAsFixed(2)),
        'read_rate': double.parse(readRate.toStringAsFixed(2)),
        'click_rate': double.parse(clickRate.toStringAsFixed(2)),
        'failure_rate': double.parse(failureRate.toStringAsFixed(2)),
        'by_type': results,
      };
    } catch (e) {
      developer.log('일별 통계 조회 실패: $e');
      return {
        'error': e.toString(),
        'total_sent': 0,
        'total_delivered': 0,
        'total_read': 0,
        'total_clicked': 0,
        'total_failed': 0,
      };
    }
  }

  /// 📈 기간별 통계 조회
  Future<List<Map<String, dynamic>>> getPeriodStats({
    required DateTime startDate,
    required DateTime endDate,
    String? notificationType,
  }) async {
    try {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];

      List<dynamic> results;
      if (notificationType != null) {
        results = await _supabase
            .from('notification_metrics')
            .select('*')
            .gte('metric_date', startStr)
            .lte('metric_date', endStr)
            .eq('notification_type', notificationType)
            .order('metric_date');
      } else {
        results = await _supabase
            .from('notification_metrics')
            .select('*')
            .gte('metric_date', startStr)
            .lte('metric_date', endStr)
            .order('metric_date');
      }

      // 날짜별로 그룹화
      final Map<String, List<dynamic>> groupedByDate = {};
      for (final metric in results) {
        final date = metric['metric_date'];
        if (!groupedByDate.containsKey(date)) {
          groupedByDate[date] = [];
        }
        groupedByDate[date]!.add(metric);
      }

      // 날짜별 통계 계산
      final List<Map<String, dynamic>> periodStats = [];
      for (final entry in groupedByDate.entries) {
        final date = entry.key;
        final metrics = entry.value;

        int totalSent = 0;
        int totalDelivered = 0;
        int totalRead = 0;
        int totalClicked = 0;
        int totalFailed = 0;

        for (final metric in metrics) {
          totalSent += (metric['total_sent'] as int? ?? 0);
          totalDelivered += (metric['total_delivered'] as int? ?? 0);
          totalRead += (metric['total_read'] as int? ?? 0);
          totalClicked += (metric['total_clicked'] as int? ?? 0);
          totalFailed += (metric['total_failed'] as int? ?? 0);
        }

        final deliveryRate = totalSent > 0 ? (totalDelivered / totalSent * 100) : 0.0;
        final readRate = totalDelivered > 0 ? (totalRead / totalDelivered * 100) : 0.0;
        final clickRate = totalRead > 0 ? (totalClicked / totalRead * 100) : 0.0;

        periodStats.add({
          'date': date,
          'total_sent': totalSent,
          'total_delivered': totalDelivered,
          'total_read': totalRead,
          'total_clicked': totalClicked,
          'total_failed': totalFailed,
          'delivery_rate': double.parse(deliveryRate.toStringAsFixed(2)),
          'read_rate': double.parse(readRate.toStringAsFixed(2)),
          'click_rate': double.parse(clickRate.toStringAsFixed(2)),
        });
      }

      return periodStats;
    } catch (e) {
      developer.log('기간별 통계 조회 실패: $e');
      return [];
    }
  }

  /// 🎯 사용자별 알림 참여도 분석
  Future<Map<String, dynamic>> getUserEngagementStats(String userId) async {
    try {
      // 최근 30일 알림 히스토리 조회
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final notifications = await _supabase
          .from('notification_history')
          .select('*')
          .eq('user_id', userId)
          .gte('sent_at', thirtyDaysAgo.toIso8601String())
          .order('sent_at', ascending: false);

      // 통계 계산
      final total = notifications.length;
      final delivered = notifications.where((n) => n['delivered_at'] != null).length;
      final read = notifications.where((n) => n['read_at'] != null).length;
      final clicked = notifications.where((n) => n['clicked_at'] != null).length;

      // 타입별 통계
      final Map<String, int> byType = {};
      for (final notification in notifications) {
        final type = notification['notification_type'];
        byType[type] = (byType[type] ?? 0) + 1;
      }

      // 평균 읽기 시간 계산
      double avgReadTime = 0.0;
      if (read > 0) {
        int totalReadTime = 0;
        int readCount = 0;
        
        for (final notification in notifications) {
          final sentAt = notification['sent_at'];
          final readAt = notification['read_at'];
          
          if (sentAt != null && readAt != null) {
            final sent = DateTime.parse(sentAt);
            final readTime = DateTime.parse(readAt);
            totalReadTime += readTime.difference(sent).inMinutes;
            readCount++;
          }
        }
        
        if (readCount > 0) {
          avgReadTime = totalReadTime / readCount;
        }
      }

      return {
        'user_id': userId,
        'period_days': 30,
        'total_notifications': total,
        'delivered_count': delivered,
        'read_count': read,
        'clicked_count': clicked,
        'delivery_rate': total > 0 ? (delivered / total * 100) : 0.0,
        'read_rate': delivered > 0 ? (read / delivered * 100) : 0.0,
        'click_rate': read > 0 ? (clicked / read * 100) : 0.0,
        'avg_read_time_minutes': avgReadTime,
        'by_type': byType,
        'last_notification_at': notifications.isNotEmpty 
            ? notifications.first['sent_at'] 
            : null,
      };
    } catch (e) {
      developer.log('사용자 참여도 분석 실패: $e');
      return {
        'error': e.toString(),
        'user_id': userId,
      };
    }
  }

  /// 🏆 알림 성과 순위 조회
  Future<List<Map<String, dynamic>>> getTopPerformingNotifications({
    int limit = 10,
    String metric = 'click_rate', // 'click_rate', 'read_rate', 'delivery_rate'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      // 알림 히스토리에서 성과 데이터 조회
      final notifications = await _supabase
          .from('notification_history')
          .select('title, body, notification_type, sent_at, delivered_at, read_at, clicked_at')
          .gte('sent_at', start.toIso8601String())
          .lte('sent_at', end.toIso8601String());

      // 제목별로 그룹화하여 통계 계산
      final Map<String, Map<String, dynamic>> titleStats = {};

      for (final notification in notifications) {
        final title = notification['title'];
        if (!titleStats.containsKey(title)) {
          titleStats[title] = {
            'title': title,
            'body': notification['body'],
            'type': notification['notification_type'],
            'total': 0,
            'delivered': 0,
            'read': 0,
            'clicked': 0,
          };
        }

        final stats = titleStats[title]!;
        stats['total']++;
        
        if (notification['delivered_at'] != null) stats['delivered']++;
        if (notification['read_at'] != null) stats['read']++;
        if (notification['clicked_at'] != null) stats['clicked']++;
      }

      // 비율 계산 및 정렬
      final rankedNotifications = titleStats.values.map((stats) {
        final total = stats['total'] as int;
        final delivered = stats['delivered'] as int;
        final read = stats['read'] as int;
        final clicked = stats['clicked'] as int;

        stats['delivery_rate'] = total > 0 ? (delivered / total * 100) : 0.0;
        stats['read_rate'] = delivered > 0 ? (read / delivered * 100) : 0.0;
        stats['click_rate'] = read > 0 ? (clicked / read * 100) : 0.0;

        return stats;
      }).toList();

      // 지정된 메트릭으로 정렬
      rankedNotifications.sort((a, b) => 
          (b[metric] as double).compareTo(a[metric] as double));

      return rankedNotifications.take(limit).toList();
    } catch (e) {
      developer.log('성과 순위 조회 실패: $e');
      return [];
    }
  }

  /// 🔍 A/B 테스트 결과 분석
  Future<Map<String, dynamic>> analyzeABTest({
    required String testId,
    required String variantA,
    required String variantB,
  }) async {
    try {
      // A/B 테스트 결과 조회 (data 필드에 test_id가 포함된 알림들)
      final notifications = await _supabase
          .from('notification_history')
          .select('*')
          .like('data', '%"test_id":"$testId"%');

      final variantAStats = _calculateVariantStats(notifications, variantA);
      final variantBStats = _calculateVariantStats(notifications, variantB);

      // 통계적 유의성 계산 (간단한 카이제곱 테스트)
      final significance = _calculateStatisticalSignificance(
        variantAStats, variantBStats
      );

      return {
        'test_id': testId,
        'variant_a': {
          'name': variantA,
          ...variantAStats,
        },
        'variant_b': {
          'name': variantB,
          ...variantBStats,
        },
        'statistical_significance': significance,
        'winner': _determineWinner(variantAStats, variantBStats),
        'confidence_level': significance['p_value'] < 0.05 ? 95 : 
                           significance['p_value'] < 0.1 ? 90 : 0,
      };
    } catch (e) {
      developer.log('A/B 테스트 분석 실패: $e');
      return {
        'error': e.toString(),
        'test_id': testId,
      };
    }
  }

  /// 📊 variant별 통계 계산
  Map<String, dynamic> _calculateVariantStats(
    List<dynamic> notifications, 
    String variant
  ) {
    final variantNotifications = notifications.where((n) {
      final data = n['data'];
      return data != null && data['variant'] == variant;
    }).toList();

    final total = variantNotifications.length;
    final delivered = variantNotifications.where((n) => n['delivered_at'] != null).length;
    final read = variantNotifications.where((n) => n['read_at'] != null).length;
    final clicked = variantNotifications.where((n) => n['clicked_at'] != null).length;

    return {
      'total': total,
      'delivered': delivered,
      'read': read,
      'clicked': clicked,
      'delivery_rate': total > 0 ? (delivered / total * 100) : 0.0,
      'read_rate': delivered > 0 ? (read / delivered * 100) : 0.0,
      'click_rate': read > 0 ? (clicked / read * 100) : 0.0,
    };
  }

  /// 📈 통계적 유의성 계산
  Map<String, dynamic> _calculateStatisticalSignificance(
    Map<String, dynamic> variantA,
    Map<String, dynamic> variantB,
  ) {
    // 간단한 카이제곱 테스트 구현
    final aClicked = variantA['clicked'] as int;
    final aTotal = variantA['total'] as int;
    final bClicked = variantB['clicked'] as int;
    final bTotal = variantB['total'] as int;

    if (aTotal == 0 || bTotal == 0) {
      return {'chi_square': 0.0, 'p_value': 1.0, 'significant': false};
    }

    final totalClicked = aClicked + bClicked;
    final totalSample = aTotal + bTotal;
    final expectedA = (aTotal * totalClicked) / totalSample;
    final expectedB = (bTotal * totalClicked) / totalSample;

    final chiSquare = ((aClicked - expectedA) * (aClicked - expectedA) / expectedA) +
                      ((bClicked - expectedB) * (bClicked - expectedB) / expectedB);

    // 간단한 p-value 추정 (정확한 계산을 위해서는 통계 라이브러리 필요)
    final pValue = chiSquare > 3.841 ? 0.05 : 
                   chiSquare > 2.706 ? 0.1 : 1.0;

    return {
      'chi_square': chiSquare,
      'p_value': pValue,
      'significant': pValue < 0.05,
    };
  }

  /// 🏆 승자 결정
  String _determineWinner(
    Map<String, dynamic> variantA,
    Map<String, dynamic> variantB,
  ) {
    final aClickRate = variantA['click_rate'] as double;
    final bClickRate = variantB['click_rate'] as double;

    if (aClickRate > bClickRate) return 'variant_a';
    if (bClickRate > aClickRate) return 'variant_b';
    return 'tie';
  }
}