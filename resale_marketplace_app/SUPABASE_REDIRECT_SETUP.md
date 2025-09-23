# Supabase OAuth Redirect URL 설정 가이드

## 문제
Android 앱에서 카카오 로그인 시 localhost로 리다이렉트되는 문제

## 해결 방법

### 1. Supabase Dashboard 설정 (중요!)

1. [Supabase Dashboard](https://supabase.com/dashboard) 접속
2. 프로젝트 선택 → **Authentication** → **URL Configuration**
3. **Redirect URLs** 섹션에서 다음 URL들을 추가:

```
# Android 앱용 딥링크 (필수!)
resale.marketplace.app://auth-callback

# 웹 개발용
http://localhost:3000/auth/kakao/callback

# 웹 프로덕션용 (필요시)
https://your-domain.com/auth/kakao/callback
```

### 2. Kakao Developers 설정

1. [Kakao Developers](https://developers.kakao.com) 접속
2. 내 애플리케이션 → 앱 설정 → 플랫폼
3. **Android 플랫폼** 설정:
   - 패키지명: `com.example.resale_marketplace_app`
   - 키 해시: (디버그/릴리즈 키 해시 추가)

4. **카카오 로그인** → **Redirect URI**에 추가:
```
https://ewhurbwdqiemeuwdtpeg.supabase.co/auth/v1/callback
```

### 3. 키 해시 생성 방법

#### 디버그 키 해시
```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

#### 릴리즈 키 해시
```bash
keytool -exportcert -alias <your-key-alias> -keystore <path-to-keystore> | openssl sha1 -binary | openssl base64
```

### 4. 앱 재빌드 및 테스트

```bash
# 클린 빌드
flutter clean
flutter pub get

# 디버그 모드로 테스트
flutter run

# 또는 새 APK 빌드
flutter build apk --release
```

### 5. 로그 확인

```bash
# OAuth 플로우 로그 확인
adb logcat | grep -E "OAuth|Redirect|딥링크|카카오"
```

## 중요 체크리스트

- [ ] Supabase Dashboard에 `resale.marketplace.app://auth-callback` 추가됨
- [ ] Kakao Developers에 Android 플랫폼 등록됨
- [ ] Kakao Developers에 키 해시 등록됨
- [ ] Kakao Developers의 Redirect URI에 Supabase 콜백 URL 등록됨

## 디버깅 팁

만약 여전히 localhost로 리다이렉트된다면:

1. 브라우저의 개발자 도구 > Network 탭에서 실제 리다이렉트 URL 확인
2. Supabase Dashboard > Authentication > Logs에서 인증 시도 로그 확인
3. `redirectTo` 파라미터가 올바르게 전달되는지 확인

## 예상되는 플로우

1. 앱에서 카카오 로그인 버튼 클릭
2. 외부 브라우저에서 카카오 로그인 페이지 열림
3. 카카오 계정으로 로그인
4. Supabase OAuth 콜백 처리
5. `resale.marketplace.app://auth-callback` 딥링크로 앱으로 복귀
6. 앱이 딥링크를 받아 세션 설정
7. 홈 화면으로 이동