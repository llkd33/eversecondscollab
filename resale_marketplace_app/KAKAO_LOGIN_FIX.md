# Kakao OAuth Login Fix for Android

## 문제점
- Android에서 카카오 로그인이 제대로 동작하지 않음
- OAuth 인증 후 사용자 프로필이 생성되지 않음
- 딥링크를 통한 앱 복귀 후 세션이 설정되지 않음

## 해결 방법

### 1. 딥링크 설정 확인 (AndroidManifest.xml)
- `resale.marketplace.app://auth-callback` 딥링크가 올바르게 설정됨
- 카카오 OAuth 콜백용 `kakao0d0b331b737c31682e666aadc2d97763://oauth` 스킴도 설정됨

### 2. OAuth 리다이렉트 URI 수정 (kakao_config.dart)
- Android에서는 항상 고정된 딥링크 사용: `resale.marketplace.app://auth-callback`
- 웹과 모바일 플랫폼별로 다른 리다이렉트 URI 사용

### 3. 딥링크 핸들러 개선 (main.dart)
- AppLinks를 통해 OAuth 콜백 딥링크 수신
- `getSessionFromUrl()`을 호출하여 Supabase 세션 설정
- 앱 실행 중과 콜드 스타트 모두 처리

### 4. 사용자 프로필 자동 생성 (auth_provider.dart, auth_service.dart)
- OAuth 로그인 성공 후 프로필이 없으면 자동 생성
- `ensureUserProfile()` 메소드 추가로 프로필 생성 보장
- 카카오 사용자 정보(닉네임, 프로필 이미지)를 프로필에 저장

### 5. 디버깅 로그 추가
- OAuth 플로우의 각 단계에서 로그 출력
- 문제 발생 시 추적 가능

## 테스트 방법

1. Android 디바이스 또는 에뮬레이터에서 앱 실행
2. 카카오 로그인 버튼 클릭
3. 브라우저에서 카카오 계정으로 로그인
4. 앱으로 자동 리다이렉트 확인
5. 사용자 프로필이 생성되고 홈 화면으로 이동하는지 확인

## 주의사항

### Supabase 설정
1. Supabase Dashboard > Authentication > Providers > Kakao 활성화 확인
2. Client ID와 Client Secret 설정 확인
3. Redirect URL에 다음 항목 추가:
   - Web: `http://localhost:3000/auth/kakao/callback` (개발)
   - Android: `resale.marketplace.app://auth-callback`

### 카카오 개발자 설정
1. 카카오 개발자 콘솔에서 앱 설정 확인
2. Android 플랫폼 등록 및 패키지명 설정
3. Redirect URI에 Supabase 콜백 URL 추가:
   - `https://ewhurbwdqiemeuwdtpeg.supabase.co/auth/v1/callback`

## 변경된 파일
- `lib/config/kakao_config.dart` - 리다이렉트 URI 로직 개선
- `lib/main.dart` - 딥링크 핸들러 추가
- `lib/providers/auth_provider.dart` - 프로필 생성 로직 추가
- `lib/services/auth_service.dart` - ensureUserProfile 메소드 추가, 디버깅 로그 추가

## 디버깅 팁
- `adb logcat | grep -E "flutter|OAuth|딥링크|카카오"` 명령으로 로그 확인
- Chrome 개발자 도구에서 네트워크 탭으로 OAuth 플로우 확인
- Supabase Dashboard의 Auth Logs에서 인증 시도 확인