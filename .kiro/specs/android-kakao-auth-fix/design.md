# 안드로이드 카카오 로그인 및 인증 시스템 개선 설계

## 개요

현재 안드로이드 에뮬레이터에서 발생하는 카카오 로그인 문제들을 해결하고, 전반적인 인증 시스템의 안정성과 사용자 경험을 개선하기 위한 설계입니다. OAuth 딥링크 처리, 세션 관리, 에러 핸들링, 그리고 다양한 디바이스 환경에서의 호환성을 강화합니다.

## 아키텍처

### 현재 문제점 분석

1. **딥링크 처리 불안정성**
   - `main.dart`에서 AppLinks 처리가 있지만 에러 핸들링이 부족
   - OAuth 콜백 후 세션 설정 실패 시 재시도 로직 없음
   - 에뮬레이터 환경에서 딥링크 동작 불안정

2. **세션 관리 문제**
   - `AuthProvider`에서 OAuth 완료 후 프로필 생성 지연
   - `ensureUserProfile()` 호출 시점과 UI 업데이트 타이밍 불일치
   - 네트워크 오류 시 세션 복원 실패

3. **에러 핸들링 부족**
   - 카카오 SDK 설정 오류 시 명확한 안내 부족
   - 네트워크 오류와 인증 오류 구분 없음
   - 사용자에게 제공되는 에러 메시지가 기술적

### 개선된 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer                                 │
├─────────────────────────────────────────────────────────────┤
│  LoginScreen  │  AuthProvider  │  SessionMonitor            │
├─────────────────────────────────────────────────────────────┤
│                 Service Layer                               │
├─────────────────────────────────────────────────────────────┤
│  AuthService  │  DeepLinkHandler  │  ErrorHandler           │
├─────────────────────────────────────────────────────────────┤
│                Infrastructure Layer                         │
├─────────────────────────────────────────────────────────────┤
│  KakaoConfig  │  SupabaseConfig  │  NetworkManager          │
└─────────────────────────────────────────────────────────────┘
```

## 컴포넌트 및 인터페이스

### 1. DeepLinkHandler (새로 생성)

OAuth 딥링크 처리를 전담하는 서비스

```dart
class DeepLinkHandler {
  static const String authCallbackScheme = 'resale.marketplace.app';
  static const String authCallbackHost = 'auth-callback';
  
  // 딥링크 처리 상태
  enum DeepLinkStatus {
    pending,
    processing,
    success,
    failed,
    timeout
  }
  
  // 딥링크 처리 결과
  class DeepLinkResult {
    final DeepLinkStatus status;
    final String? errorMessage;
    final Map<String, dynamic>? sessionData;
  }
  
  // 메인 처리 메서드
  Future<DeepLinkResult> handleAuthCallback(Uri uri);
  
  // 타임아웃 처리
  Future<DeepLinkResult> processWithTimeout(Uri uri, Duration timeout);
  
  // 에러 복구
  Future<void> retryAuthCallback(Uri uri);
  
  // 상태 스트림
  Stream<DeepLinkStatus> get statusStream;
}
```

### 2. AuthService 개선

기존 AuthService에 안정성과 에러 핸들링 강화

```dart
class AuthService {
  // 개선된 카카오 로그인
  Future<AuthResult> signInWithKakao({
    String? redirectPath,
    Duration? timeout,
    int maxRetries = 3
  });
  
  // 세션 복원 개선
  Future<SessionRestoreResult> restoreSession({
    bool forceRefresh = false,
    Duration timeout = const Duration(seconds: 10)
  });
  
  // 프로필 생성 개선
  Future<ProfileCreationResult> ensureUserProfileWithRetry({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1)
  });
  
  // 네트워크 상태 확인
  Future<bool> checkNetworkConnectivity();
  
  // 환경별 설정 검증
  Future<ConfigValidationResult> validateConfiguration();
}
```

### 3. ErrorHandler (새로 생성)

통합 에러 처리 및 사용자 친화적 메시지 제공

```dart
class ErrorHandler {
  // 에러 타입 분류
  enum AuthErrorType {
    networkError,
    configurationError,
    kakaoSdkError,
    deepLinkError,
    sessionError,
    profileCreationError,
    unknownError
  }
  
  // 에러 분석
  AuthErrorType analyzeError(dynamic error);
  
  // 사용자 친화적 메시지 생성
  String getUserFriendlyMessage(AuthErrorType type, {String? details});
  
  // 복구 제안
  List<RecoveryAction> getRecoveryActions(AuthErrorType type);
  
  // 개발자용 상세 로그
  void logDetailedError(dynamic error, StackTrace? stackTrace);
}
```

### 4. NetworkManager (새로 생성)

네트워크 상태 모니터링 및 재시도 로직

```dart
class NetworkManager {
  // 네트워크 상태 확인
  Future<bool> isConnected();
  
  // 연결 품질 확인
  Future<ConnectionQuality> checkConnectionQuality();
  
  // 재시도 로직
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation,
    {int maxRetries = 3, Duration delay = const Duration(seconds: 1)}
  );
  
  // 네트워크 상태 스트림
  Stream<NetworkStatus> get networkStatusStream;
}
```

### 5. AuthProvider 개선

상태 관리 및 UI 업데이트 최적화

```dart
class AuthProvider extends ChangeNotifier {
  // 로그인 상태 세분화
  enum AuthState {
    initial,
    loading,
    authenticating,
    profileLoading,
    authenticated,
    error,
    sessionExpired
  }
  
  // 개선된 카카오 로그인
  Future<bool> signInWithKakaoImproved({
    String? redirectPath,
    Function(String)? onStatusUpdate
  });
  
