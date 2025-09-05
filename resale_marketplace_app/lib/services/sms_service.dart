import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SMSService {
  final SupabaseClient _client = SupabaseConfig.client;
  
  // 관리자 전화번호 (실제 환경에서는 환경변수로 관리)
  static const String adminPhoneNumber = '010-1234-5678';
  
  // SMS 발송 제한 (동일 번호로 1분에 1회)
  static final Map<String, DateTime> _lastSentTime = {};
  static const Duration _rateLimitDuration = Duration(minutes: 1);

  // SMS 발송 (개선된 버전)
  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
    String type = 'general',
  }) async {
    try {
      // 전화번호 유효성 검사
      if (!_isValidPhoneNumber(phoneNumber)) {
        throw Exception('유효하지 않은 전화번호입니다: $phoneNumber');
      }

      // Rate limiting 검사 (인증번호 타입만)
      if (type == '인증번호') {
        final lastSent = _lastSentTime[phoneNumber];
        if (lastSent != null) {
          final timeDiff = DateTime.now().difference(lastSent);
          if (timeDiff < _rateLimitDuration) {
            final remainingSeconds = _rateLimitDuration.inSeconds - timeDiff.inSeconds;
            throw Exception('SMS 발송 제한: ${remainingSeconds}초 후 다시 시도해주세요.');
          }
        }
        _lastSentTime[phoneNumber] = DateTime.now();
      }

      // 메시지 길이 검사 (SMS 제한: 90바이트, 한글 45자)
      if (message.length > 45) {
        throw Exception('메시지가 너무 깁니다. 45자 이내로 작성해주세요.');
      }

      // 실제 SMS 발송 로직 (여기서는 시뮬레이션)
      // TODO: 실제 SMS API 연동 (Twilio, AWS SNS, 알리고 등)
      await _simulateSMSSending(phoneNumber, message, type);

      // 성공 로그 저장
      await _client.from('sms_logs').insert({
        'phone_number': phoneNumber,
        'message_type': type,
        'message_content': message,
        'is_sent': true,
        'sent_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error sending SMS: $e');
      
      // 실패 로그 저장
      try {
        await _client.from('sms_logs').insert({
          'phone_number': phoneNumber,
          'message_type': type,
          'message_content': message,
          'is_sent': false,
          'error_message': e.toString(),
          'sent_at': DateTime.now().toIso8601String(),
        });
      } catch (logError) {
        print('Error saving SMS log: $logError');
      }
      
      rethrow; // 상위에서 에러 처리할 수 있도록 다시 던짐
    }
  }

  // SMS 발송 시뮬레이션 (실제 API 연동 전까지 사용)
  Future<void> _simulateSMSSending(String phoneNumber, String message, String type) async {
    // 개발 환경에서는 콘솔에 출력
    print('=== SMS 발송 시뮬레이션 ===');
    print('수신번호: $phoneNumber');
    print('메시지 타입: $type');
    print('메시지 내용: $message');
    print('발송 시간: ${DateTime.now()}');
    print('========================');

    // 네트워크 지연 시뮬레이션
    await Future.delayed(const Duration(milliseconds: 500));

    // 실패 시뮬레이션 (10% 확률로 실패)
    if (DateTime.now().millisecond % 10 == 0) {
      throw Exception('SMS 발송 서비스 일시 장애');
    }
  }

  // 관리자에게 SMS 발송
  Future<bool> sendSMSToAdmin({
    required String message,
    String type = 'admin_notification',
  }) async {
    return sendSMS(
      phoneNumber: adminPhoneNumber,
      message: message,
      type: type,
    );
  }

  // 인증번호 SMS 발송 (개선된 버전)
  Future<bool> sendVerificationCode({
    required String phoneNumber,
    required String code,
  }) async {
    // 전화번호 유효성 검사
    if (!_isValidPhoneNumber(phoneNumber)) {
      throw Exception('유효하지 않은 전화번호입니다: $phoneNumber');
    }

    // 인증번호 유효성 검사
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw Exception('유효하지 않은 인증번호 형식입니다: $code');
    }

    final message = '[에버세컨즈] 인증번호: $code\n'
        '타인에게 절대 알려주지 마세요.\n'
        '유효시간: 5분';
    
    return sendSMS(
      phoneNumber: phoneNumber,
      message: message,
      type: '인증번호',
    );
  }

  // 전화번호 유효성 검사
  bool _isValidPhoneNumber(String phoneNumber) {
    // 한국 전화번호 패턴 검사
    final RegExp phoneRegExp = RegExp(r'^01[0-9]-?[0-9]{4}-?[0-9]{4}$');
    return phoneRegExp.hasMatch(phoneNumber);
  }

  // 입금확인 요청 SMS (관리자용)
  Future<bool> sendDepositRequestToAdmin({
    required String buyerName,
    required String buyerPhone,
    required String productTitle,
    required int amount,
  }) async {
    final message = '💰 입금확인 요청\n'
        '구매자: $buyerName ($buyerPhone)\n'
        '상품: $productTitle\n'
        '금액: ${_formatPrice(amount)}\n'
        '어드민에서 확인 후 처리해주세요.';
    
    return sendSMSToAdmin(
      message: message,
      type: '입금확인요청',
    );
  }

  // 입금확인 완료 SMS (판매자용)
  Future<bool> sendDepositConfirmedToSeller({
    required String sellerPhone,
    required String productTitle,
    required int amount,
  }) async {
    final message = '✅ 입금이 확인되었습니다.\n'
        '상품: $productTitle\n'
        '금액: ${_formatPrice(amount)}\n'
        '상품을 발송해주세요.';
    
    return sendSMS(
      phoneNumber: sellerPhone,
      message: message,
      type: '입금확인',
    );
  }

  // 배송정보 SMS (구매자용)
  Future<bool> sendShippingInfoToBuyer({
    required String buyerPhone,
    required String productTitle,
    String? trackingNumber,
    String? courier,
  }) async {
    String message = '📦 상품이 발송되었습니다.\n'
        '상품: $productTitle\n';
    
    if (trackingNumber != null) {
      message += '운송장번호: $trackingNumber\n';
    }
    if (courier != null) {
      message += '택배사: $courier\n';
    }
    
    message += '상품 수령 후 완료 버튼을 눌러주세요.';
    
    return sendSMS(
      phoneNumber: buyerPhone,
      message: message,
      type: '배송정보',
    );
  }

  // 거래완료 SMS (회사용)
  Future<bool> sendTransactionCompletedToAdmin({
    required String buyerName,
    required String sellerName,
    required String productTitle,
    required int amount,
  }) async {
    final message = '✅ 거래가 정상 완료되었습니다.\n'
        '구매자: $buyerName\n'
        '판매자: $sellerName\n'
        '상품: $productTitle\n'
        '금액: ${_formatPrice(amount)}\n'
        '정산 처리를 진행해주세요.';
    
    return sendSMSToAdmin(
      message: message,
      type: '거래완료',
    );
  }

  // 대신판매 수수료 정산 SMS
  Future<bool> sendResaleCommissionToReseller({
    required String resellerPhone,
    required String productTitle,
    required int commission,
  }) async {
    final message = '💰 대신판매 수수료가 정산되었습니다.\n'
        '상품: $productTitle\n'
        '수수료: ${_formatPrice(commission)}\n'
        '감사합니다.';
    
    return sendSMS(
      phoneNumber: resellerPhone,
      message: message,
      type: '수수료정산',
    );
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
      var query = _client
          .from('sms_logs')
          .select('*');

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
      var query = _client
          .from('sms_logs')
          .select('message_type, is_sent');

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
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
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

  // 가격 포맷팅 헬퍼
  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }
}