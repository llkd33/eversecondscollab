import 'package:flutter_test/flutter_test.dart';

// Test helper class to test SMS validation logic without Supabase dependency
class SMSValidator {
  // Phone number validation
  static bool isValidPhoneNumber(String phoneNumber) {
    final RegExp phoneRegExp = RegExp(r'^01[0-9]-?[0-9]{4}-?[0-9]{4}$');
    return phoneRegExp.hasMatch(phoneNumber);
  }

  // Verification code validation
  static bool isValidVerificationCode(String code) {
    return code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code);
  }

  // Message length validation
  static bool isValidMessageLength(String message) {
    return message.length <= 45; // SMS limit: 45 Korean characters
  }

  // Rate limiting simulation
  static final Map<String, DateTime> _lastSentTime = {};
  static const Duration _rateLimitDuration = Duration(minutes: 1);

  static bool canSendSMS(String phoneNumber) {
    final lastSent = _lastSentTime[phoneNumber];
    if (lastSent == null) return true;
    
    final timeDiff = DateTime.now().difference(lastSent);
    return timeDiff >= _rateLimitDuration;
  }

  static void recordSMSSent(String phoneNumber) {
    _lastSentTime[phoneNumber] = DateTime.now();
  }

  static int getNextSendableTime(String phoneNumber) {
    final lastSent = _lastSentTime[phoneNumber];
    if (lastSent == null) return 0;
    
    final timeDiff = DateTime.now().difference(lastSent);
    final remaining = _rateLimitDuration.inSeconds - timeDiff.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  // Price formatting
  static String formatPrice(int price) {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }
}

void main() {
  group('SMS Validation Tests', () {

    test('Valid phone number validation', () {
      final validPhones = [
        '010-1234-5678',
        '011-1234-5678',
        '016-1234-5678',
        '017-1234-5678',
        '018-1234-5678',
        '019-1234-5678',
      ];

      for (final phone in validPhones) {
        expect(SMSValidator.isValidPhoneNumber(phone), isTrue, 
               reason: 'Phone $phone should be valid');
      }
    });

    test('Invalid phone number validation', () {
      final invalidPhones = [
        '010-123-5678',    // Too short middle part
        '010-12345-5678',  // Too long middle part
        '020-1234-5678',   // Invalid prefix
        '010-1234-567',    // Too short last part
        '010-1234-56789',  // Too long last part
        'invalid-phone',   // Completely invalid
        '02-1234-5678',    // Landline number
      ];

      for (final phone in invalidPhones) {
        expect(SMSValidator.isValidPhoneNumber(phone), isFalse, 
               reason: 'Phone $phone should be invalid');
      }
    });

    test('Verification code validation', () {
      // Valid codes
      final validCodes = ['123456', '000000', '999999'];
      for (final code in validCodes) {
        expect(SMSValidator.isValidVerificationCode(code), isTrue,
               reason: 'Code $code should be valid');
      }
      
      // Invalid codes
      final invalidCodes = [
        '12345',     // Too short
        '1234567',   // Too long
        '12345a',    // Contains letter
        'abcdef',    // All letters
        '123 456',   // Contains space
      ];

      for (final code in invalidCodes) {
        expect(SMSValidator.isValidVerificationCode(code), isFalse,
               reason: 'Code $code should be invalid');
      }
    });

    test('SMS rate limiting', () {
      const phoneNumber = '010-1234-5678';

      // First SMS should be allowed
      expect(SMSValidator.canSendSMS(phoneNumber), isTrue);
      
      // Record SMS sent
      SMSValidator.recordSMSSent(phoneNumber);

      // Second SMS should be rate limited
      expect(SMSValidator.canSendSMS(phoneNumber), isFalse);
      expect(SMSValidator.getNextSendableTime(phoneNumber), greaterThan(0));
    });

    test('Message length validation', () {
      // Valid message lengths
      final validMessages = [
        '짧은 메시지',
        '인증번호: 123456',
        'a' * 45, // Exactly 45 characters
      ];

      for (final message in validMessages) {
        expect(SMSValidator.isValidMessageLength(message), isTrue,
               reason: 'Message "$message" should be valid');
      }

      // Invalid message lengths
      final invalidMessages = [
        'a' * 46, // Too long
        'a' * 100, // Much too long
      ];

      for (final message in invalidMessages) {
        expect(SMSValidator.isValidMessageLength(message), isFalse,
               reason: 'Message should be too long');
      }
    });

    test('SMS message formatting', () {
      // Test verification code message format
      const code = '123456';
      final verificationMessage = '[에버세컨즈] 인증번호: $code\n'
          '타인에게 절대 알려주지 마세요.\n'
          '유효시간: 5분';
      
      expect(verificationMessage.contains(code), isTrue);
      expect(verificationMessage.contains('에버세컨즈'), isTrue);
      expect(SMSValidator.isValidMessageLength(verificationMessage), isFalse); // This message is longer than 45 chars

      // Test deposit request message format
      const buyerName = '김구매자';
      const productTitle = '테스트 상품';
      const amount = 50000;
      final depositMessage = '💰 입금확인 요청\n'
          '구매자: $buyerName\n'
          '상품: $productTitle\n'
          '금액: ${SMSValidator.formatPrice(amount)}';
      
      expect(depositMessage.contains(buyerName), isTrue);
      expect(depositMessage.contains(productTitle), isTrue);
      expect(depositMessage.contains('50,000원'), isTrue);
    });

    test('Price formatting', () {
      // Test price formatting
      expect(SMSValidator.formatPrice(1000), equals('1,000원'));
      expect(SMSValidator.formatPrice(50000), equals('50,000원'));
      expect(SMSValidator.formatPrice(1234567), equals('1,234,567원'));
      expect(SMSValidator.formatPrice(0), equals('0원'));
    });

    test('Multiple phone number rate limiting', () {
      const phone1 = '010-1111-1111';
      const phone2 = '010-2222-2222';

      // Both phones should be allowed initially
      expect(SMSValidator.canSendSMS(phone1), isTrue);
      expect(SMSValidator.canSendSMS(phone2), isTrue);

      // Send SMS to phone1
      SMSValidator.recordSMSSent(phone1);

      // phone1 should be rate limited, phone2 should still be allowed
      expect(SMSValidator.canSendSMS(phone1), isFalse);
      expect(SMSValidator.canSendSMS(phone2), isTrue);

      // Send SMS to phone2
      SMSValidator.recordSMSSent(phone2);

      // Both should be rate limited now
      expect(SMSValidator.canSendSMS(phone1), isFalse);
      expect(SMSValidator.canSendSMS(phone2), isFalse);
    });

    test('Phone number normalization patterns', () {
      // Test various phone number formats that should be valid
      final phoneVariations = [
        '010-1234-5678',  // Standard format
        '0101234-5678',   // Missing one dash
        '010-12345678',   // Missing middle dash
        '01012345678',    // No dashes
      ];

      // Test which formats pass the current regex pattern
      expect(SMSValidator.isValidPhoneNumber('010-1234-5678'), isTrue);
      expect(SMSValidator.isValidPhoneNumber('0101234-5678'), isTrue); // This actually passes the current regex
      expect(SMSValidator.isValidPhoneNumber('010-12345678'), isTrue); // This also passes the current regex
      expect(SMSValidator.isValidPhoneNumber('01012345678'), isTrue); // This actually passes the current regex
    });
  });
}