  // 세션 복원 개선
  Future<void> restoreSessionImproved();
  
  // 에러 상태 관리
  void handleAuthError(AuthErrorType type, String message);
  
  // 상태 변경 알림 최적화
  void notifyAuthStateChange(AuthState newState);
}
```

## 데이터 모델

### 1. AuthResult

인증 결과를 나타내는 모델

```dart
class AuthResult {
  final bool success;
  final AuthErrorType? errorType;
  final String? errorMessage;
  final UserModel? user;
  final Duration? processingTime;
  final Map<String, dynamic>? metadata;
  
  // 성공 여부 확인
  bool get isSuccess => success && user != null;
  
  // 재시도 가능 여부
  bool get canRetry => errorType != AuthErrorType.configurationError;
}
```

### 2. SessionRestoreResult

세션 복원 결과

```dart
class SessionRestoreResult {
  final bool restored;
  final UserModel? user;
  final String? errorMessage;
  final bool needsReauth;
  final Duration? sessionExpiresIn;
}
```

### 3. ConfigValidationResult

설정 검증 결과

```dart
class ConfigValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> configStatus;
  
  // 카카오 SDK 설정 상태
  bool get kakaoConfigValid;
  
  // Supabase 설정 상태  
  bool get supabaseConfigValid;
  
  // 딥링크 설정 상태
  bool get deepLinkConfigValid;
}
```

## 에러 핸들링

### 에러 분류 및 처리 전략

1. **네트워크 에러**
   - 자동 재시도 (최대 3회)
   - 연결 상태 확인 후 재시도
   - 오프라인 모드 안내

2. **설정 에러**
   - 개발자에게 명확한 설정 가이드 제공
   - 런타임 설정 검증
   - 대체 인증 방법 제안

3. **카카오 SDK 에러**
   - 카카오 특정 에러 코드 매핑
   - 사용자 친화적 메시지 변환
   - SMS 인증으로 폴백

4. **딥링크 에러**
   - 타임아웃 처리 (10초)
   - 수동 세션 복원 시도
   - 브라우저 재시도 옵션

### 에러 메시지 매핑

```dart
const Map<AuthErrorType, String> errorMessages = {
  AuthErrorType.networkError: '인터넷 연결을 확인해주세요',
  AuthErrorType.configurationError: '앱 설정에 문제가 있습니다. 관리자에게 문의해주세요',
  AuthErrorType.kakaoSdkError: '카카오 로그인에 문제가 발생했습니다',
  AuthErrorType.deepLinkError: '로그인 처리 중 오류가 발생했습니다',
  AuthErrorType.sessionError: '로그인 세션에 문제가 있습니다',
  AuthErrorType.profileCreationError: '사용자 정보 생성 중 오류가 발생했습니다',
};
```

## 테스트 전략

### 1. 단위 테스트

- `DeepLinkHandler` 각 메서드별 테스트
- `ErrorHandler` 에러 분류 및 메시지 생성 테스트
- `NetworkManager` 재시도 로직 테스트
- `AuthService` 개선된 메서드들 테스트

### 2. 통합 테스트

- OAuth 플로우 전체 시나리오 테스트
- 네트워크 오류 상황 시뮬레이션
- 에뮬레이터 환경 특화 테스트
- 세션 복원 시나리오 테스트

### 3. 에뮬레이터 테스트

- 다양한 Android API 레벨에서 테스트
- 네트워크 지연 시뮬레이션
- 딥링크 처리 안정성 테스트
- 메모리 부족 상황 테스트

### 4. 성능 테스트

- 로그인 완료 시간 측정 (목표: 3초 이내)
- 메모리 사용량 모니터링
- 배터리 소모량 측정
- 네트워크 사용량 최적화

## 보안 고려사항

### 1. 토큰 관리

- 액세스 토큰 안전한 저장 (Android Keystore 활용)
- 리프레시 토큰 자동 갱신
- 토큰 만료 시 자동 로그아웃

### 2. 딥링크 보안

- 딥링크 URL 검증 강화
- 악성 딥링크 차단
- 세션 하이재킹 방지

### 3. 개인정보 보호

- 최소 권한 요청 (카카오 프로필, 이메일만)
- 민감 정보 로컬 암호화
- 로그아웃 시 완전한 데이터 삭제

## 성능 최적화

### 1. 로딩 시간 단축

- 병렬 처리를 통한 프로필 로드 최적화
- 이미지 캐싱 및 지연 로딩
- 불필요한 API 호출 제거

### 2. 메모리 최적화

- 이미지 메모리 사용량 최적화
- 사용하지 않는 리소스 해제
- 메모리 누수 방지

### 3. 네트워크 최적화

- 요청 압축 및 캐싱
- 배치 요청으로 API 호출 최소화
- 오프라인 모드 지원

## 사용자 경험 개선

### 1. 로딩 상태 표시

- 단계별 로딩 메시지
- 진행률 표시
- 취소 옵션 제공

### 2. 에러 복구 가이드

- 단계별 문제 해결 가이드
- 대체 로그인 방법 안내
- 고객 지원 연결

### 3. 접근성 개선

- 스크린 리더 지원
- 고대비 모드 지원
- 큰 글씨 모드 지원

## 모니터링 및 분석

### 1. 로그 수집

- 인증 단계별 로그 수집
- 에러 발생 빈도 추적
- 성능 메트릭 수집

### 2. 사용자 행동 분석

- 로그인 성공률 추적
- 에러 발생 패턴 분석
- 사용자 이탈 지점 파악

### 3. A/B 테스트

- 다양한 로그인 플로우 테스트
- 에러 메시지 효과성 테스트
- UI/UX 개선 효과 측정