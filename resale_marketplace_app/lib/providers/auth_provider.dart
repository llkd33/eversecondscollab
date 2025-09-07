import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/test_session.dart';

/// 인증 상태 관리 Provider
/// 전역적으로 인증 상태를 관리하고 UI 업데이트를 트리거
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isTestLogin = false;
  
  // 현재 사용자 정보
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  
  // 로딩 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  // 로그인 여부
  bool get isAuthenticated => _isTestLogin || _authService.isAuthenticated;
  
  // 사용자 ID
  String? get userId => _isTestLogin ? _currentUser?.id : _authService.currentUser?.id;
  
  // 사용자 이메일
  String? get userEmail => _isTestLogin ? _currentUser?.email : _authService.currentUser?.email;
  
  /// Provider 초기화
  AuthProvider() {
    _initializeAuth();
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
        if (!_isTestLogin) {
          _currentUser = null;
        }
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
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000).isAfter(DateTime.now())) {
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
    } catch (e) {
      print('Error handling session expiry: $e');
    }
  }
  
  /// 현재 사용자 정보 로드
  Future<void> _loadCurrentUser() async {
    if (_isTestLogin) {
      notifyListeners();
      return;
    }
    if (_authService.isAuthenticated) {
      try {
        _currentUser = await _authService.getUserProfile();
        notifyListeners();
      } catch (e) {
        print('Error loading user profile: $e');
      }
    }
  }
  
  
  
  /// 로그아웃
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      if (_isTestLogin) {
        _isTestLogin = false;
        _currentUser = null;
        TestSession.clear();
      } else {
        await _authService.signOut();
        _currentUser = null;
      }
      _errorMessage = null;
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
  bool isSessionValid() {
    if (_isTestLogin) return true;
    return _authService.isSessionValid();
  }
  
  /// 세션 만료 시간 확인 (분 단위)
  int? getSessionExpiryMinutes() {
    if (_isTestLogin) return null;
    return _authService.getSessionExpiryMinutes();
  }
  
  /// 자동 로그인 시도
  Future<bool> tryAutoLogin() async {
    if (_isTestLogin) return true;
    
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
  bool canUploadProduct() => _isTestLogin || _authService.canUploadProduct();
  bool canPurchase() => _isTestLogin || _authService.canPurchase();
  bool canEditProduct(String sellerId) => _isTestLogin || _authService.canEditProduct(sellerId);
  bool canDeleteProduct(String sellerId) => _isTestLogin || _authService.canDeleteProduct(sellerId);
  bool canViewProduct() => true;
  bool canSearchProduct() => true;
  
  /// 전화번호로 OTP 전송
  Future<bool> sendOTP(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _authService.sendOTP(phone);
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
  
  /// OTP 인증 및 로그인/회원가입
  Future<bool> verifyOTP({
    required String phone,
    required String otp,
    String? name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await _authService.verifyOTP(
        phone: phone,
        otp: otp,
        name: name,
      );
      
      if (response.user != null) {
        await _loadCurrentUser();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = '인증에 실패했습니다';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// 에러 메시지 클리어
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 전화번호+비밀번호 로그인
  Future<bool> signInWithPhonePassword({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signInWithPhonePassword(phone: phone, password: password);
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
  
  /// 테스트 계정으로 로그인 (Supabase 연결 없이 전 기능 오픈)
  Future<bool> signInWithTestAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _isTestLogin = true;
      _currentUser = UserModel(
        id: 'test-user-0001',
        email: 'test@example.com',
        name: '테스트 사용자',
        phone: '01012345678',
        isVerified: true,
        profileImage: null,
        role: UserRole.admin,
        shopId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      TestSession.start(_currentUser!);
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
  
  @override
  void dispose() {
    // 리소스 정리
    super.dispose();
  }

  // 테스트 로그인 제거
}
