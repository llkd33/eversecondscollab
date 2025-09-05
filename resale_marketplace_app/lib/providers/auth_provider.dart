import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
// test_session removed: using only real Supabase sessions

/// 인증 상태 관리 Provider
/// 전역적으로 인증 상태를 관리하고 UI 업데이트를 트리거
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  // 테스트 로그인 제거: 항상 실제 세션 사용
  
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
  bool get isAuthenticated => _authService.isAuthenticated;
  
  // 사용자 ID
  String? get userId => _authService.currentUser?.id;
  
  // 사용자 이메일
  String? get userEmail => _authService.currentUser?.email;
  
  /// Provider 초기화
  AuthProvider() {
    _initializeAuth();
  }
  
  /// 인증 상태 초기화 및 리스너 설정
  void _initializeAuth() {
    // 현재 사용자 정보 로드
    _loadCurrentUser();
    
    // 인증 상태 변경 리스너
    _authService.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.signedIn ||
          authState.event == AuthChangeEvent.tokenRefreshed) {
        _loadCurrentUser();
      } else if (authState.event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        notifyListeners();
      }
    });
  }
  
  /// 현재 사용자 정보 로드
  Future<void> _loadCurrentUser() async {
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
      await _authService.signOut();
      _currentUser = null;
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
    await _authService.refreshSession();
  }
  
  /// 특정 기능에 대한 접근 권한 확인
  bool canUploadProduct() => _authService.canUploadProduct();
  bool canPurchase() => _authService.canPurchase();
  bool canEditProduct(String sellerId) => _authService.canEditProduct(sellerId);
  bool canDeleteProduct(String sellerId) => _authService.canDeleteProduct(sellerId);
  bool canViewProduct() => _authService.canViewProduct();
  bool canSearchProduct() => _authService.canSearchProduct();
  
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
  
  @override
  void dispose() {
    // 리소스 정리
    super.dispose();
  }

  // 테스트 로그인 제거
}
