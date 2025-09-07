import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/api_cache.dart';

/// 인증 서비스 - 로그인, 로그아웃, 회원가입 및 인증 상태 관리
class AuthService {
  final _supabase = Supabase.instance.client;
  final _cache = ApiCache();
  
  /// 현재 로그인된 사용자 정보
  User? get currentUser => _supabase.auth.currentUser;
  
  /// 로그인 여부 확인
  bool get isAuthenticated => currentUser != null;
  
  /// 현재 사용자의 역할 (판매자/구매자)
  Future<String?> get userRole async {
    if (!isAuthenticated) return null;
    
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', currentUser!.id)
          .single();
      
      return response['role'] as String?;
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }
  
  
  /// 전화번호로 OTP 전송
  Future<void> sendOTP(String phone) async {
    try {
      // 한국 번호 형식으로 변환 (+82)
      String formattedPhone = phone;
      if (phone.startsWith('010')) {
        formattedPhone = '+82${phone.substring(1)}';
      } else if (!phone.startsWith('+')) {
        formattedPhone = '+82$phone';
      }
      
      await _supabase.auth.signInWithOtp(
        phone: formattedPhone,
      );
    } catch (e) {
      throw Exception('인증번호 전송 실패: $e');
    }
  }
  
  /// OTP 인증 및 로그인/회원가입
  Future<AuthResponse> verifyOTP({
    required String phone,
    required String otp,
    String? name,
  }) async {
    try {
      // 한국 번호 형식으로 변환
      String formattedPhone = phone;
      if (phone.startsWith('010')) {
        formattedPhone = '+82${phone.substring(1)}';
      } else if (!phone.startsWith('+')) {
        formattedPhone = '+82$phone';
      }
      
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.sms,
        phone: formattedPhone,
        token: otp,
      );
      
      if (response.user != null) {
        // 신규 사용자인 경우 users 테이블에 추가
        final existingUser = await _supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();
        
        if (existingUser == null) {
          // 신규 회원가입
          await _supabase.from('users').insert({
            'id': response.user!.id,
            'phone': phone,
            'name': name ?? '사용자${phone.substring(phone.length - 4)}',
            'role': 'user',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        
        _cache.clear();
      }
      
      return response;
    } catch (e) {
      throw Exception('인증 실패: $e');
    }
  }
  
  
  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _cache.clear(); // 로그아웃시 캐시 클리어
    } catch (e) {
      throw Exception('로그아웃 실패: $e');
    }
  }
  
  
  /// 현재 사용자의 프로필 정보 가져오기
  Future<UserModel?> getUserProfile() async {
    if (!isAuthenticated) return null;
    
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', currentUser!.id)
          .single();
      
      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
  
  /// getCurrentUser 메소드 (기존 코드와의 호환성을 위해)
  Future<UserModel?> getCurrentUser() async {
    return getUserProfile();
  }
  
  /// 프로필 업데이트
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
    String? profileImage,
  }) async {
    if (!isAuthenticated) {
      throw Exception('로그인이 필요합니다');
    }
    
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (address != null) updates['address'] = address;
      if (profileImage != null) updates['profile_image'] = profileImage;
      
      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().toIso8601String();
        
        await _supabase
            .from('users')
            .update(updates)
            .eq('id', currentUser!.id);
      }
    } catch (e) {
      throw Exception('프로필 업데이트 실패: $e');
    }
  }
  
  /// 인증 상태 변경 스트림
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  
  /// 액세스 토큰 가져오기 (API 호출시 필요)
  Future<String?> getAccessToken() async {
    final session = _supabase.auth.currentSession;
    return session?.accessToken;
  }
  
  /// 토큰 새로고침
  Future<void> refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (e) {
      print('Error refreshing session: $e');
      throw Exception('세션 새로고침 실패: $e');
    }
  }
  
  /// 현재 세션 정보 가져오기
  Session? get currentSession => _supabase.auth.currentSession;
  
  /// 세션 유효성 검사
  bool isSessionValid() {
    final session = currentSession;
    if (session == null) return false;
    
    if (session.expiresAt != null) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      return expiryTime.isAfter(DateTime.now());
    }
    
    return true;
  }
  
  /// 자동 토큰 새로고침 설정
  void enableAutoRefresh() {
    // Supabase는 기본적으로 자동 새로고침이 활성화되어 있음
    // 필요시 추가 로직 구현
  }
  
  /// 세션 만료 시간 확인 (분 단위)
  int? getSessionExpiryMinutes() {
    final session = currentSession;
    if (session?.expiresAt == null) return null;
    
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(session!.expiresAt! * 1000);
    final now = DateTime.now();
    
    if (expiryTime.isBefore(now)) return 0;
    
    return expiryTime.difference(now).inMinutes;
  }
  
  /// 특정 기능에 대한 접근 권한 확인
  bool canUploadProduct() => isAuthenticated;
  bool canPurchase() => isAuthenticated;
  bool canEditProduct(String sellerId) => isAuthenticated && currentUser?.id == sellerId;
  bool canDeleteProduct(String sellerId) => isAuthenticated && currentUser?.id == sellerId;
  bool canViewProduct() => true; // 모든 사용자 가능
  bool canSearchProduct() => true; // 모든 사용자 가능
  
  /// 전화번호 포맷팅 (표시용)
  static String formatPhoneNumber(String phone) {
    // 숫자만 추출
    final numbers = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (numbers.length == 11 && numbers.startsWith('010')) {
      // 010-1234-5678 형식
      return '${numbers.substring(0, 3)}-${numbers.substring(3, 7)}-${numbers.substring(7)}';
    } else if (numbers.length == 10 && numbers.startsWith('10')) {
      // 10-1234-5678 형식 (+82 제거된 경우)
      return '0${numbers.substring(0, 2)}-${numbers.substring(2, 6)}-${numbers.substring(6)}';
    }
    
    return phone;
  }

  /// Phone+Password 로그인 (이메일로 매핑)
  Future<UserModel?> signInWithPhonePassword({
    required String phone,
    required String password,
  }) async {
    try {
      // Prefer email path to avoid phone provider dependencies
      final syntheticEmail = _syntheticEmailFromPhone(phone);
      await _supabase.auth.signInWithPassword(email: syntheticEmail, password: password);
      // users 테이블에서 프로필 로드
      final profile = await _supabase
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();
      _cache.clear();
      return profile != null ? UserModel.fromJson(profile) : await getUserProfile();
    } catch (e) {
      // 2) Fallback: try phone+password with E.164 formatting
      try {
        final e164 = _formatToE164KR(phone);
        await _supabase.auth.signInWithPassword(phone: e164, password: password);
        final profile = await _supabase
            .from('users')
            .select()
            .eq('phone', _displayPhoneFromE164(e164))
            .maybeSingle();
        _cache.clear();
        return profile != null ? UserModel.fromJson(profile) : await getUserProfile();
      } catch (_) {}
      // 3) If no account, auto sign-up
      try {
        final existing = await _supabase
            .from('users')
            .select('id')
            .eq('phone', phone)
            .maybeSingle();
        if (existing == null) {
          // 계정이 없으면 자동 회원가입
          final nickname = '사용자${phone.replaceAll(RegExp(r'[^0-9]'), '')}';
          return await signUpWithPhonePassword(phone: phone, password: password, nickname: nickname);
        } else {
          throw Exception('로그인 실패: 기존 계정은 OTP 기반으로 가입되었을 수 있습니다. 회원가입 화면에서 비밀번호를 설정한 후 다시 시도해주세요.');
        }
      } catch (inner) {
        throw Exception(inner.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Phone+Password 회원가입 (전화번호를 계정 ID로 사용, 이메일은 내부용)
  Future<UserModel?> signUpWithPhonePassword({
    required String phone,
    required String password,
    required String nickname,
    String role = '일반',
  }) async {
    // 중복 체크 (전화번호 기준)
    final exists = await _supabase
        .from('users')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();
    if (exists != null) {
      throw Exception('이미 가입된 전화번호입니다. 다른 방법으로 로그인해주세요.');
    }

    final syntheticEmail = _syntheticEmailFromPhone(phone);

    // 1) Try phone+password sign-up with E.164
    try {
      final e164 = _formatToE164KR(phone);
      final signUpRes = await _supabase.auth.signUp(
        phone: e164,
        password: password,
        data: {
          'name': nickname,
          'phone': _displayPhoneFromE164(e164),
        },
      );
      if (signUpRes.user == null) {
        throw Exception('회원가입 실패: 인증 계정 생성에 실패했습니다');
      }

      final userRow = await _supabase
          .from('users')
          .insert({
            'id': signUpRes.user!.id,
            'email': syntheticEmail,
            'name': nickname,
            'phone': _displayPhoneFromE164(e164),
            'profile_image': null,
            'is_verified': true,
            'role': role,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      _cache.clear();
      return UserModel.fromJson(userRow);
    } catch (e) {
      final msg = e.toString();
      // 2) Fallback: if phone provider disabled, sign up via email+password
      if (msg.contains('phone_provider_disabled') ||
          msg.contains('Phone signups are disabled')) {
        final emailSignUp = await _supabase.auth.signUp(
          email: syntheticEmail,
          password: password,
          data: {
            'name': nickname,
            'phone': phone,
          },
        );
        if (emailSignUp.user == null) {
          throw Exception('회원가입 실패: 이메일 경로 생성 실패');
        }

        final userRow = await _supabase
            .from('users')
            .insert({
              'id': emailSignUp.user!.id,
              'email': syntheticEmail,
              'name': nickname,
              'phone': phone,
              'profile_image': null,
              'is_verified': true,
              'role': role,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        _cache.clear();
        return UserModel.fromJson(userRow);
      }

      if (msg.contains('User already registered')) {
        throw Exception('이미 가입된 전화번호입니다. 로그인하거나 다른 전화번호를 사용해주세요.');
      }
      throw Exception('회원가입 실패: $e');
    }
  }

  String _syntheticEmailFromPhone(String phone) {
    final digits = phone.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) {
      throw Exception('전화번호가 비어있습니다. 전화번호를 정확히 입력해주세요.');
    }
    // Conservative local part: start with a letter, then digits only.
    final local = 'u$digits';
    // Use a conventional public TLD domain specific to the app.
    return '${local.toLowerCase()}@everseconds.dev';
  }

  // Convert KR local phone (e.g., 01012345678 or 010-1234-5678) to E.164 (+82...)
  String _formatToE164KR(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      // Remove leading 0 for KR mobiles, assume 010/011 etc
      digits = digits.substring(1);
    }
    if (!digits.startsWith('82')) {
      // Prepend country code 82
      digits = '82$digits';
    }
    return '+$digits';
  }

  // Display form back to 010-.... style (stored in DB as plain digits with dashes optional)
  String _displayPhoneFromE164(String e164) {
    final digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    // Strip 82
    final local = digits.startsWith('82') ? digits.substring(2) : digits;
    // Re-add leading 0
    final full = local.startsWith('0') ? local : '0$local';
    return full; // Keep as numeric string without dashes
  }

  /// Ensure a test user exists and sign in; grants admin role for full access.
  Future<UserModel?> signInOrCreateTestUser({
    String phone = '010-9999-0001',
    String password = 'test1234',
    String nickname = '테스트 사용자',
    String role = '관리자',
  }) async {
    try {
      // Try sign in first
      await signInWithPhonePassword(phone: phone, password: password);
      final profile = await getUserProfile();
      if (profile != null) return profile;
    } catch (_) {
      // ignore, will try to sign up
    }

    // Create if missing
    final created = await signUpWithPhonePassword(
      phone: phone,
      password: password,
      nickname: nickname,
      role: role,
    );
    return created ?? await getUserProfile();
  }
}
