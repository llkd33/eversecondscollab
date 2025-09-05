import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Environment-based configuration. Pass via --dart-define.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  // Supabase 클라이언트 초기화
  static Future<void> initialize() async {
    final url = supabaseUrl.isNotEmpty ? supabaseUrl : 'https://ewhurbwdqiemeuwdtpeg.supabase.co';
    final anon = supabaseAnonKey.isNotEmpty ? supabaseAnonKey : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3aHVyYndkcWllbWV1d2R0cGVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzNzk5MzcsImV4cCI6MjA3MTk1NTkzN30.CKQh2HqJWzadYgxoaqaBKFuJd9n6Zz54eSueVkR6GmQ';
    await Supabase.initialize(
      url: url,
      anonKey: anon,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
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
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // 세션 가져오기
  static Session? get currentSession => client.auth.currentSession;

  // 로그아웃
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
