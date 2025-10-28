import 'package:flutter/foundation.dart';

import 'supabase_config.dart';

class KakaoConfig {
  // 카카오 앱 키 (환경변수에서 가져오기, 없으면 기본값 사용)
  static const String nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: 'd7hGLkmnlxhgv11Ww1dlae11fQX7wxW5',
  );

  // ⚠️ SECURITY: 하드코딩된 키는 보안상 위험합니다.
  // 실제 운영 환경에서는 반드시 환경변수를 사용하세요.
  static const String javaScriptKey = String.fromEnvironment(
    'KAKAO_JAVASCRIPT_KEY',
    defaultValue: 'bcbbbc27c5bfa788f960c55acdd1c90a',
  );

  static const String restApiKey = String.fromEnvironment(
    'KAKAO_REST_API_KEY',
    defaultValue: '',
  );

  // 개발/운영 환경별 설정
  static const String developmentNativeAppKey = String.fromEnvironment(
    'KAKAO_DEV_NATIVE_APP_KEY',
    defaultValue: 'd7hGLkmnlxhgv11Ww1dlae11fQX7wxW5',
  );

  static const String productionNativeAppKey = String.fromEnvironment(
    'KAKAO_PROD_NATIVE_APP_KEY',
    defaultValue: 'd7hGLkmnlxhgv11Ww1dlae11fQX7wxW5',
  );

  // 현재 환경에 맞는 앱 키 반환
  static String get currentNativeAppKey {
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    if (isProduction) {
      // 운영 환경: KAKAO_PROD_NATIVE_APP_KEY -> KAKAO_NATIVE_APP_KEY 순서로 확인
      if (productionNativeAppKey.isNotEmpty &&
          productionNativeAppKey != 'YOUR_PROD_KAKAO_NATIVE_APP_KEY') {
        return productionNativeAppKey;
      }
      return nativeAppKey;
    } else {
      // 개발 환경: KAKAO_DEV_NATIVE_APP_KEY -> KAKAO_NATIVE_APP_KEY 순서로 확인
      if (developmentNativeAppKey.isNotEmpty &&
          developmentNativeAppKey != 'YOUR_DEV_KAKAO_NATIVE_APP_KEY') {
        return developmentNativeAppKey;
      }
      return nativeAppKey;
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
    print('=== Kakao Config Debug Info ===');
    print('Is Configured: $isConfigured');
    print(
      'Current Native App Key: ${currentNativeAppKey.isNotEmpty ? "${currentNativeAppKey.substring(0, 4)}****" : "Not Set"}',
    );
    final jsKeySet =
        javaScriptKey.isNotEmpty &&
        javaScriptKey != 'YOUR_KAKAO_JAVASCRIPT_KEY';
    print('JavaScript Key Set: $jsKeySet');
    print('Is Production: false'); // Web에서는 항상 false로 설정
    print('==============================');
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
