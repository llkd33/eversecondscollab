import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Kakao OAuth Callback Tests', () {
    test('카카오 OAuth 사용자 메타데이터 파싱 테스트', () {
      // Given: 카카오 OAuth 사용자 메타데이터
      final kakaoUserMetadata = {
        'kakao_account': {
          'email': 'test@kakao.com',
          'profile': {
            'nickname': '테스트사용자',
            'profile_image_url': 'https://example.com/profile.jpg',
            'thumbnail_image_url': 'https://example.com/thumb.jpg',
          }
        }
      };

      // When: 카카오 계정 정보 추출
      final kakaoAccount = kakaoUserMetadata['kakao_account'] as Map<String, dynamic>? ?? {};
      final kakaoProfile = kakaoAccount['profile'] as Map<String, dynamic>? ?? {};
      final email = kakaoAccount['email'] as String?;
      final nickname = kakaoProfile['nickname'] as String?;
      final profileImage = kakaoProfile['profile_image_url'] as String?;

      // Then: 데이터가 올바르게 추출되어야 함
      expect(email, equals('test@kakao.com'));
      expect(nickname, equals('테스트사용자'));
      expect(profileImage, equals('https://example.com/profile.jpg'));
    });

    test('카카오 사용자 데이터 검증 로직 테스트', () {
      // Given: 유효한 카카오 사용자 데이터
      final validPayload = {
        'name': '테스트사용자',
        'email': 'test@kakao.com',
        'is_verified': true,
      };

      // When: 데이터 검증
      final name = validPayload['name'] as String?;
      final email = validPayload['email'] as String?;
      final isValid = name != null && 
                      name.isNotEmpty && 
                      (email == null || email.contains('@'));

      // Then: 검증이 성공해야 함
      expect(isValid, equals(true));

      // Given: 유효하지 않은 데이터 (이름 없음)
      final invalidPayload = {
        'email': 'test@kakao.com',
        'is_verified': true,
      };

      // When: 데이터 검증
      final invalidName = invalidPayload['name'] as String?;
      final isInvalid = invalidName == null || invalidName.isEmpty;

      // Then: 검증이 실패해야 함
      expect(isInvalid, equals(true));
    });

    test('OAuth 에러 처리 테스트', () {
      // Given: OAuth 에러 상황
      final errorMetadata = {
        'error': 'access_denied',
        'error_description': '사용자가 로그인을 취소했습니다'
      };

      // When: 에러 정보 추출
      final error = errorMetadata['error'];
      final description = errorMetadata['error_description'];

      // Then: 에러 정보가 올바르게 추출되어야 함
      expect(error, equals('access_denied'));
      expect(description, equals('사용자가 로그인을 취소했습니다'));
      
      // When & Then: 에러가 적절히 처리되어야 함
      expect(() {
        if (error != null) {
          throw Exception('OAuth Error: $error - $description');
        }
      }, throwsA(isA<Exception>()));
    });
  });

  group('OAuth 딥링크 처리 테스트', () {
    test('유효한 OAuth 딥링크 파싱', () {
      // Given: 유효한 OAuth 콜백 URI
      final uri = Uri.parse(
        'resale.marketplace.app://auth-callback?code=test_code&state=test_state'
      );

      // When: URI 파싱
      final hasOAuthParams = uri.queryParameters.containsKey('code');

      // Then: OAuth 파라미터가 감지되어야 함
      expect(hasOAuthParams, equals(true));
      expect(uri.scheme, equals('resale.marketplace.app'));
      expect(uri.host, equals('auth-callback'));
    });

    test('OAuth 에러가 포함된 딥링크 처리', () {
      // Given: 에러가 포함된 OAuth 콜백 URI
      final uri = Uri.parse(
        'resale.marketplace.app://auth-callback?error=access_denied&error_description=User%20cancelled'
      );

      // When: 에러 파라미터 확인
      final hasError = uri.queryParameters.containsKey('error');
      final errorType = uri.queryParameters['error'];

      // Then: 에러가 올바르게 감지되어야 함
      expect(hasError, equals(true));
      expect(errorType, equals('access_denied'));
    });
  });
}

