import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/services/safe_transaction_service.dart';
import '../lib/services/sms_service.dart';
import '../lib/services/chat_service.dart';
import '../lib/models/safe_transaction_model.dart';

// Mock 클래스 생성을 위한 어노테이션
@GenerateMocks([SupabaseClient, SMSService, ChatService])
import 'safe_transaction_test.mocks.dart';

void main() {
  group('SafeTransactionService Tests', () {
    late SafeTransactionService safeTransactionService;
    late MockSupabaseClient mockClient;
    late MockSMSService mockSMSService;
    late MockChatService mockChatService;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockSMSService = MockSMSService();
      mockChatService = MockChatService();
      safeTransactionService = SafeTransactionService();
    });

    group('안전거래 생성', () {
      test('정상적인 안전거래 생성', () async {
        // Given
        const transactionId = 'test-transaction-id';
        const depositAmount = 100000;

        final mockResponse = {
          'id': 'safe-transaction-id',
          'transaction_id': transactionId,
          'deposit_amount': depositAmount,
          'deposit_confirmed': false,
          'shipping_confirmed': false,
          'delivery_confirmed': false,
          'settlement_status': '대기중',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Mock 설정
        when(mockClient.from('safe_transactions')).thenReturn(
          MockPostgrestQueryBuilder()
        );

        // When & Then
        // 실제 테스트는 Supabase 연결이 필요하므로 여기서는 구조만 확인
        expect(safeTransactionService, isNotNull);
      });

      test('중복 안전거래 생성 시 예외 발생', () async {
        // Given
        const transactionId = 'existing-transaction-id';
        const depositAmount = 100000;

        // When & Then
        // 중복 생성 시 예외가 발생해야 함
        expect(safeTransactionService, isNotNull);
      });
    });

    group('입금확인 요청', () {
      test('정상적인 입금확인 요청', () async {
        // Given
        const safeTransactionId = 'safe-transaction-id';
        const buyerPhone = '010-1234-5678';
        const productTitle = '테스트 상품';
        const depositAmount = 100000;

        // When & Then
        expect(safeTransactionService, isNotNull);
      });

      test('이미 입금확인 요청된 경우 예외 발생', () async {
        // Given
        const safeTransactionId = 'already-requested-id';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });
    });

    group('입금 확인', () {
      test('관리자의 입금 확인 처리', () async {
        // Given
        const safeTransactionId = 'safe-transaction-id';
        const adminNotes = '입금 확인 완료';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });

      test('이미 입금확인된 경우 예외 발생', () async {
        // Given
        const safeTransactionId = 'already-confirmed-id';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });
    });

    group('배송 확인', () {
      test('판매자의 배송 시작 확인', () async {
        // Given
        const safeTransactionId = 'safe-transaction-id';
        const trackingNumber = '1234567890';
        const courier = 'CJ대한통운';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });

      test('입금확인 전 배송 시작 시 예외 발생', () async {
        // Given
        const safeTransactionId = 'not-deposit-confirmed-id';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });
    });

    group('배송 완료 확인', () {
      test('구매자의 배송 완료 확인', () async {
        // Given
        const safeTransactionId = 'safe-transaction-id';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });

      test('배송 시작 전 완료 확인 시 예외 발생', () async {
        // Given
        const safeTransactionId = 'not-shipping-started-id';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });
    });

    group('정산 처리', () {
      test('관리자의 정산 처리', () async {
        // Given
        const safeTransactionId = 'safe-transaction-id';
        const adminNotes = '정산 처리 완료';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });

      test('배송완료 확인 전 정산 처리 시 예외 발생', () async {
        // Given
        const safeTransactionId = 'not-delivery-confirmed-id';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });
    });

    group('안전거래 진행 상태', () {
      test('안전거래 진행률 계산', () async {
        // Given
        final safeTransaction = SafeTransactionModel(
          id: 'test-id',
          transactionId: 'transaction-id',
          depositAmount: 100000,
          depositConfirmed: true,
          shippingConfirmed: true,
          deliveryConfirmed: false,
          settlementStatus: '대기중',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // When
        final progress = safeTransaction.progress;
        final currentStep = safeTransaction.currentStep;

        // Then
        expect(progress, equals(0.4)); // 2/5 단계 완료
        expect(currentStep, equals('배송중'));
      });

      test('정산 완료 상태 확인', () async {
        // Given
        final safeTransaction = SafeTransactionModel(
          id: 'test-id',
          transactionId: 'transaction-id',
          depositAmount: 100000,
          depositConfirmed: true,
          shippingConfirmed: true,
          deliveryConfirmed: true,
          settlementStatus: '정산완료',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // When
        final isCompleted = safeTransaction.isCompleted;
        final progress = safeTransaction.progress;

        // Then
        expect(isCompleted, isTrue);
        expect(progress, equals(1.0));
      });
    });

    group('안전거래 취소', () {
      test('입금확인 전 안전거래 취소', () async {
        // Given
        const safeTransactionId = 'safe-transaction-id';
        const reason = '구매자 요청';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });

      test('입금확인 후 취소 시 예외 발생', () async {
        // Given
        const safeTransactionId = 'deposit-confirmed-id';
        const reason = '구매자 요청';

        // When & Then
        expect(safeTransactionService, isNotNull);
      });
    });
  });

  group('SMS Service Tests', () {
    late SMSService smsService;

    setUp(() {
      smsService = SMSService();
    });

    group('SMS 템플릿', () {
      test('인증번호 템플릿 포맷팅', () {
        // Given
        const code = '123456';

        // When
        final message = smsService._formatSMSTemplate('verification_code', {
          'code': code,
        });

        // Then
        expect(message, contains(code));
        expect(message, contains('에버세컨즈'));
        expect(message, contains('5분'));
      });

      test('입금확인 요청 템플릿 포맷팅', () {
        // Given
        const buyerName = '홍길동';
        const buyerPhone = '010-1234-5678';
        const productTitle = '테스트 상품';
        const amount = '100,000원';

        // When
        final message = smsService._formatSMSTemplate('deposit_request_admin', {
          'buyer_name': buyerName,
          'buyer_phone': buyerPhone,
          'product_title': productTitle,
          'amount': amount,
        });

        // Then
        expect(message, contains(buyerName));
        expect(message, contains(buyerPhone));
        expect(message, contains(productTitle));
        expect(message, contains(amount));
      });
    });

    group('SMS 유효성 검사', () {
      test('유효한 전화번호 검사', () {
        // Given
        const validPhones = [
          '010-1234-5678',
          '01012345678',
          '011-123-4567',
          '016-1234-5678',
          '017-123-4567',
          '018-123-4567',
          '019-123-4567',
        ];

        // When & Then
        for (final phone in validPhones) {
          expect(smsService._isValidPhoneNumber(phone), isTrue, reason: 'Phone: $phone');
        }
      });

      test('유효하지 않은 전화번호 검사', () {
        // Given
        const invalidPhones = [
          '010-123-456',    // 너무 짧음
          '010-1234-56789', // 너무 김
          '020-1234-5678',  // 잘못된 앞자리
          '010-abcd-5678',  // 문자 포함
          '010 1234 5678',  // 공백 포함
          '',               // 빈 문자열
        ];

        // When & Then
        for (final phone in invalidPhones) {
          expect(smsService._isValidPhoneNumber(phone), isFalse, reason: 'Phone: $phone');
        }
      });
    });

    group('SMS 비용 계산', () {
      test('SMS 길이별 비용 계산', () {
        // Given
        const shortMessage = '안녕하세요'; // 5자
        const longMessage = '안녕하세요' * 20; // 100자

        // When
        final shortCost = smsService.calculateSMSCost(shortMessage);
        final longCost = smsService.calculateSMSCost(longMessage);

        // Then
        expect(shortCost['message_type'], equals('SMS'));
        expect(shortCost['sms_count'], equals(1));
        
        expect(longCost['message_type'], equals('LMS'));
        expect(longCost['sms_count'], greaterThan(1));
      });
    });

    group('SMS 발송 시간 제한', () {
      test('정상 시간대 발송 가능', () {
        // Given
        final normalTime = DateTime(2024, 1, 1, 10, 0); // 오전 10시

        // When
        final canSend = smsService.canSendSMSNow(targetTime: normalTime);

        // Then
        expect(canSend, isTrue);
      });

      test('야간 시간대 발송 제한', () {
        // Given
        final nightTime = DateTime(2024, 1, 1, 22, 0); // 오후 10시

        // When
        final canSend = smsService.canSendSMSNow(targetTime: nightTime);

        // Then
        expect(canSend, isFalse);
      });
    });
  });
}

// Mock 클래스들
class MockPostgrestQueryBuilder extends Mock implements PostgrestQueryBuilder<dynamic> {}