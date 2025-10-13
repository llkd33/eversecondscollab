import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 🔧 Global App Logger
/// Centralized logging utility for the entire application
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.debug : Level.info,
  );

  /// Debug log (verbose, only in debug mode)
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Info log (general information)
  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Warning log (potential issues)
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Error log (errors that need attention)
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Fatal log (critical errors)
  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Create a scoped logger for a specific feature/module
  static ScopedLogger scoped(String scope) {
    return ScopedLogger(scope);
  }
}

/// Scoped logger for specific features/modules
class ScopedLogger {
  final String scope;

  ScopedLogger(this.scope);

  void d(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger.d('[$scope] $message', error, stackTrace);
  }

  void i(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger.i('[$scope] $message', error, stackTrace);
  }

  void w(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger.w('[$scope] $message', error, stackTrace);
  }

  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger.e('[$scope] $message', error, stackTrace);
  }
}

/// Extension to add logging capabilities to any class
extension LoggerExtension on Object {
  Logger get log => AppLogger._logger;

  void logDebug(String message) => AppLogger.d('[$runtimeType] $message');
  void logInfo(String message) => AppLogger.i('[$runtimeType] $message');
  void logWarning(String message) => AppLogger.w('[$runtimeType] $message');
  void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger.e('[$runtimeType] $message', error, stackTrace);
  }
}
