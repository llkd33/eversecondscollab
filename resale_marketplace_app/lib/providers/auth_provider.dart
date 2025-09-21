import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../models/user_model.dart';

/// 인증 상태 관리 Provider
/// 전역적으로 인증 상태를 관리하고 UI 업데이트를 트리거
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  // 현재 사용자 정보
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Timer? _sessionRefreshTimer;
  bool _isRefreshingSession = false;
  bool? _debugAuthOverride;

  // 로딩 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 로그인 여부
  bool get isAuthenticated =>
      _debugAuthOverride ?? _authService.isAuthenticated;

  // 사용자 ID
  String? get userId => _authService.currentUser?.id;

  // 사용자 이메일
  String? get userEmail => _authService.currentUser?.email;

  /// Provider 초기화
  AuthProvider({AuthService? authService, bool initialize = true})
    : _authService = authService ?? AuthService() {
    if (initialize) {
      _initializeAuth();
    }
  }

  /// 인증 상태 초기화 및 리스너 설정
  void _initializeAuth() {
    // 앱 시작 시 기존 세션 복원 시도
    _restoreSession();

    // 인증 상태 변경 리스너
    _authService.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.signedIn ||
          authState.event == AuthChangeEvent.tokenRefreshed) {
        _loadCurrentUser();
      } else if (authState.event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _stopSessionRefreshTimer();
        notifyListeners();
      } else if (authState.event == AuthChangeEvent.passwordRecovery) {
        // 비밀번호 복구 이벤트 처리
        print('Password recovery event received');
      }
    });
  }

  /// 앱 시작 시 기존 세션 복원
  Future<void> _restoreSession() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Supabase 세션 자동 복원 확인
      final session = _authService.currentSession;
      if (session != null) {
        // 세션이 유효한지 확인
        if (session.expiresAt != null &&
            DateTime.fromMillisecondsSinceEpoch(
              session.expiresAt! * 1000,
            ).isAfter(DateTime.now())) {
          // 유효한 세션이 있으면 사용자 정보 로드
          await _loadCurrentUser();
        } else {
          // 만료된 세션이면 토큰 새로고침 시도
          await _authService.refreshSession();
          await _loadCurrentUser();
        }
      }
    } catch (e) {
      print('Session restoration failed: $e');
      // 세션 복원 실패 시 로그아웃 처리
      await _handleSessionExpired();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 세션 만료 처리
  Future<void> _handleSessionExpired() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      _errorMessage = '세션이 만료되었습니다. 다시 로그인해주세요.';
      _debugAuthOverride = null;
      _stopSessionRefreshTimer();
    } catch (e) {
      print('Error handling session expiry: $e');
    }
  }

  /// 현재 사용자 정보 로드
  Future<void> _loadCurrentUser({bool restartTimer = true}) async {
    if (_authService.isAuthenticated) {
      try {
        _currentUser = await _authService.getUserProfile();
        if (restartTimer) {
          if (_currentUser != null) {
            _startSessionRefreshTimer();
          } else {
            _stopSessionRefreshTimer();
          }
        }
        _debugAuthOverride = null;
        notifyListeners();
      } catch (e) {
        print('Error loading user profile: $e');
        if (restartTimer) {
          _stopSessionRefreshTimer();
        }
      }
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
      _errorMessage = null;
      _debugAuthOverride = null;
      _stopSessionRefreshTimer();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 프로필 업데이트
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? address,
    String? profileImage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.updateProfile(
        name: name,
        phone: phone,
        address: address,
        profileImage: profileImage,
      );
      // 프로필 업데이트 후 사용자 정보 재로드
      await _loadCurrentUser();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 토큰 새로고침
  Future<void> refreshSession() async {
    try {
      await _authService.refreshSession();
      await _loadCurrentUser();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      await _handleSessionExpired();
    }
  }

  /// 세션 유효성 확인
  bool isSessionValid() => _authService.isSessionValid();

  /// 세션 만료 시간 확인 (분 단위)
  int? getSessionExpiryMinutes() => _authService.getSessionExpiryMinutes();

  /// 자동 로그인 시도
  Future<bool> tryAutoLogin() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_authService.isAuthenticated && _authService.isSessionValid()) {
        await _loadCurrentUser();
        return true;
      } else if (_authService.currentSession != null) {
        // 세션이 있지만 만료된 경우 새로고침 시도
        await _authService.refreshSession();
        await _loadCurrentUser();
        return true;
      }

      return false;
    } catch (e) {
      print('Auto login failed: $e');
      await _handleSessionExpired();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 특정 기능에 대한 접근 권한 확인
  bool canUploadProduct() => _authService.canUploadProduct();
  bool canPurchase() => _authService.canPurchase();
  bool canEditProduct(String sellerId) => _authService.canEditProduct(sellerId);
  bool canDeleteProduct(String sellerId) =>
      _authService.canDeleteProduct(sellerId);
  bool canViewProduct() => true;
  bool canSearchProduct() => true;

  /// 에러 메시지 클리어
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 카카오 로그인
  Future<bool> signInWithKakao({String? redirectPath}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final launched = await _authService.signInWithKakao(
        redirectPath: redirectPath,
      );
      if (launched && _authService.isAuthenticated) {
        _startSessionRefreshTimer();
      }
      _isLoading = false;
      notifyListeners();
      return launched;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 카카오 로그아웃
  Future<void> signOutWithKakao() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOutWithKakao();
      _currentUser = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // 리소스 정리
    _stopSessionRefreshTimer();
    super.dispose();
  }

  // 테스트 로그인 제거

  void _startSessionRefreshTimer({bool immediate = false}) {
    _sessionRefreshTimer?.cancel();

    if (!_authService.isAuthenticated) {
      return;
    }

    _sessionRefreshTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _refreshSessionIfNeeded(),
    );

    if (immediate) {
      Future.microtask(() => _refreshSessionIfNeeded(force: true));
    }
  }

  void _stopSessionRefreshTimer() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = null;
    _isRefreshingSession = false;
  }

  Future<void> _refreshSessionIfNeeded({bool force = false}) async {
    if (_isRefreshingSession) return;
    if (!_authService.isAuthenticated) {
      _stopSessionRefreshTimer();
      return;
    }

    final minutesLeft = _authService.getSessionExpiryMinutes();
    final shouldRefresh =
        force || minutesLeft == null || minutesLeft <= 43200; // 30일 이하
    if (!shouldRefresh) {
      return;
    }

    _isRefreshingSession = true;
    try {
      await _authService.refreshSession();
      await _loadCurrentUser(restartTimer: false);
    } catch (e) {
      print('Session refresh failed: $e');
    } finally {
      _isRefreshingSession = false;
    }
  }

  @visibleForTesting
  void debugOverrideAuthState({UserModel? user, bool? isAuthenticated}) {
    _currentUser = user;
    _debugAuthOverride = isAuthenticated;
    notifyListeners();
  }
}
