import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'utils/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'widgets/session_monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 세로 화면 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Supabase 초기화
  await SupabaseConfig.initialize();
  
  // Kakao SDK 초기화 (필요시 추가)
  
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