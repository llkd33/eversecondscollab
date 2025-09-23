# 카카오 OAuth 콜백 처리 개선 사항

## 개요
카카오 로그인 OAuth 콜백 후 사용자 프로필 생성 로직을 완성하고, 프로필 생성 실패 시 재시도 로직을 구현하며, 자동 리다이렉트 처리를 개선했습니다.

## 주요 개선 사항

### 1. 사용자 프로필 생성 로직 개선

#### 1.1 재시도 로직 구현
- `ensureUserProfile()` 메서드에 `maxRetries` 파라미터 추가
- 프로필 생성 실패 시 최대 3회까지 재시도
- 각 시도 간 지연 시간 증가 (exponential backoff)
- 생성 후 검증 로직 추가

```dart
Future<bool> ensureUserProfile({int maxRetries = 3}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    // 프로필 생성 시도
    // 실패 시 지연 후 재시도
  }
}
```

#### 1.2 카카오 사용자 데이터 처리 개선
- 카카오 OAuth 전용 데이터 추출 로직 분리
- `_buildKakaoUserPayload()` 메서드 추가
- 카카오 계정 정보에서 이메일, 닉네임, 프로필 이미지 추출
- 데이터 검증 로직 강화

```dart
Map<String, dynamic> _buildKakaoUserPayload(User user, Map<String, dynamic> metadata) {
  final kakaoAccount = metadata['kakao_account'] ?? {};
  final kakaoProfile = kakaoAccount['profile'] ?? {};
  
  // 카카오 데이터 추출 및 검증
}
```

#### 1.3 RPC 함수를 통한 안전한 프로필 생성
- `create_user_profile_safe` RPC 함수 생성
- RLS(Row Level Security) 우회를 위한 SECURITY DEFINER 사용
- 중복 데이터 처리 로직 포함
- 에러 처리 및 결과 반환 개선

### 2. OAuth 콜백 화면 개선

#### 2.1 콜백 처리 로직 강화
- 상세한 로깅 추가
- 에러 처리 개선
- AuthProvider와의 연동 강화
- 프로필 생성 확인 로직 추가

```dart
Future<void> _handleCallback() async {
  // OAuth 세션 처리
  await Supabase.instance.client.auth.getSessionFromUrl(callbackUri);
  
  // AuthProvider를 통한 프로필 처리
  final authProvider = context.read<AuthProvider>();
  await authProvider.tryAutoLogin();
  
  // 리다이렉트 처리
}
```

### 3. AuthProvider 개선

#### 3.1 OAuth 로그인 이벤트 처리
- `_handleSignInEvent()` 메서드 추가
- OAuth와 일반 로그인 구분 처리
- 프로필 생성 재시도 로직 통합

```dart
Future<void> _handleSignInEvent(User authUser) async {
  final provider = authUser.appMetadata['provider'] as String?;
  final isOAuth = provider != null && provider != 'email';
  
  if (isOAuth) {
    // OAuth 전용 처리 로직
    final profileCreated = await _authService.ensureUserProfile(maxRetries: 3);
  }
}
```

### 4. 딥링크 처리 개선

#### 4.1 OAuth 딥링크 처리 함수 분리
- `_handleOAuthDeepLink()` 함수 추가
- 에러 체크 로직 강화
- 카카오 OAuth 전용 로깅 추가

```dart
Future<void> _handleOAuthDeepLink(Uri uri) async {
  // OAuth 파라미터 확인
  // 에러 체크
  // 세션 처리
  // 카카오 OAuth 전용 로깅
}
```

### 5. 데이터베이스 개선

#### 5.1 RPC 함수 생성
- `create_user_profile_safe` 함수 추가
- RLS 우회를 통한 안전한 프로필 생성
- 중복 데이터 처리
- JSON 형태의 결과 반환

```sql
CREATE OR REPLACE FUNCTION create_user_profile_safe(
  user_id UUID,
  user_email TEXT DEFAULT NULL,
  user_name TEXT DEFAULT '',
  -- 기타 파라미터들
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
```

## 테스트 구현

### 1. 단위 테스트
- 카카오 OAuth 메타데이터 파싱 테스트
- 사용자 데이터 검증 로직 테스트
- OAuth 에러 처리 테스트
- 딥링크 파싱 테스트

### 2. 통합 테스트
- OAuth 콜백 시나리오 시뮬레이션
- 프로필 생성 재시도 로직 테스트
- 에러 시나리오 테스트

## 주요 요구사항 충족

### 요구사항 1.1: 카카오 OAuth 사용자 정보 저장
✅ 카카오에서 받은 사용자 정보를 Supabase users 테이블에 저장하는 로직 완성
- 이메일, 닉네임, 프로필 이미지 추출 및 저장
- 전화번호는 빈 값으로 처리 (카카오에서 제공하지 않음)

### 요구사항 1.4: 사용자 ID 관리
✅ 카카오 로그인 시 이메일을 사용자 ID로 활용
- 카카오 이메일이 없으면 synthetic 이메일 생성
- 중복 방지 로직 구현

### 요구사항 1.5: 사용자 정보 저장
✅ name, phone, is_verified, profile_image, role 저장
- 카카오 OAuth는 항상 is_verified = true
- 기본 role = '일반'
- 프로필 이미지 URL 저장

## 개선된 플로우

1. **카카오 로그인 시작**
   - 사용자가 카카오 로그인 버튼 클릭
   - Supabase OAuth 페이지로 리다이렉트

2. **OAuth 콜백 처리**
   - 딥링크로 앱 복귀
   - OAuth 세션 설정
   - 사용자 메타데이터 추출

3. **프로필 생성**
   - 카카오 데이터 검증
   - RPC 함수를 통한 안전한 프로필 생성
   - 실패 시 재시도 (최대 3회)

4. **자동 리다이렉트**
   - 프로필 생성 완료 후 홈 화면으로 이동
   - 에러 발생 시 로그인 화면으로 이동

## 에러 처리 개선

- OAuth 에러 (access_denied, invalid_request 등) 처리
- 프로필 생성 실패 시 재시도 로직
- 네트워크 오류 처리
- RLS 정책 오류 우회

## 로깅 개선

- 각 단계별 상세 로깅 추가
- 카카오 OAuth 전용 로깅
- 에러 상황별 구체적인 로그 메시지
- 디버깅을 위한 메타데이터 출력

## 다음 단계

1. **실제 환경 테스트**
   - 카카오 개발자 콘솔에서 리다이렉트 URI 등록
   - 실제 디바이스에서 OAuth 플로우 테스트

2. **SMS 인증 시스템 연동**
   - 다음 우선순위 태스크
   - 전화번호 기반 회원가입 완성

3. **성능 최적화**
   - 프로필 생성 속도 개선
   - 캐싱 로직 추가

이번 개선으로 카카오 OAuth 콜백 처리가 안정적이고 신뢰할 수 있게 되었으며, 사용자 경험이 크게 향상되었습니다.