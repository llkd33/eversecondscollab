import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

// SMS 에러 타입
enum SMSErrorType {
  invalidPhoneNumber,
  rateLimited,
  messageTooLong,
  networkError,
  serviceUnavailable,
  authenticationFailed,
  insufficientBalance,
}

// SMS 예외 클래스
class SMSException implements Exception {
  final String message;
  final SMSErrorType errorType;
  final bool isRetryable;

  SMSException(this.message, this.errorType, {bool? isRetryable})
    : isRetryable = isRetryable ?? _getDefaultRetryable(errorType);

  static bool _getDefaultRetryable(SMSErrorType errorType) {
    switch (errorType) {
      case SMSErrorType.invalidPhoneNumber:
      case SMSErrorType.rateLimited:
      case SMSErrorType.messageTooLong:
      case SMSErrorType.authenticationFailed:
      case SMSErrorType.insufficientBalance:
        return false;
      case SMSErrorType.networkError:
      case SMSErrorType.serviceUnavailable:
        return true;
    }
  }

  @override
  String toString() => 'SMSException: $message (${errorType.name})';
}

class SMSService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 관리자 전화번호 (실제 환경에서는 환경변수로 관리)
  static const String adminPhoneNumber = '010-1234-5678';

  // SMS 발송 제한 (동일 번호로 1분에 1회)
  static final Map<String, DateTime> _lastSentTime = {};
  static const Duration _rateLimitDuration = Duration(minutes: 1);

  // SMS 템플릿 관리
  static const Map<String, String> _smsTemplates = {
    'verification_code': '[에버세컨즈] 인증번호: {code}\n타인에게 절대 알려주지 마세요.\n유효시간: 5분',
    'deposit_request_admin':
        '💰 입금확인 요청\n구매자: {buyer_name} ({buyer_phone})\n상품: {product_title}\n금액: {amount}\n어드민에서 확인 후 처리해주세요.',
    'deposit_confirmed_seller':
        '✅ 입금이 확인되었습니다.\n상품: {product_title}\n금액: {amount}\n상품을 발송해주세요.',
    'deposit_confirmed_reseller':
        '✅ 입금이 확인되었습니다.\n상품: {product_title}\n대신판매 수수료 정산이 예정되어 있습니다.',
    'shipping_info_buyer':
        '📦 상품이 발송되었습니다.\n상품: {product_title}\n{tracking_info}상품 수령 후 완료 버튼을 눌러주세요.',
    'transaction_completed_admin':
        '✅ 거래가 정상 완료되었습니다.\n구매자: {buyer_name}\n판매자: {seller_name}\n상품: {product_title}\n금액: {amount}\n정산 처리를 진행해주세요.',
    'commission_settlement':
        '💰 대신판매 수수료가 정산되었습니다.\n상품: {product_title}\n수수료: {commission}\n감사합니다.',
  };

  // SMS 템플릿 포맷팅
  String _formatSMSTemplate(String templateKey, Map<String, String> variables) {
    String template = _smsTemplates[templateKey] ?? '';
    if (template.isEmpty) {
      throw Exception('SMS 템플릿을 찾을 수 없습니다: $templateKey');
    }

    String formattedMessage = template;
    variables.forEach((key, value) {
      formattedMessage = formattedMessage.replaceAll('{$key}', value);
    });

    return formattedMessage;
  }

  @visibleForTesting
  String debugFormatTemplate(
    String templateKey,
    Map<String, String> variables,
  ) {
    return _formatSMSTemplate(templateKey, variables);
  }

  // SMS 발송 (개선된 버전)
  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
    String type = 'general',
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    Exception? lastException;

    while (retryCount < maxRetries) {
      try {
        // 전화번호 유효성 검사
        if (!_isValidPhoneNumber(phoneNumber)) {
          throw SMSException(
            '유효하지 않은 전화번호입니다: $phoneNumber',
            SMSErrorType.invalidPhoneNumber,
          );
        }

        // Rate limiting 검사 (인증번호 타입만)
        if (type == '인증번호') {
          final lastSent = _lastSentTime[phoneNumber];
          if (lastSent != null) {
            final timeDiff = DateTime.now().difference(lastSent);
            if (timeDiff < _rateLimitDuration) {
              final remainingSeconds =
                  _rateLimitDuration.inSeconds - timeDiff.inSeconds;
              throw SMSException(
                'SMS 발송 제한: ${remainingSeconds}초 후 다시 시도해주세요.',
                SMSErrorType.rateLimited,
              );
            }
          }
          _lastSentTime[phoneNumber] = DateTime.now();
        }

        // 메시지 길이 검사 (SMS 제한: 90바이트, 한글 45자)
        if (message.length > 45) {
          // LMS로 자동 전환 (장문 메시지)
          if (message.length > 2000) {
            throw SMSException(
              '메시지가 너무 깁니다. 2000자 이내로 작성해주세요.',
              SMSErrorType.messageTooLong,
            );
          }
        }

        // 실제 SMS 발송 로직 (여기서는 시뮬레이션)
        // TODO: 실제 SMS API 연동 (Twilio, AWS SNS, 알리고 등)
        await _simulateSMSSending(phoneNumber, message, type);

        // 성공 로그 저장
        await _saveSMSLog(
          phoneNumber: phoneNumber,
          messageType: type,
          messageContent: message,
          isSuccess: true,
          retryCount: retryCount,
        );

        return true;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        retryCount++;

        print('SMS 발송 실패 (시도 $retryCount/$maxRetries): $e');

        // 재시도 불가능한 에러인 경우 즉시 실패 처리
        if (e is SMSException && !e.isRetryable) {
          break;
        }

        // 마지막 시도가 아닌 경우 잠시 대기 후 재시도
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: retryCount * 2)); // 지수 백오프
        }
      }
    }

    // 실패 로그 저장
    await _saveSMSLog(
      phoneNumber: phoneNumber,
      messageType: type,
      messageContent: message,
      isSuccess: false,
      errorMessage: lastException?.toString(),
      retryCount: retryCount,
    );

    throw lastException ?? Exception('SMS 발송에 실패했습니다.');
  }

  // SMS 로그 저장
  Future<void> _saveSMSLog({
    required String phoneNumber,
    required String messageType,
    required String messageContent,
    required bool isSuccess,
    String? errorMessage,
    int retryCount = 0,
  }) async {
    try {
      await _client.from('sms_logs').insert({
        'phone_number': phoneNumber,
        'message_type': messageType,
        'message_content': messageContent,
        'is_sent': isSuccess,
        'error_message': errorMessage,
        'retry_count': retryCount,
        'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving SMS log: $e');
      // 로그 저장 실패는 SMS 발송 실패로 처리하지 않음
    }
  }

  // SMS 발송 시뮬레이션 (실제 API 연동 전까지 사용)
  Future<void> _simulateSMSSending(
    String phoneNumber,
    String message,
    String type,
  ) async {
    // 개발 환경에서는 콘솔에 출력
    print('=== SMS 발송 시뮬레이션 ===');
    print('수신번호: $phoneNumber');
    print('메시지 타입: $type');
    print('메시지 길이: ${message.length}자');
    print('메시지 내용: $message');
    print('발송 시간: ${DateTime.now()}');
    print('========================');

    // 네트워크 지연 시뮬레이션 (실제 SMS API 응답 시간 모방)
    final delay = Duration(
      milliseconds: 300 + (DateTime.now().millisecond % 700),
    );
    await Future.delayed(delay);

    // 실패 시뮬레이션 (5% 확률로 실패)
    final random = DateTime.now().millisecond % 100;
    if (random < 5) {
      if (random < 2) {
        throw SMSException('네트워크 연결 오류', SMSErrorType.networkError);
      } else if (random < 4) {
        throw SMSException('SMS 서비스 일시 장애', SMSErrorType.serviceUnavailable);
      } else {
        throw SMSException('인증 실패', SMSErrorType.authenticationFailed);
      }
    }

    // 성공 시뮬레이션
    print('✅ SMS 발송 성공 (시뮬레이션)');
  }

  // 관리자에게 SMS 발송
  Future<bool> sendSMSToAdmin({
    required String message,
    String type = 'admin_notification',
  }) async {
    return sendSMS(phoneNumber: adminPhoneNumber, message: message, type: type);
  }

  // 인증번호 SMS 발송 (개선된 버전)
  Future<bool> sendVerificationCode({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      // 전화번호 유효성 검사
      if (!_isValidPhoneNumber(phoneNumber)) {
        throw SMSException(
          '유효하지 않은 전화번호입니다: $phoneNumber',
          SMSErrorType.invalidPhoneNumber,
        );
      }

      // 인증번호 유효성 검사
      if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
        throw SMSException(
          '유효하지 않은 인증번호 형식입니다: $code',
          SMSErrorType.invalidPhoneNumber,
        );
      }

      // 템플릿을 사용하여 메시지 생성
      final message = _formatSMSTemplate('verification_code', {'code': code});

      return await sendSMS(
        phoneNumber: phoneNumber,
        message: message,
        type: '인증번호',
      );
    } catch (e) {
      print('Error sending verification code: $e');
      rethrow;
    }
  }

  // 전화번호 유효성 검사
  bool _isValidPhoneNumber(String phoneNumber) {
    // 한국 전화번호 패턴 검사
    final RegExp phoneRegExp = RegExp(r'^01[0-9]-?[0-9]{4}-?[0-9]{4}$');
    return phoneRegExp.hasMatch(phoneNumber);
  }

  @visibleForTesting
  bool debugIsValidPhoneNumber(String phoneNumber) {
    return _isValidPhoneNumber(phoneNumber);
  }

  // 입금확인 요청 SMS (관리자용)
  Future<bool> sendDepositRequestToAdmin({
    required String buyerName,
    required String buyerPhone,
    required String productTitle,
    required int amount,
  }) async {
    try {
      final message = _formatSMSTemplate('deposit_request_admin', {
        'buyer_name': buyerName,
        'buyer_phone': buyerPhone,
        'product_title': productTitle,
        'amount': _formatPrice(amount),
      });

      return await sendSMSToAdmin(message: message, type: '입금확인요청');
    } catch (e) {
      print('Error sending deposit request to admin: $e');
      rethrow;
    }
  }

  // 입금확인 완료 SMS (판매자용)
  Future<bool> sendDepositConfirmedToSeller({
    required String sellerPhone,
    required String productTitle,
    required int amount,
  }) async {
    try {
      final message = _formatSMSTemplate('deposit_confirmed_seller', {
        'product_title': productTitle,
        'amount': _formatPrice(amount),
      });

      return await sendSMS(
        phoneNumber: sellerPhone,
        message: message,
        type: '입금확인',
      );
    } catch (e) {
      print('Error sending deposit confirmed to seller: $e');
      rethrow;
    }
  }

  // 입금확인 완료 SMS (대신판매자용)
  Future<bool> sendDepositConfirmedToReseller({
    required String resellerPhone,
    required String productTitle,
  }) async {
    try {
      final message = _formatSMSTemplate('deposit_confirmed_reseller', {
        'product_title': productTitle,
      });

      return await sendSMS(
        phoneNumber: resellerPhone,
        message: message,
        type: '입금확인',
      );
    } catch (e) {
      print('Error sending deposit confirmed to reseller: $e');
      rethrow;
    }
  }

  // 배송정보 SMS (구매자용)
  Future<bool> sendShippingInfoToBuyer({
    required String buyerPhone,
    required String productTitle,
    String? trackingNumber,
    String? courier,
  }) async {
    try {
      String trackingInfo = '';
      if (trackingNumber != null) {
        trackingInfo += '운송장번호: $trackingNumber\n';
      }
      if (courier != null) {
        trackingInfo += '택배사: $courier\n';
      }

      final message = _formatSMSTemplate('shipping_info_buyer', {
        'product_title': productTitle,
        'tracking_info': trackingInfo,
      });

      return await sendSMS(
        phoneNumber: buyerPhone,
        message: message,
        type: '배송정보',
      );
    } catch (e) {
      print('Error sending shipping info to buyer: $e');
      rethrow;
    }
  }

  // 거래완료 SMS (회사용)
  Future<bool> sendTransactionCompletedToAdmin({
    required String buyerName,
    required String sellerName,
    required String productTitle,
    required int amount,
  }) async {
    try {
      final message = _formatSMSTemplate('transaction_completed_admin', {
        'buyer_name': buyerName,
        'seller_name': sellerName,
        'product_title': productTitle,
        'amount': _formatPrice(amount),
      });

      return await sendSMSToAdmin(message: message, type: '거래완료');
    } catch (e) {
      print('Error sending transaction completed to admin: $e');
      rethrow;
    }
  }

  // 대신판매 수수료 정산 SMS
  Future<bool> sendResaleCommissionToReseller({
    required String resellerPhone,
    required String productTitle,
    required int commission,
  }) async {
    try {
      final message = _formatSMSTemplate('commission_settlement', {
        'product_title': productTitle,
        'commission': _formatPrice(commission),
      });

      return await sendSMS(
        phoneNumber: resellerPhone,
        message: message,
        type: '수수료정산',
      );
    } catch (e) {
      print('Error sending commission settlement to reseller: $e');
      rethrow;
    }
  }

  // SMS 발송 내역 조회
  Future<List<Map<String, dynamic>>> getSMSLogs({
    String? phoneNumber,
    String? messageType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('sms_logs').select('*');

      if (phoneNumber != null) {
        query = query.eq('phone_number', phoneNumber);
      }
      if (messageType != null) {
        query = query.eq('message_type', messageType);
      }
      if (startDate != null) {
        query = query.gte('sent_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('sent_at', endDate.toIso8601String());
      }

      final response = await query
          .order('sent_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting SMS logs: $e');
      return [];
    }
  }

  // SMS 발송 통계
  Future<Map<String, dynamic>> getSMSStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client.from('sms_logs').select('message_type, is_sent');

      if (startDate != null) {
        query = query.gte('sent_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('sent_at', endDate.toIso8601String());
      }

      final response = await query;

      final stats = <String, dynamic>{
        'total_count': 0,
        'success_count': 0,
        'failed_count': 0,
        'by_type': <String, int>{},
      };

      for (final log in response) {
        stats['total_count']++;

        if (log['is_sent'] == true) {
          stats['success_count']++;
        } else {
          stats['failed_count']++;
        }

        final type = log['message_type'] as String;
        stats['by_type'][type] = (stats['by_type'][type] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting SMS stats: $e');
      return {};
    }
  }

  // SMS 발송 가능 여부 확인
  bool canSendSMS(String phoneNumber) {
    final lastSent = _lastSentTime[phoneNumber];
    if (lastSent == null) return true;

    final timeDiff = DateTime.now().difference(lastSent);
    return timeDiff >= _rateLimitDuration;
  }

  // 다음 SMS 발송 가능 시간 반환 (초 단위)
  int getNextSendableTime(String phoneNumber) {
    final lastSent = _lastSentTime[phoneNumber];
    if (lastSent == null) return 0;

    final timeDiff = DateTime.now().difference(lastSent);
    final remaining = _rateLimitDuration.inSeconds - timeDiff.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  // SMS 발송 내역 통계 (일별)
  Future<Map<String, int>> getDailySMSStats({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startOfDay = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('sms_logs')
          .select('message_type, is_sent')
          .gte('sent_at', startOfDay.toIso8601String())
          .lt('sent_at', endOfDay.toIso8601String());

      final stats = <String, int>{
        'total': 0,
        'success': 0,
        'failed': 0,
        'verification': 0,
        'notification': 0,
      };

      for (final log in response) {
        stats['total'] = (stats['total'] ?? 0) + 1;

        if (log['is_sent'] == true) {
          stats['success'] = (stats['success'] ?? 0) + 1;
        } else {
          stats['failed'] = (stats['failed'] ?? 0) + 1;
        }

        final type = log['message_type'] as String;
        if (type == '인증번호') {
          stats['verification'] = (stats['verification'] ?? 0) + 1;
        } else {
          stats['notification'] = (stats['notification'] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      print('Error getting daily SMS stats: $e');
      return {};
    }
  }

  // SMS 큐에 추가 (배치 발송용)
  Future<void> addToSMSQueue({
    required String phoneNumber,
    required String message,
    required String type,
    DateTime? scheduledAt,
    int priority = 5, // 1(높음) ~ 10(낮음)
  }) async {
    try {
      await _client.from('sms_queue').insert({
        'phone_number': phoneNumber,
        'message_type': type,
        'message_content': message,
        'priority': priority,
        'scheduled_at': (scheduledAt ?? DateTime.now()).toIso8601String(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding SMS to queue: $e');
      rethrow;
    }
  }

  // SMS 큐 처리 (배치 발송)
  Future<void> processSMSQueue({int batchSize = 10}) async {
    try {
      // 대기중인 SMS 조회 (우선순위 및 예약시간 순)
      final response = await _client
          .from('sms_queue')
          .select()
          .eq('status', 'pending')
          .lte('scheduled_at', DateTime.now().toIso8601String())
          .order('priority')
          .order('scheduled_at')
          .limit(batchSize);

      final smsQueue = response as List;

      for (final smsItem in smsQueue) {
        try {
          // SMS 발송 시도
          final success = await sendSMS(
            phoneNumber: smsItem['phone_number'],
            message: smsItem['message_content'],
            type: smsItem['message_type'],
          );

          // 큐 상태 업데이트
          await _client
              .from('sms_queue')
              .update({
                'status': success ? 'sent' : 'failed',
                'sent_at': DateTime.now().toIso8601String(),
              })
              .eq('id', smsItem['id']);
        } catch (e) {
          // 개별 SMS 실패 시 큐 상태 업데이트
          await _client
              .from('sms_queue')
              .update({
                'status': 'failed',
                'error_message': e.toString(),
                'sent_at': DateTime.now().toIso8601String(),
              })
              .eq('id', smsItem['id']);
        }
      }
    } catch (e) {
      print('Error processing SMS queue: $e');
    }
  }

  // SMS 발송 실패 재시도
  Future<void> retryFailedSMS({int maxRetries = 3}) async {
    try {
      final response = await _client
          .from('sms_logs')
          .select()
          .eq('is_sent', false)
          .lt('retry_count', maxRetries)
          .gte(
            'sent_at',
            DateTime.now().subtract(Duration(hours: 24)).toIso8601String(),
          )
          .order('sent_at', ascending: false)
          .limit(50);

      final failedSMS = response as List;

      for (final sms in failedSMS) {
        try {
          final success = await sendSMS(
            phoneNumber: sms['phone_number'],
            message: sms['message_content'],
            type: sms['message_type'],
          );

          if (success) {
            // 원본 로그 업데이트
            await _client
                .from('sms_logs')
                .update({
                  'is_sent': true,
                  'retry_count': (sms['retry_count'] ?? 0) + 1,
                })
                .eq('id', sms['id']);
          }
        } catch (e) {
          // 재시도 횟수 증가
          await _client
              .from('sms_logs')
              .update({
                'retry_count': (sms['retry_count'] ?? 0) + 1,
                'error_message': e.toString(),
              })
              .eq('id', sms['id']);
        }
      }
    } catch (e) {
      print('Error retrying failed SMS: $e');
    }
  }

  // SMS 템플릿 유효성 검사
  bool validateSMSTemplate(String templateKey, Map<String, String> variables) {
    try {
      _formatSMSTemplate(templateKey, variables);
      return true;
    } catch (e) {
      return false;
    }
  }

  // SMS 발송 가능 시간 확인 (야간 발송 제한 등)
  bool canSendSMSNow({DateTime? targetTime}) {
    final now = targetTime ?? DateTime.now();
    final hour = now.hour;

    // 야간 시간대 (21시 ~ 8시) 발송 제한
    if (hour >= 21 || hour < 8) {
      return false;
    }

    return true;
  }

  // SMS 발송 비용 계산 (예상)
  Map<String, dynamic> calculateSMSCost(String message) {
    final length = message.length;
    int smsCount;
    String messageType;

    if (length <= 45) {
      smsCount = 1;
      messageType = 'SMS';
    } else if (length <= 2000) {
      smsCount = (length / 45).ceil();
      messageType = 'LMS';
    } else {
      smsCount = (length / 45).ceil();
      messageType = 'MMS';
    }

    // 예상 비용 (실제 요금제에 따라 조정 필요)
    final costPerSMS = messageType == 'SMS' ? 20 : 50; // 원
    final totalCost = smsCount * costPerSMS;

    return {
      'message_type': messageType,
      'sms_count': smsCount,
      'cost_per_sms': costPerSMS,
      'total_cost': totalCost,
      'character_count': length,
    };
  }

  // 가격 포맷팅 헬퍼
  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  }
}
