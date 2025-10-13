import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:resale_marketplace_app/services/account_encryption_service.dart';

void main() {
  setUpAll(() async {
    // Load test environment variables
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: '''
ENCRYPTION_KEY=test_key_for_unit_testing_only_32chars
''');
  });

  group('AccountEncryptionService', () {
    test('should encrypt and decrypt account number correctly', () {
      const accountNumber = '1234567890123';

      final encrypted = AccountEncryptionService.encryptAccountNumber(accountNumber);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(accountNumber));

      final decrypted = AccountEncryptionService.decryptAccountNumber(encrypted);
      expect(decrypted, equals(accountNumber));
    });

    test('should handle account numbers with hyphens', () {
      const accountNumber = '1234-5678-90123';

      final encrypted = AccountEncryptionService.encryptAccountNumber(accountNumber);
      final decrypted = AccountEncryptionService.decryptAccountNumber(encrypted);

      // Should strip hyphens during encryption
      expect(decrypted, equals('1234567890123'));
    });

    test('should throw on empty account number', () {
      expect(
        () => AccountEncryptionService.encryptAccountNumber(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw on short account number', () {
      expect(
        () => AccountEncryptionService.encryptAccountNumber('12345'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should mask account number correctly', () {
      const accountNumber = '1234567890123';
      final masked = AccountEncryptionService.maskAccountNumber(accountNumber);

      expect(masked, equals('*********0123'));
      expect(masked.length, equals(13));
    });

    test('should validate account numbers correctly', () {
      expect(AccountEncryptionService.isValidAccountNumber('1234567890123'), isTrue);
      expect(AccountEncryptionService.isValidAccountNumber('123-456-7890'), isTrue);
      expect(AccountEncryptionService.isValidAccountNumber('123'), isFalse);
      expect(AccountEncryptionService.isValidAccountNumber('1111111111111111'), isFalse);
      expect(AccountEncryptionService.isValidAccountNumber(''), isFalse);
    });

    test('should format account number correctly', () {
      expect(
        AccountEncryptionService.formatAccountNumber('1234567890123'),
        equals('1234-567-890123'),
      );
    });

    test('encrypted data should be different each time (random IV)', () {
      const accountNumber = '1234567890123';

      final encrypted1 = AccountEncryptionService.encryptAccountNumber(accountNumber);
      final encrypted2 = AccountEncryptionService.encryptAccountNumber(accountNumber);

      // Different IVs should produce different encrypted outputs
      expect(encrypted1, isNot(equals(encrypted2)));

      // But both should decrypt to same value
      expect(
        AccountEncryptionService.decryptAccountNumber(encrypted1),
        equals(accountNumber),
      );
      expect(
        AccountEncryptionService.decryptAccountNumber(encrypted2),
        equals(accountNumber),
      );
    });

    test('should throw on malformed encrypted data', () {
      expect(
        () => AccountEncryptionService.decryptAccountNumber('invalid_data'),
        throwsA(isA<Exception>()),
      );
    });

    test('should generate data hash correctly', () {
      const data = 'test_data';
      final hash1 = AccountEncryptionService.generateDataHash(data);
      final hash2 = AccountEncryptionService.generateDataHash(data);

      // Same input should produce same hash
      expect(hash1, equals(hash2));
      expect(hash1, isNotEmpty);

      // Different input should produce different hash
      final hash3 = AccountEncryptionService.generateDataHash('different_data');
      expect(hash1, isNot(equals(hash3)));
    });
  });

  group('AccountAccessControl', () {
    test('should allow owner to view their account', () {
      const userId = 'user_123';
      expect(
        AccountAccessControl.canViewAccount(userId, userId),
        isTrue,
      );
    });

    test('should deny access to other users account without transaction', () {
      const userId1 = 'user_123';
      const userId2 = 'user_456';

      expect(
        AccountAccessControl.canViewAccount(userId1, userId2),
        isFalse,
      );
    });
  });
}
