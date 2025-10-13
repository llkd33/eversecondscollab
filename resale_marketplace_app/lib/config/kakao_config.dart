import 'package:flutter/foundation.dart';

import 'supabase_config.dart';
import '../utils/app_logger.dart';

class KakaoConfig {
  // 카카오 앱 키 (환경변수에서 가져오기, 없으면 기본값 사용)
  static const String nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: 'YOUR_KAKAO_NATIVE_APP_KEY',
  );

  static const String javaScriptKey = String.fromEnvironment(
    'KAKAO_JAVASCRIPT_KEY',
    defaultValue: 'bcbbbc27c5bfa788f960c55acdd1c90a',
  );

  static const String restApiKey = String.fromEnvironment(
    'KAKAO_REST_API_KEY',
    defaultValue: '08f48ea45b011427cecdf40eb9988e26',
  );

  // 개발/운영 환경별 설정
  static const String developmentNativeAppKey = String.fromEnvironment(
    'KAKAO_DEV_NATIVE_APP_KEY',
    defaultValue: '0d0b331b737c31682e666aadc2d97763', // 개발용 실제 키
  );

  static const String productionNativeAppKey = String.fromEnvironment(
    'KAKAO_PROD_NATIVE_APP_KEY',
    defaultValue: '0d0b331b737c31682e666aadc2d97763', // 운영용 (동일 키 사용)
  );

  // 현재 환경에 맞는 앱 키 반환
  static String get currentNativeAppKey {
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    if (isProduction) {
      return productionNativeAppKey != 'YOUR_PROD_KAKAO_NATIVE_APP_KEY'
          ? productionNativeAppKey
          : nativeAppKey;
    } else {
      return developmentNativeAppKey != 'YOUR_DEV_KAKAO_NATIVE_APP_KEY'
          ? developmentNativeAppKey
          : nativeAppKey;
    }
  }

  // 카카오 로그인 Redirect URI 기본값 (웹에서 환경에 따라 동적으로 사용)
  static const String redirectUri =
      'http://localhost:3000/auth/kakao/callback'; // Changed to localhost for development

  // 환경 또는 실행 중인 호스트에 맞는 웹 리다이렉트 URI 생성
  static String buildWebRedirectUri({String? redirectPath}) {
    const envRedirect = String.fromEnvironment(
      'KAKAO_WEB_REDIRECT_URI',
      defaultValue: '',
    );

    Uri baseUri;
    if (envRedirect.isNotEmpty) {
      baseUri = Uri.parse(envRedirect);
    } else if (kIsWeb) {
      // Flutter web에서는 현재 호스트를 기준으로 콜백 경로를 구성
      baseUri = Uri.parse(
        Uri.base.origin,
      ).replace(path: '/auth/kakao/callback');
    } else {
      baseUri = Uri.parse(redirectUri);
    }

    final sanitizedRedirect = sanitizeRedirectPath(redirectPath);
    final params = Map<String, String>.from(baseUri.queryParameters);
    if (sanitizedRedirect != null) {
      params['redirect'] = sanitizedRedirect;
    } else {
      params.remove('redirect');
    }

    return baseUri
        .replace(queryParameters: params.isEmpty ? null : params)
        .toString();
  }

  // 모바일 앱에서 Supabase OAuth 콜백으로 사용할 리다이렉트 URI
  // Android에서는 딥링크로 직접 앱으로 돌아오도록 설정
  static const String _fallbackNativeRedirectUri =
      'resale.marketplace.app://auth-callback';

  static String get nativeRedirectUri {
    // 모든 모바일 플랫폼에서 딥링크 사용
    if (!kIsWeb) {
      return _fallbackNativeRedirectUri;
    }
    return _fallbackNativeRedirectUri;
  }

  static String buildNativeRedirectUri({String? redirectPath}) {
    // 모바일 환경에서는 항상 동일한 딥링크 사용
    // Supabase가 OAuth 성공 후 이 딥링크로 리다이렉트하도록 설정
    if (!kIsWeb) {
      // 안드로이드와 iOS 모두 딥링크로 처리
      // redirectPath는 세션 설정 후 앱 내부에서 처리
      return _fallbackNativeRedirectUri;
    }
    
    final sanitized = sanitizeRedirectPath(redirectPath);
    final baseUri = Uri.parse(_fallbackNativeRedirectUri);
    final params = Map<String, String>.from(baseUri.queryParameters);

    if (sanitized != null) {
      params['redirect'] = sanitized;
    } else {
      params.remove('redirect');
    }

    return baseUri
        .replace(queryParameters: params.isEmpty ? null : params)
        .toString();
  }

  // 네이티브 앱에서 사용하는 URL Scheme (실제 사용됨)
  static String get urlScheme => 'kakao$currentNativeAppKey';

  // 요청할 사용자 정보 권한
  static const List<String> scopes = [
    'profile_nickname',
    'profile_image',
    'account_email',
    // 'phone_number', // 전화번호는 선택적으로 사용
  ];

  // 카카오 SDK 초기화 여부 확인
  static bool get isConfigured =>
      currentNativeAppKey != 'YOUR_KAKAO_NATIVE_APP_KEY' &&
      currentNativeAppKey != 'YOUR_DEV_KAKAO_NATIVE_APP_KEY' &&
      currentNativeAppKey != 'YOUR_PROD_KAKAO_NATIVE_APP_KEY' &&
      currentNativeAppKey.isNotEmpty;

  // 디버그 정보 출력
  static void printDebugInfo() {
    final logger = AppLogger.scoped('KakaoConfig');
    logger.i('=== Kakao Config Debug Info ===');
    logger.i('Is Configured: $isConfigured');
    logger.i(
      'Current Native App Key: ${currentNativeAppKey.isNotEmpty ? "${currentNativeAppKey.substring(0, 4)}****" : "Not Set"}',
    );
    final jsKeySet =
        javaScriptKey.isNotEmpty &&
        javaScriptKey != 'YOUR_KAKAO_JAVASCRIPT_KEY';
    logger.i('JavaScript Key Set: $jsKeySet');
    logger.i('Is Production: false'); // Web에서는 항상 false로 설정
    logger.i('==============================');
  }

  static String? sanitizeRedirectPath(String? redirectPath) {
    if (redirectPath == null || redirectPath.isEmpty) {
      return null;
    }

    final decoded = Uri.decodeComponent(redirectPath);
    if (decoded.startsWith('/')) {
      return decoded;
    }

    return null;
  }
}
