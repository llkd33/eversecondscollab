import 'package:logger/logger.dart';

/// Performance logging utility for measuring query and operation performance
class PerformanceLogger {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Measure and log the execution time of a database query
  static Future<T> measureQuery<T>(
    String queryName,
    Future<T> Function() query, {
    Map<String, dynamic>? metadata,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await query();
      stopwatch.stop();

      final duration = stopwatch.elapsedMilliseconds;

      // Log performance warnings for slow queries
      if (duration > 1000) {
        _logger.w(
          '⚠️ SLOW Query: $queryName | ${duration}ms${_formatMetadata(metadata)}',
        );
      } else if (duration > 500) {
        _logger.i(
          '⏱️ Query: $queryName | ${duration}ms${_formatMetadata(metadata)}',
        );
      } else {
        _logger.d(
          '✅ Query: $queryName | ${duration}ms${_formatMetadata(metadata)}',
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      _logger.e(
        '❌ Query Failed: $queryName | ${stopwatch.elapsedMilliseconds}ms | Error: $e${_formatMetadata(metadata)}',
      );
      rethrow;
    }
  }

  /// Measure and log the execution time of any operation
  static Future<T> measureOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? metadata,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();

      final duration = stopwatch.elapsedMilliseconds;

      if (duration > 2000) {
        _logger.w(
          '⚠️ SLOW Operation: $operationName | ${duration}ms${_formatMetadata(metadata)}',
        );
      } else {
        _logger.d(
          '⚡ Operation: $operationName | ${duration}ms${_formatMetadata(metadata)}',
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      _logger.e(
        '❌ Operation Failed: $operationName | ${stopwatch.elapsedMilliseconds}ms | Error: $e${_formatMetadata(metadata)}',
      );
      rethrow;
    }
  }

  /// Log query count for N+1 detection
  static void logQueryCount(String operation, int queryCount) {
    if (queryCount > 5) {
      _logger.w(
        '⚠️ Possible N+1: $operation executed $queryCount queries',
      );
    } else {
      _logger.d(
        '📊 Query count: $operation executed $queryCount queries',
      );
    }
  }

  /// Format metadata for logging
  static String _formatMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return '';

    final parts = metadata.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');

    return ' | $parts';
  }

  /// Log performance summary
  static void logSummary(
    String operation, {
    required int totalQueries,
    required int totalTime,
    int? itemCount,
  }) {
    final avgTime = itemCount != null && itemCount > 0
        ? (totalTime / itemCount).toStringAsFixed(1)
        : 'N/A';

    _logger.i(
      '📊 Performance Summary: $operation\n'
      '   Total Time: ${totalTime}ms\n'
      '   Total Queries: $totalQueries\n'
      '   Items: ${itemCount ?? 0}\n'
      '   Avg Time per Item: ${avgTime}ms',
    );
  }
}
