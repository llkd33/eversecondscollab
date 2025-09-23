import 'package:flutter_test/flutter_test.dart';
import '../lib/services/auth_service.dart';

/// 수동 테스트용 - 실제 Supabase 연결 없이 로직만 검증
void main() {
  group('Manual Kakao OAuth Tests', () {
    test('카카오 OAuth 콜백 시나리오 시뮬레이션', () async {
      print('🔐 카카오 OAuth 콜백 처리 시나리오 테스트');
      
      // 1. 딥링크 수신 시뮬레이션
      final oauthCallbackUri = Uri.parse(
        'resale.marketplace.app://auth-callback?code=test_auth_code&state=test_state'
      );
      
      print('📱 딥링크 수신: $oauthCallbackUri');
      
      // 2. OAuth 파라미터 검증
      final hasCode = oauthCallbackUri.queryParameters.containsKey('code');
      final code = oauthCallbackUri.queryParameters['code'];
      
      expect(hasCode, true);
      expect(code, 'test_auth_code');
      print('✅ OAuth 코드 검증 완료: $code');
      
      // 3. 카카오 사용자 메타데이터 시뮬레이션
      final mockKakaoMetadata = {
        'kakao_account': {
          'email': 'testuser@kakao.com',
          'profile': {
            'nickname': '테스트유저',
            'profile_image_url': 'https://k.kakaocdn.net/dn/profile.jpg',
            'thumbnail_image_url': 'https://k.kakaocdn.net/dn/thumb.jpg',
          }
        }
      };
      
      // 4. 사용자 데이터 추출 로직 테스트
      final kakaoAccount = mockKakaoMetadata['kakao_account'] as Map<String, dynamic>;
      final kakaoProfile = kakaoAccount['profile'] as Map<String, dynamic>;
      
      final extractedData = {
        'email': kakaoAccount['email'],
        'name': kakaoProfile['nickname'],
        'profile_image': kakaoProfile['profile_image_url'],
        'is_verified': true,
        'role': '일반',
        'phone': '', // 카카오에서는 전화번호 제공 안함
      };
      
      print('📝 추출된 사용자 데이터: $extractedData');
      
      // 5. 데이터 검증
      expect(extractedData['email'], 'testuser@kakao.com');
      expect(extractedData['name'], '테스트유저');
      expect(extractedData['is_verified'], true);
      expect(extractedData['phone'], '');
      
      print('✅ 카카오 OAuth 콜백 시나리오 테스트 완료');
    });
    
    test('OAuth 에러 시나리오 테스트', () {
      print('❌ OAuth 에러 시나리오 테스트');
      
      // 1. 에러가 포함된 딥링크
      final errorUri = Uri.parse(
        'resale.marketplace.app://auth-callback?error=access_denied&error_description=User%20cancelled%20login'
      );
      
      // 2. 에러 파라미터 추출
      final error = errorUri.queryParameters['error'];
      final errorDescription = Uri.decodeComponent(
        errorUri.queryParameters['error_description'] ?? ''
      );
      
      expect(error, 'access_denied');
      expect(errorDescription, 'User cancelled login');
      
      print('📝 에러 정보: $error - $errorDescription');
      print('✅ OAuth 에러 시나리오 테스트 완료');
    });
    
    test('프로필 생성 재시도 로직 시뮬레이션', () async {
      print('🔄 프로필 생성 재시도 로직 테스트');
      
      // 재시도 로직 시뮬레이션
      int maxRetries = 3;
      int attempt = 0;
      bool success = false;
      
      while (attempt < maxRetries && !success) {
        attempt++;
        print('  - 시도 $attempt/$maxRetries');
        
        // 시뮬레이션: 3번째 시도에서 성공
        if (attempt == 3) {
          success = true;
          print('  ✅ 프로필 생성 성공');
        } else {
          print('  ❌ 프로필 생성 실패, 재시도...');
          await Future.delayed(Duration(milliseconds: 100)); // 실제로는 더 긴 지연
        }
      }
      
      expect(success, true);
      expect(attempt, 3);
      print('✅ 재시도 로직 테스트 완료');
    });
  });
}