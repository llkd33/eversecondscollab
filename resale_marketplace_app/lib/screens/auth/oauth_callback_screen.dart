import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';

class OAuthCallbackScreen extends StatefulWidget {
  final String? provider;
  final String? code;
  final String? error;
  final String? redirectPath;

  const OAuthCallbackScreen({
    super.key,
    this.provider,
    this.code,
    this.error,
    this.redirectPath,
  });

  @override
  State<OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends State<OAuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  Future<void> _handleCallback() async {
    final callbackUri = Uri.base;
    final params = _collectParams(callbackUri);

    final error =
        widget.error ?? params['error'] ?? params['error_description'];

    if (error != null && error.isNotEmpty) {
      print('❌ OAuth 콜백 에러: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('인증 오류: $error')));
        context.go('/login');
      }
      return;
    }

    final hasOAuthParams =
        params.containsKey('code') || params.containsKey('access_token');

    // If we already have an active session and no OAuth params, just redirect.
    if (!hasOAuthParams &&
        Supabase.instance.client.auth.currentSession != null) {
      print('✅ 기존 세션 존재, 리다이렉트 처리');
      if (mounted) {
        context.go(_resolveRedirect(params['redirect'] ?? widget.redirectPath));
      }
      return;
    }

    try {
      print('🔐 OAuth 콜백 처리 시작...');
      print('  - URI: $callbackUri');
      print('  - Has OAuth params: $hasOAuthParams');
      
      // Supabase에서 OAuth 세션 처리
      await Supabase.instance.client.auth.getSessionFromUrl(callbackUri);
      
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.user != null) {
        print('✅ OAuth 세션 설정 완료');
        print('  - User ID: ${session!.user!.id}');
        print('  - Provider: ${session.user!.appMetadata['provider']}');
        print('  - Email: ${session.user!.email}');
      } else {
        print('⚠️ OAuth 세션 설정 후에도 사용자 정보가 없습니다');
      }

      if (!mounted) return;
      
      // AuthProvider를 통해 프로필 생성 및 로드 처리
      try {
        print('🔄 AuthProvider를 통한 프로필 처리 시작...');
        final authProvider = context.read<AuthProvider>();
        
        // 프로필 생성 및 로드를 위해 약간의 지연
        await Future.delayed(const Duration(milliseconds: 500));
        
        // AuthProvider의 자동 로그인 시도 (프로필 생성 포함)
        final success = await authProvider.tryAutoLogin();
        
        if (success && authProvider.currentUser != null) {
          print('✅ 프로필 로드 성공: ${authProvider.currentUser!.name}');
        } else {
          print('⚠️ 프로필 로드 실패, 추가 처리 시도...');
          
          // 추가 시도: AuthProvider의 사용자 정보 강제 로드
          await authProvider.refreshSession();
          
          if (authProvider.currentUser != null) {
            print('✅ 재시도 후 프로필 로드 성공');
          } else {
            print('❌ 모든 시도 후에도 프로필 로드 실패');
          }
        }
      } catch (providerError) {
        print('❌ AuthProvider 처리 중 오류: $providerError');
        // Provider 오류가 있어도 세션이 있으면 계속 진행
      }

      if (mounted) {
        final target = _resolveRedirect(
          params['redirect'] ?? widget.redirectPath,
        );
        print('🎯 최종 리다이렉트: $target');
        context.go(target);
      }
    } on AuthException catch (authError) {
      print('❌ AuthException: ${authError.message}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('인증 오류: ${authError.message}')));
        context.go('/login');
      }
    } catch (error) {
      print('❌ OAuth 콜백 처리 중 예기치 않은 오류: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('세션 처리 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
        context.go('/login');
      }
    }
  }

  Map<String, String> _collectParams(Uri uri) {
    final params = <String, String>{};
    params.addAll(uri.queryParameters);

    if (uri.fragment.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(uri.fragment));
      } catch (_) {
        // Ignore malformed fragments.
      }
    }

    if (widget.provider != null) {
      params.putIfAbsent('provider', () => widget.provider!);
    }
    if (widget.code != null) {
      params.putIfAbsent('code', () => widget.code!);
    }
    if (widget.redirectPath != null) {
      params.putIfAbsent('redirect', () => widget.redirectPath!);
    }

    return params;
  }

  String _resolveRedirect(String? redirect) {
    if (redirect == null || redirect.isEmpty) {
      return '/';
    }

    final decoded = Uri.decodeComponent(redirect);
    return decoded.startsWith('/') ? decoded : '/';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('인증 처리 중...', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
