# 🔒 보안 개선 가이드

## ⚠️ 즉시 조치 필요 (CRITICAL)

### 1. API 키 교체 및 보안 설정

#### Step 1: Supabase 키 재발급
1. Supabase Dashboard → Settings → API
2. "Reset" 버튼 클릭하여 새 Anon Key 발급
3. 새 키를 안전하게 보관

#### Step 2: Kakao 키 재발급  
1. Kakao Developers Console → 내 애플리케이션
2. 앱 키 → "재발급" 클릭
3. 모든 키(Native, JavaScript, REST API, Admin) 재발급

#### Step 3: 환경변수 설정
```bash
# .env 파일 생성 (루트 디렉토리에)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...새발급받은키

KAKAO_NATIVE_APP_KEY=새발급받은키
KAKAO_JAVASCRIPT_KEY=새발급받은키  
KAKAO_REST_API_KEY=새발급받은키
KAKAO_ADMIN_KEY=새발급받은키
```

#### Step 4: .gitignore에 추가
```bash
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore
echo ".env.production" >> .gitignore
```

#### Step 5: Config 파일 수정
현재 하드코딩된 키를 환경변수로 대체합니다.

**변경 전 (lib/config/supabase_config.dart):**
```dart
static const String _defaultSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

**변경 후:**
```dart
static String get supabaseAnonKey {
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (key.isEmpty) {
    throw Exception('⚠️ SUPABASE_ANON_KEY must be set in environment variables');
  }
  return key;
}
```

#### Step 6: 빌드 명령 수정
```bash
# 개발 환경
flutter run --dart-define=SUPABASE_URL=$SUPABASE_URL \
            --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
            --dart-define=KAKAO_NATIVE_APP_KEY=$KAKAO_NATIVE_APP_KEY

# 프로덕션 빌드
flutter build apk --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### 2. 민감 정보 로깅 제거

**변경 전:**
```dart
print('사용자 이메일: ${user.email}');
print('사용자 ID: ${user.id}');
```

**변경 후:**
```dart
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

void secureLog(String message, {Object? data}) {
  if (kDebugMode) {
    developer.log(message, name: 'SecureLog');
    // 민감 정보는 로그하지 않음
  }
}

// 사용
secureLog('사용자 로그인 성공'); // ✅ OK
// print('이메일: ${user.email}'); // ❌ NO
```

### 3. 디버그 인증 우회 제거

**파일: lib/providers/auth_provider.dart (19번 줄)**

**변경 전:**
```dart
bool _debugAuthOverride = false;

void debugOverrideAuthState({...}) {
  _currentUser = user;
  _debugAuthOverride = isAuthenticated;
  notifyListeners();
}
```

**변경 후:**
```dart
@visibleForTesting
void debugOverrideAuthState({...}) {
  assert(() {
    _currentUser = user;
    _debugAuthOverride = isAuthenticated;
    notifyListeners();
    return true;
  }());
}
```

## 📋 보안 체크리스트

- [ ] Supabase 키 재발급 완료
- [ ] Kakao 키 재발급 완료
- [ ] .env 파일 생성 및 키 입력
- [ ] .gitignore에 .env 추가
- [ ] Config 파일에서 하드코딩 제거
- [ ] 빌드 스크립트에 환경변수 추가
- [ ] 기존 커밋 히스토리에서 키 제거 (git filter-branch 또는 BFG Repo-Cleaner)
- [ ] GitHub/GitLab Secrets에 환경변수 등록 (CI/CD용)
- [ ] 민감 정보 로깅 제거
- [ ] 디버그 인증 우회 제거

## 🔐 추가 보안 권장사항

### Row Level Security (RLS) 활성화
Supabase Dashboard에서 각 테이블의 RLS를 활성화하고 정책을 설정하세요.

### SSL Pinning (선택사항)
API 통신 보안을 강화하려면 SSL Pinning을 구현하세요.

### 암호화된 로컬 저장소
민감한 데이터는 `flutter_secure_storage` 사용을 권장합니다.
