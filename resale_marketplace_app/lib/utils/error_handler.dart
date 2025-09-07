import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 에러 타입 정의
enum ErrorType {
  network,
  authentication,
  validation,
  server,
  unknown,
  timeout,
  permission,
}

/// 사용자 친화적 에러 메시지 클래스
class AppError {
  final ErrorType type;
  final String code;
  final String message;
  final String userMessage;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  AppError({
    required this.type,
    required this.code,
    required this.message,
    required this.userMessage,
    this.originalError,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  /// 에러 타입별 사용자 메시지 생성
  static String _getUserMessage(ErrorType type, String code) {
    switch (type) {
      case ErrorType.network:
        return '인터넷 연결을 확인해주세요. 잠시 후 다시 시도해보세요.';
      case ErrorType.authentication:
        return '로그인이 필요합니다. 다시 로그인해주세요.';
      case ErrorType.validation:
        return '입력하신 정보를 다시 확인해주세요.';
      case ErrorType.server:
        return '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
      case ErrorType.timeout:
        return '요청 시간이 초과되었습니다. 다시 시도해주세요.';
      case ErrorType.permission:
        return '권한이 필요합니다. 설정에서 권한을 허용해주세요.';
      default:
        return '예상치 못한 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
  }

  /// 에러 코드로부터 AppError 생성
  factory AppError.fromCode(String code, {dynamic originalError, StackTrace? stackTrace}) {
    ErrorType type;
    String message;

    // 에러 코드별 분류
    if (code.startsWith('network_') || code.contains('connection')) {
      type = ErrorType.network;
      message = 'Network error: $code';
    } else if (code.startsWith('auth_') || code.contains('unauthorized')) {
      type = ErrorType.authentication;
      message = 'Authentication error: $code';
    } else if (code.startsWith('validation_') || code.contains('invalid')) {
      type = ErrorType.validation;
      message = 'Validation error: $code';
    } else if (code.startsWith('server_') || code.contains('500')) {
      type = ErrorType.server;
      message = 'Server error: $code';
    } else if (code.contains('timeout')) {
      type = ErrorType.timeout;
      message = 'Timeout error: $code';
    } else if (code.contains('permission')) {
      type = ErrorType.permission;
      message = 'Permission error: $code';
    } else {
      type = ErrorType.unknown;
      message = 'Unknown error: $code';
    }

    return AppError(
      type: type,
      code: code,
      message: message,
      userMessage: _getUserMessage(type, code),
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// Exception으로부터 AppError 생성
  factory AppError.fromException(Exception exception, {StackTrace? stackTrace}) {
    String code = 'unknown_exception';
    ErrorType type = ErrorType.unknown;

    if (exception.toString().contains('SocketException') || 
        exception.toString().contains('NetworkException')) {
      type = ErrorType.network;
      code = 'network_connection_failed';
    } else if (exception.toString().contains('TimeoutException')) {
      type = ErrorType.timeout;
      code = 'request_timeout';
    } else if (exception.toString().contains('FormatException')) {
      type = ErrorType.validation;
      code = 'validation_format_error';
    }

    return AppError(
      type: type,
      code: code,
      message: exception.toString(),
      userMessage: _getUserMessage(type, code),
      originalError: exception,
      stackTrace: stackTrace,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'code': code,
      'message': message,
      'userMessage': userMessage,
      'timestamp': timestamp.toIso8601String(),
      'originalError': originalError?.toString(),
    };
  }
}

/// 에러 핸들러 클래스
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final List<AppError> _errorLog = [];
  final int _maxLogSize = 100;

  /// 에러 로깅
  void logError(AppError error) {
    _errorLog.add(error);
    
    // 로그 크기 제한
    if (_errorLog.length > _maxLogSize) {
      _errorLog.removeAt(0);
    }

    // 개발 모드에서 콘솔 출력
    if (kDebugMode) {
      developer.log(
        'AppError: ${error.code}',
        name: 'ErrorHandler',
        error: error.message,
        stackTrace: error.stackTrace,
      );
    }

    // TODO: 프로덕션에서는 외부 로깅 서비스로 전송
    // _sendToLoggingService(error);
  }

  /// 에러 처리 및 사용자에게 표시
  void handleError(BuildContext context, AppError error, {VoidCallback? onRetry}) {
    logError(error);
    
    // 사용자에게 에러 메시지 표시
    showErrorDialog(context, error, onRetry: onRetry);
  }

  /// 에러 다이얼로그 표시
  void showErrorDialog(BuildContext context, AppError error, {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: _getErrorColor(error.type),
            ),
            const SizedBox(width: 8),
            const Text('알림'),
          ],
        ),
        content: Text(error.userMessage),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('다시 시도'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 에러 스낵바 표시
  void showErrorSnackBar(BuildContext context, AppError error, {VoidCallback? onRetry}) {
    final messenger = ScaffoldMessenger.of(context);
    
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(error.userMessage)),
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        action: onRetry != null
            ? SnackBarAction(
                label: '다시 시도',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock;
      case ErrorType.validation:
        return Icons.error_outline;
      case ErrorType.server:
        return Icons.cloud_off;
      case ErrorType.timeout:
        return Icons.access_time;
      case ErrorType.permission:
        return Icons.security;
      default:
        return Icons.warning;
    }
  }

  Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.server:
        return Colors.red;
      case ErrorType.timeout:
        return Colors.blue;
      case ErrorType.permission:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// 에러 로그 조회
  List<AppError> getErrorLog() => List.unmodifiable(_errorLog);

  /// 에러 로그 클리어
  void clearErrorLog() => _errorLog.clear();
}

/// 자동 재시도 메커니즘
class RetryMechanism {
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        attempts++;
        
        // 재시도 여부 판단
        if (attempts >= maxRetries || 
            (shouldRetry != null && !shouldRetry(error))) {
          throw AppError.fromException(
            error is Exception ? error : Exception(error.toString()),
            stackTrace: stackTrace,
          );
        }
        
        // 지연 후 재시도
        await Future.delayed(delay * attempts);
      }
    }
    
    throw AppError.fromCode('max_retries_exceeded');
  }
}

/// 에러 처리 믹스인
mixin ErrorHandlerMixin {
  void handleError(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    AppError appError;
    
    if (error is AppError) {
      appError = error;
    } else if (error is Exception) {
      appError = AppError.fromException(error);
    } else {
      appError = AppError.fromCode('unknown_error', originalError: error);
    }
    
    ErrorHandler().handleError(context, appError, onRetry: onRetry);
  }
  
  void showErrorSnackBar(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    AppError appError;
    
    if (error is AppError) {
      appError = error;
    } else if (error is Exception) {
      appError = AppError.fromException(error);
    } else {
      appError = AppError.fromCode('unknown_error', originalError: error);
    }
    
    ErrorHandler().showErrorSnackBar(context, appError, onRetry: onRetry);
  }
}