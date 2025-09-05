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
    }
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
      throw Exception('로그인 실패: $e');
    }
  }

  /// Phone+Password 회원가입 (전화번호를 계정 ID로 사용, 이메일은 내부용)
  Future<UserModel?> signUpWithPhonePassword({
    required String phone,
    required String password,
    required String nickname,
  }) async {
    try {
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
      final signUpRes = await _supabase.auth.signUp(
        email: syntheticEmail,
        password: password,
        data: {
          'name': nickname,
          'phone': phone,
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
            'phone': phone,
            'profile_image': null,
            'is_verified': true,
            'role': '일반',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      _cache.clear();
      return UserModel.fromJson(userRow);
    } catch (e) {
      throw Exception('회원가입 실패: $e');
    }
  }

  String _syntheticEmailFromPhone(String phone) {
    final digits = phone.replaceAll(RegExp('[^0-9]'), '');
    return '$digits@everseconds.local';
  }
}
