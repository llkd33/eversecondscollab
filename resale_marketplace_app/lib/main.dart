import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'config/kakao_config.dart';
import 'utils/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/realtime_provider.dart';
import 'services/push_notification_service.dart';
import 'widgets/session_monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 화면 고정 (웹은 미지원이므로 제외)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Firebase 백그라운드 메시지 핸들러 설정 (앱이 완전히 종료된 상태에서 메시지 수신)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Supabase 초기화
  await SupabaseConfig.initialize();
  
  // 딥링크 처리 설정 (모바일에서만)
  if (!kIsWeb) {
    final appLinks = AppLinks();
    
    // 앱이 실행 중일 때 딥링크 처리
    appLinks.uriLinkStream.listen((uri) async {
      print('🔗 딥링크 수신: $uri');
      print('  - Scheme: ${uri.scheme}');
      print('  - Host: ${uri.host}');
      print('  - Path: ${uri.path}');
      print('  - Query: ${uri.query}');
      print('  - Fragment: ${uri.fragment}');
      
      await _handleOAuthDeepLink(uri);
    });
    
    // 앱이 종료된 상태에서 딥링크로 시작될 때
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      print('🔗 초기 딥링크: $initialUri');
      print('  - Scheme: ${initialUri.scheme}');
      print('  - Host: ${initialUri.host}');
      print('  - Fragment: ${initialUri.fragment}');
      
      await _handleOAuthDeepLink(initialUri);
    }
  }

  // Supabase 연결 상태 확인
  final client = SupabaseConfig.client;
  print('✅ Supabase 연결 성공!');
  print('🔑 Auth 상태: ${client.auth.currentUser?.id ?? "Not authenticated"}');

  // 디버그 모드에서만 간단한 연결 테스트 (존재하는 테이블 대상으로)
  if (kDebugMode) {
    try {
      final response = await client.from('products').select('id').limit(1);
      print('📡 DB 연결 테스트(products): ${response.isNotEmpty ? "성공" : "비어있음"}');
    } catch (e) {
      // RLS나 테이블이 없을 수 있으므로 단순 정보 로그로 처리
      print('⚠️ 디버그용 DB 테스트 스킵(권한/스키마 이슈 가능): $e');
    }
  }

  // Kakao SDK 초기화
  if (KakaoConfig.isConfigured) {
    // Web에서는 JavaScript Key가 필요합니다.
    KakaoSdk.init(
      nativeAppKey: KakaoConfig.currentNativeAppKey,
      javaScriptAppKey: kIsWeb ? KakaoConfig.javaScriptKey : null,
      loggingEnabled: kDebugMode,
    );
    if (kDebugMode) {
      KakaoConfig.printDebugInfo();
      if (kIsWeb) {
        // Show exact origin that must be registered in Kakao Developers > Platform > Web
        // Example: http://localhost:8080
        // Note: Port must match.
        // ignore: avoid_print
        print('Kakao Web Origin: ' + Uri.base.origin);
      }
      if (kIsWeb &&
          (KakaoConfig.javaScriptKey.isEmpty ||
              KakaoConfig.javaScriptKey == 'YOUR_KAKAO_JAVASCRIPT_KEY')) {
        print(
          'Warning: Kakao JavaScript key is missing. Set KAKAO_JAVASCRIPT_KEY in .env and add allowed domains in Kakao Developers.',
        );
      }
    }
  } else {
    print(
      'Warning: Kakao SDK is not configured. Please set KAKAO_NATIVE_APP_KEY.',
    );
  }

  runApp(const MyApp());
}

/// OAuth 딥링크 처리 함수
Future<void> _handleOAuthDeepLink(Uri uri) async {
  // OAuth 파라미터 체크 (fragment나 query 모두 체크)
  final hasOAuthParams =
      uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('access_token') ||
      uri.fragment.contains('error_description') ||
      uri.queryParameters.containsKey('error') ||
      uri.fragment.contains('error=');

  if (uri.scheme == 'resale.marketplace.app' &&
      uri.host == 'auth-callback' &&
      hasOAuthParams) {
    print('🔐 OAuth 콜백 감지');

    // 에러 체크 (query parameters와 fragment 모두 확인)
    String? error = uri.queryParameters['error'];
    String? errorCode = uri.queryParameters['error_code'];
    String? errorDescription = uri.queryParameters['error_description'];
    
    // Fragment에서도 에러 확인 (Supabase가 fragment에 에러를 넣는 경우도 있음)
    if (error == null && uri.fragment.contains('error=')) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      error = fragmentParams['error'];
      errorCode = fragmentParams['error_code'];
      errorDescription = fragmentParams['error_description'];
    }
    
    if (error != null) {
      print('❌ OAuth 에러: $error');
      print('  - Error Code: $errorCode');
      print('  - Description: $errorDescription');
      
      // Database error나 server_error의 경우 특별 처리를 하지 않음
      // Supabase SDK가 이를 처리하도록 함
      if (error == 'server_error' && errorCode == 'unexpected_failure') {
        print('⚠️ 서버 측 프로필 생성 오류 감지. Supabase SDK가 처리하도록 계속 진행...');
        // 에러가 있어도 getSessionFromUrl을 호출하여 SDK가 적절히 처리하도록 함
      } else {
        // 다른 에러의 경우 처리 중단
        return;
      }
    }

    try {
      print('🔄 OAuth 세션 처리 시작...');
      await SupabaseConfig.client.auth.getSessionFromUrl(uri);
      final newSession = SupabaseConfig.client.auth.currentSession;

      if (newSession != null) {
        print('✅ OAuth 세션 설정 완료: ${newSession.user?.id}');
        print('  - Email: ${newSession.user?.email}');
        print('  - Provider: ${newSession.user?.appMetadata['provider']}');
        
        // 카카오 OAuth의 경우 추가 로깅
        if (newSession.user?.appMetadata['provider'] == 'kakao') {
          print('🔐 카카오 OAuth 세션 설정 완료');
          print('  - User metadata: ${newSession.user?.userMetadata}');
        }
      } else {
        print('⚠️ OAuth 콜백 처리 후에도 세션이 비어있습니다.');
      }
    } on AuthException catch (e) {
      print('❌ OAuth 세션 처리 실패(AuthException): ${e.message}');
      print('  - Code: ${e.statusCode}');
      print('  - Error: ${e.code}');
      // AuthException은 여기서 처리하지 않고 AuthProvider가 처리하도록 함
    } catch (e, stackTrace) {
      print('❌ OAuth 세션 처리 중 예기치 않은 오류: $e');
      print('  - Stack trace: $stackTrace');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => RealtimeProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Router 초기화 (인증 상태에 따른 리디렉션 처리를 위해)
          AppRouter.router = AppRouter.createRouter(context);

          return SessionMonitor(
            child: MaterialApp.router(
              title: '에버세컨즈',
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              routerConfig: AppRouter.router,
            ),
          );
        },
      ),
    );
  }
}
