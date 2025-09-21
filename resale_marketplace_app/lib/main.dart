import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:app_links/app_links.dart';
import 'config/supabase_config.dart';
import 'config/kakao_config.dart';
import 'utils/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
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

  // Supabase 초기화
  await SupabaseConfig.initialize();
  
  // 딥링크 처리 설정 (모바일에서만)
  if (!kIsWeb) {
    final appLinks = AppLinks();
    
    // 앱이 실행 중일 때 딥링크 처리
    appLinks.uriLinkStream.listen((uri) {
      print('🔗 딥링크 수신: $uri');
      // Supabase가 자동으로 처리합니다
    });
    
    // 앱이 종료된 상태에서 딥링크로 시작될 때
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      print('🔗 초기 딥링크: $initialUri');
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Router 초기화 (인증 상태에 따른 리디렉션 처리를 위해)
          AppRouter.router = AppRouter.createRouter(context);

          return SessionMonitor(
            child: MaterialApp.router(
              title: '중고거래 마켓',
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
