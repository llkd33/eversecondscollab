import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/config/kakao_config.dart';
import 'package:resale_marketplace_app/models/user_model.dart';

void main() {
  group('Authentication Configuration Tests', () {
    test('Kakao configuration validation', () {
      // Test Kakao configuration
      expect(KakaoConfig.nativeAppKey, isNotEmpty);
      expect(KakaoConfig.javaScriptKey, isNotEmpty);
      expect(KakaoConfig.redirectUri, isNotEmpty);
      expect(KakaoConfig.scopes, isNotEmpty);
      expect(KakaoConfig.scopes.length, greaterThan(0));
    });

    test('Kakao configuration check', () {
      // Test configuration check method
      final isConfigured = KakaoConfig.isConfigured;
      expect(isConfigured, isA<bool>());
    });
  });

  group('User Model Tests', () {
    test('Valid user model creation', () {
      // Test valid user model creation
      final user = UserModel(
        id: 'test-id',
        email: 'test@example.com',
        name: 'Test User',
        phone: '010-1234-5678',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(user.id, equals('test-id'));
      expect(user.email, equals('test@example.com'));
      expect(user.name, equals('Test User'));
      expect(user.phone, equals('010-1234-5678'));
      expect(user.isVerified, isFalse);
      expect(user.role, equals('일반'));
    });

    test('User model validation - invalid email', () {
      // Test invalid email validation
      expect(() {
        UserModel(
          id: 'test-id',
          email: 'invalid-email',
          name: 'Test User',
          phone: '010-1234-5678',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }, throwsArgumentError);
    });

    test('User model validation - invalid phone', () {
      // Test invalid phone validation
      expect(() {
        UserModel(
          id: 'test-id',
          email: 'test@example.com',
          name: 'Test User',
          phone: 'invalid-phone',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }, throwsArgumentError);
    });

    test('User role validation', () {
      // Test user role validation
      expect(UserRole.isValid('일반'), isTrue);
      expect(UserRole.isValid('대신판매자'), isTrue);
      expect(UserRole.isValid('관리자'), isTrue);
      expect(UserRole.isValid('invalid-role'), isFalse);
    });

    test('User helper methods', () {
      final user = UserModel(
        id: 'test-id',
        email: 'test@example.com',
        name: 'Test User',
        phone: '01012345678',
        role: '관리자',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(user.isAdmin, isTrue);
      expect(user.isReseller, isTrue);
      expect(user.isGeneralUser, isFalse);
      expect(user.formattedPhone, equals('010-1234-5678'));
    });

    test('User copyWith method', () {
      final user = UserModel(
        id: 'test-id',
        email: 'test@example.com',
        name: 'Test User',
        phone: '010-1234-5678',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedUser = user.copyWith(name: 'Updated User');
      
      expect(updatedUser.name, equals('Updated User'));
      expect(updatedUser.id, equals(user.id));
      expect(updatedUser.email, equals(user.email));
    });

    test('User JSON serialization', () {
      final user = UserModel(
        id: 'test-id',
        email: 'test@example.com',
        name: 'Test User',
        phone: '010-1234-5678',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = user.toJson();
      final userFromJson = UserModel.fromJson(json);

      expect(userFromJson.id, equals(user.id));
      expect(userFromJson.email, equals(user.email));
      expect(userFromJson.name, equals(user.name));
      expect(userFromJson.phone, equals(user.phone));
    });
  });

  group('Phone Number Validation Tests', () {
    test('Valid phone number formats', () {
      final validPhones = [
        '010-1234-5678',
        '011-1234-5678',
        '016-1234-5678',
        '017-1234-5678',
        '018-1234-5678',
        '019-1234-5678',
      ];

      for (final phone in validPhones) {
        expect(() {
          UserModel(
            id: 'test-id',
            email: 'test@example.com',
            name: 'Test User',
            phone: phone,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }, returnsNormally, reason: 'Phone $phone should be valid');
      }
    });

    test('Invalid phone number formats', () {
      final invalidPhones = [
        '010-123-5678',    // Too short
        '010-12345-5678',  // Too long middle part
        '020-1234-5678',   // Invalid prefix
        '010-1234-567',    // Too short last part
        '010-1234-56789',  // Too long last part
        'invalid-phone',   // Completely invalid
      ];

      for (final phone in invalidPhones) {
        expect(() {
          UserModel(
            id: 'test-id',
            email: 'test@example.com',
            name: 'Test User',
            phone: phone,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }, throwsArgumentError, reason: 'Phone $phone should be invalid');
      }
    });
  });
}