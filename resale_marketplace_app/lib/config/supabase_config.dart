import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Environment-based configuration. Pass via --dart-define.
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  // ⚠️ SECURITY: 하드코딩된 키는 보안상 위험합니다.
  // 실제 운영 환경에서는 반드시 환경변수를 사용하세요.
  // flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String _defaultSupabaseUrl = '';
  static const String _defaultSupabaseAnonKey = '';

  static String get resolvedSupabaseUrl {
    final raw = supabaseUrl.isNotEmpty ? supabaseUrl : _defaultSupabaseUrl;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    // Automatically normalise missing schemes so redirects stay on HTTPS.
    return 'https://$raw';
  }

  static String get resolvedSupabaseAnonKey =>
      supabaseAnonKey.isNotEmpty ? supabaseAnonKey : _defaultSupabaseAnonKey;

  static String authRedirectUri({String? redirect}) {
    final normalizedBase =
        resolvedSupabaseUrl.replaceAll(RegExp(r'/+$'), '');
    final baseUri = Uri.parse('$normalizedBase/auth/v1/callback');
    final params = Map<String, String>.from(baseUri.queryParameters);

    if (redirect != null && redirect.isNotEmpty) {
      params['redirect'] = redirect;
    } else {
      params.remove('redirect');
    }

    return baseUri
        .replace(queryParameters: params.isEmpty ? null : params)
        .toString();
  }

  // Supabase 클라이언트 초기화
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: resolvedSupabaseUrl,
      anonKey: resolvedSupabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        // 세션 감지 활성화
        detectSessionInUri: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
        eventsPerSecond: 10,
      ),
      storageOptions: const StorageClientOptions(
        retryAttempts: 3,
      ),
    );
  }

  // Supabase 클라이언트 인스턴스 가져오기
  static SupabaseClient get client => Supabase.instance.client;

  // 인증된 사용자 가져오기
  static User? get currentUser => client.auth.currentUser;

  // 인증 상태 스트림
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  // 세션 가져오기
  static Session? get currentSession => client.auth.currentSession;

  // 로그아웃
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
