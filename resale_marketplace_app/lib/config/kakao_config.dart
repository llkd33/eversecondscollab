class KakaoConfig {
  // 카카오 앱 키 (환경변수에서 가져오기, 없으면 기본값 사용)
  static const String nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: 'YOUR_KAKAO_NATIVE_APP_KEY',
  );
  
  static const String javaScriptKey = String.fromEnvironment(
    'KAKAO_JAVASCRIPT_KEY',
    defaultValue: 'YOUR_KAKAO_JAVASCRIPT_KEY',
  );
  
  static const String restApiKey = String.fromEnvironment(
    'KAKAO_REST_API_KEY',
    defaultValue: 'YOUR_KAKAO_REST_API_KEY',
  );
  
  // 카카오 로그인 Redirect URI
  static const String redirectUri = 'https://everseconds.com/auth/kakao/callback';
  
  // 요청할 사용자 정보 권한
  static const List<String> scopes = [
    'account_email',
    'profile_nickname',
    'profile_image',
    'phone_number',
  ];
  
  // 카카오 SDK 초기화 여부 확인
  static bool get isConfigured => 
      nativeAppKey != 'YOUR_KAKAO_NATIVE_APP_KEY' && 
      nativeAppKey.isNotEmpty;
}