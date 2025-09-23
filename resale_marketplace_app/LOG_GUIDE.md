# Android 로그 확인 가이드

## 1. ADB (Android Debug Bridge) 설치 확인

먼저 ADB가 설치되어 있는지 확인:
```bash
adb --version
```

설치되어 있지 않다면:
- Mac: `brew install android-platform-tools`
- Windows: Android SDK Platform Tools 다운로드
- Linux: `sudo apt-get install android-tools-adb`

## 2. 디바이스 연결

### 실제 디바이스 사용 시:
1. Android 설정 → 개발자 옵션 → USB 디버깅 활성화
2. USB 케이블로 컴퓨터와 연결
3. 디바이스에서 USB 디버깅 허용

### 에뮬레이터 사용 시:
Android Studio에서 에뮬레이터 실행

연결된 디바이스 확인:
```bash
adb devices
```

## 3. 실시간 로그 확인 명령어

### 모든 Flutter 로그 보기:
```bash
adb logcat | grep flutter
```

### 카카오 로그인 관련 로그만 보기:
```bash
adb logcat | grep -E "OAuth|딥링크|Auth|Profile|Session|카카오|Kakao"
```

### 더 자세한 로그 (추천):
```bash
adb logcat *:S flutter:V | grep -E "🔗|🔐|✅|❌|⚠️|📝"
```

### 로그를 파일로 저장:
```bash
adb logcat | grep flutter > kakao_login_log.txt
```

## 4. 로그 확인 순서

1. **앱 실행 전 로그 시작**
```bash
# 터미널을 열고 다음 명령 실행
adb logcat -c  # 이전 로그 삭제
adb logcat | grep -E "flutter"
```

2. **앱에서 카카오 로그인 시도**

3. **확인할 주요 로그 패턴**:
- `🔐 Kakao OAuth 시작` - OAuth 시작
- `🔗 딥링크 수신` - 딥링크 콜백 수신
- `Fragment 데이터 있음` - 토큰 데이터 수신
- `Auth State Change: signedIn` - 로그인 성공
- `ensureUserProfile` - 프로필 생성 시도
- `✅ 프로필 로드 성공` - 프로필 생성 완료

## 5. Visual Studio Code에서 로그 확인

VS Code 사용 시:
1. Flutter 앱을 디버그 모드로 실행
2. Debug Console 탭에서 실시간 로그 확인

```bash
# VS Code에서 디버그 실행
flutter run --debug
```

## 6. Android Studio에서 로그 확인

Android Studio 사용 시:
1. 하단의 Logcat 탭 열기
2. 필터에 "flutter" 입력
3. 실시간 로그 확인

## 7. 문제 해결을 위한 로그 레벨

### 간단한 로그:
```bash
adb logcat *:E  # 에러만
adb logcat *:W  # 경고 이상
```

### 상세한 로그:
```bash
adb logcat *:V  # 모든 로그
```

### Flutter 전용:
```bash
flutter logs  # Flutter CLI 사용
```

## 예시 로그 출력

정상적인 카카오 로그인 시 나와야 하는 로그:

```
I/flutter: 🔐 Kakao OAuth 시작
I/flutter: 📱 Platform: Mobile (Android)
I/flutter: 🔗 Redirect URI: resale.marketplace.app://auth-callback
I/flutter: ✅ OAuth 브라우저 열기: true
I/flutter: 🔗 딥링크 수신: resale.marketplace.app://auth-callback#access_token=...
I/flutter:   - Fragment 데이터 있음: access_token=...
I/flutter: 🔐 Auth State Change: signedIn
I/flutter: ✅ User signed in, processing...
I/flutter: 🔍 ensureUserProfile: Checking for user ...
I/flutter: ✅ Profile already exists
I/flutter: ✅ 프로필 로드 성공: 사용자명
```

## 팁

1. **로그가 너무 많을 때**:
```bash
adb logcat | grep -E "🔗|🔐|✅|❌"  # 이모지로 필터링
```

2. **특정 시간 이후 로그만 보기**:
```bash
adb logcat -T "01-01 12:00:00.000"
```

3. **로그 지우고 새로 시작**:
```bash
adb logcat -c && adb logcat | grep flutter
```
