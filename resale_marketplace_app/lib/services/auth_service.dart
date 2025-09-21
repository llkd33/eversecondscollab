import 'dart:io' show Platform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';
import 'package:gotrue/gotrue.dart' show OAuthProvider;
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../utils/api_cache.dart';
import '../config/kakao_config.dart';
import '../config/env_flags.dart';
import 'shop_service.dart';

/// 인증 서비스 - 로그인, 로그아웃, 회원가입 및 인증 상태 관리
class AuthService {
  final _supabase = Supabase.instance.client;
  final _cache = ApiCache();

  /// Phone Auth 설정 상태 확인
  Future<Map<String, dynamic>> checkPhoneAuthStatus() async {
    // In web or local test mode, avoid hitting the OTP endpoint to prevent 422 noise.
    if (kIsWeb || enableLocalTestMode) {
      return {
        'enabled': false,
        'provider': 'none',
        'message': 'Skipped phone auth check in web/test mode',
      };
    }
    try {
      // Supabase Auth 설정 상태 확인 시도
      final testPhone = '+821012345678'; // 테스트용 번호

      // 실제 SMS를 보내지 않고 설정만 확인하는 방법을 시도
      await _supabase.auth.signInWithOtp(
        phone: testPhone,
        shouldCreateUser: false,
      );

      return {
        'enabled': true,
        'provider': 'vonage',
        'message': 'Phone Auth 설정이 정상입니다',
      };
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();

      if (errorMsg.contains('phone_provider_disabled') ||
          errorMsg.contains('phone provider disabled')) {
        return {
          'enabled': false,
          'provider': 'none',
          'message': 'Phone 인증이 비활성화되어 있습니다',
          'error': e.toString(),
        };
      } else if (errorMsg.contains('signup not allowed')) {
        return {
          'enabled': true,
          'provider': 'unknown',
          'message': 'Phone Auth는 활성화되어 있지만 회원가입이 제한되어 있습니다',
          'error': e.toString(),
        };
      } else {
        return {
          'enabled': true,
          'provider': 'vonage',
          'message': 'Phone Auth 설정을 확인할 수 없지만 활성화되어 있는 것으로 보입니다',
          'error': e.toString(),
        };
      }
    }
  }

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

  /// 전화번호로 OTP 전송 (Vonage API 사용)
  Future<void> sendOTP(String phone) async {
    final success = await sendVerificationCode(phone, allowCreateUser: true);
    if (!success) {
      throw Exception('인증번호 전송에 실패했습니다.');
    }
  }

  /// OTP 전송 (신규 가입 허용 여부를 제어)
  Future<bool> sendVerificationCode(
    String phone, {
    bool allowCreateUser = true,
  }) async {
    try {
      final normalizedPhone = _normalizeLocalPhone(phone);
      final e164Phone = _formatToE164KR(normalizedPhone);

      if (allowCreateUser) {
        try {
          final tempPassword = '${DateTime.now().millisecondsSinceEpoch}Temp!';
          await _supabase.auth.signUp(phone: e164Phone, password: tempPassword);
          print('✅ 신규 전화번호 가입 완료: $e164Phone');
        } on AuthApiException catch (e) {
          final message = (e.message ?? e.toString()).toLowerCase();
          if (!(message.contains('already registered') ||
              (e.code != null && e.code!.contains('already')))) {
            rethrow;
          }
          print('ℹ️ 이미 가입된 전화번호로 확인되어 가입 단계는 건너뜁니다.');
        }
      }

      await _supabase.auth.signInWithOtp(
        phone: e164Phone,
        channel: OtpChannel.sms,
        // signUp을 별도로 수행했으므로 여기서는 false로 두어도 됨
        shouldCreateUser: false,
      );

      print('✅ OTP 전송 성공: $e164Phone');
      return true;
    } on AuthApiException catch (e) {
      if (e.code == 'otp_disabled') {
        throw Exception(
          'OTP 인증이 비활성화되어 있습니다. Supabase Auth 설정에서 전화번호 가입을 허용해주세요. (${e.message})',
        );
      }
      throw Exception('인증번호 전송 실패: ${e.message}');
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
      print('🔐 OTP 검증 시작: $phone / $otp');

      // 한국 번호 형식으로 변환
      final formattedPhone = _formatToE164KR(phone);

      print('🌏 변환된 전화번호: $formattedPhone');
      print('🔑 인증번호: $otp');

      final response = await _supabase.auth.verifyOTP(
        type: OtpType.sms,
        phone: formattedPhone,
        token: otp,
      );

      print('✅ OTP 검증 응답 받음: ${response.user?.id}');

      if (response.user != null) {
        // 신규 사용자인 경우 users 테이블에 추가
        final existingUser = await _supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (existingUser == null) {
          // 신규 회원가입 - RLS 우회를 위해 다양한 방법 시도
          print('🔧 신규 사용자 생성 시도...');

          try {
            // 방법 1: 일반 삽입 시도
            await _supabase.from('users').insert({
              'id': response.user!.id,
              'email': null, // 전화번호 기반 가입
              'phone': phone,
              'name': name ?? '사용자${phone.substring(phone.length - 4)}',
              'is_verified': true, // SMS 인증 완료
              'role': '일반', // UserModel에서 기대하는 역할
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            print('✅ 신규 사용자 생성 완료: ${response.user!.id}');
          } catch (rlsError) {
            print('⚠️ RLS 정책으로 인한 삽입 실패, 대안 방법 시도: $rlsError');

            try {
              // 방법 2: RPC 함수를 통한 삽입 시도 (만약 있다면)
              await _supabase.rpc(
                'create_user_profile',
                params: {
                  'user_id': response.user!.id,
                  'user_phone': phone,
                  'user_name':
                      name ?? '사용자${phone.substring(phone.length - 4)}',
                  'user_role': '일반',
                },
              );
              print('✅ RPC를 통한 사용자 생성 완료: ${response.user!.id}');
            } catch (rpcError) {
              print('⚠️ RPC도 실패, 기본 프로필로 계속 진행: $rpcError');
              // RLS 오류를 무시하고 계속 진행
              // Auth 사용자는 생성되었으므로 기본 프로필 정보만으로도 진행 가능
            }
          }
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
          .maybeSingle();

      if (response == null) {
        print('⚠️ Auth 사용자는 있지만 users 테이블에 정보가 없습니다. 프로필을 자동으로 생성합니다.');

        final created = await _createUserFromAuth();
        if (created) {
          final retry = await _supabase
              .from('users')
              .select()
              .eq('id', currentUser!.id)
              .maybeSingle();

          if (retry != null) {
            return UserModel.fromJson(retry);
          }
        }

        // 최후의 수단으로 Auth 사용자 정보를 기반으로 기본 프로필 생성
        final fallbackUser = _buildUserPayloadFromAuth(currentUser!);
        return UserModel.fromJson(fallbackUser);
      }

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Auth 사용자 정보를 기반으로 users 테이블에 사용자 생성
  Future<bool> _createUserFromAuth() async {
    if (!isAuthenticated) return false;

    User? authUser = currentUser;
    if (authUser == null) {
      return false;
    }

    Map<String, dynamic>? userPayload;

    try {
      userPayload = _buildUserPayloadFromAuth(authUser);

      await _supabase.from('users').upsert(userPayload);
      await _ensureShopAfterProfileSync(
        authUser.id,
        userPayload['name'] as String?,
      );
      print('✅ Auth 기반 사용자 생성/동기화 완료: ${authUser.id}');
      return true;
    } on PostgrestException catch (error) {
      final isShareUrlConflict =
          error.code == '23505' &&
          (error.message ?? '').contains('shops_share_url_key');

      if (isShareUrlConflict) {
        final existing = await _supabase
            .from('users')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();

        if (existing != null) {
          await _ensureShopAfterProfileSync(
            authUser.id,
            (existing['name'] as String?) ?? userPayload?['name'] as String?,
          );

          print(
            '⚠️ Auth 기반 사용자 생성 시 기존 share_url 충돌이 감지되었지만 기존 프로필을 재사용합니다: ${authUser.id}',
          );
          return true;
        }
      }

      print('❌ Auth 기반 사용자 생성 실패: $error');
      return false;
    } catch (e) {
      print('❌ Auth 기반 사용자 생성 실패: $e');
      return false;
    }
  }

  Future<void> _ensureShopAfterProfileSync(
    String userId,
    String? resolvedName,
  ) async {
    final displayName = (resolvedName ?? '사용자').trim().isEmpty
        ? '사용자'
        : resolvedName!.trim();

    try {
      final shopService = ShopService();
      await shopService.ensureUserShop(userId, displayName);
    } catch (e) {
      print('Error ensuring shop after profile sync: $e');
    }
  }

  Map<String, dynamic> _buildUserPayloadFromAuth(User user) {
    final metadata = user.userMetadata ?? <String, dynamic>{};
    final resolvedPhone = _resolveUserPhone(user, metadata);
    final resolvedName = _resolveUserName(user, metadata, resolvedPhone);
    final nowIso = DateTime.now().toIso8601String();

    final rawRole = metadata['role'];
    final role = rawRole is String && rawRole.trim().isNotEmpty
        ? rawRole.trim()
        : '일반';
    final profileImage = metadata['profile_image'];
    final shopId = metadata['shop_id'];

    final payload = <String, dynamic>{
      'id': user.id,
      'email': user.email,
      'phone': resolvedPhone,
      'name': resolvedName,
      'is_verified': _resolveIsVerified(metadata),
      'role': role,
      'created_at': _resolveCreatedAt(metadata, nowIso),
      'updated_at': nowIso,
    };

    if (profileImage is String && profileImage.isNotEmpty) {
      payload['profile_image'] = profileImage;
    }
    if (shopId is String && shopId.isNotEmpty) {
      payload['shop_id'] = shopId;
    }

    payload.removeWhere((key, value) => value == null);
    return payload;
  }

  String _resolveUserPhone(User user, Map<String, dynamic> metadata) {
    // Try auth phone first
    final authPhone = user.phone;
    if (authPhone != null && authPhone.isNotEmpty) {
      try {
        final display = _displayPhoneFromE164(authPhone);
        if (_isValidLocalPhone(display)) {
          return display;
        }
      } catch (_) {
        // If not E164 format, try normalizing
        try {
          final normalized = _normalizeLocalPhone(authPhone);
          if (_isValidLocalPhone(normalized)) {
            return normalized;
          }
        } catch (_) {
          // Ignore and fall back to other metadata sources
        }
      }
    }

    // Try metadata phone
    final metaPhone = metadata['phone'];
    if (metaPhone is String && metaPhone.trim().isNotEmpty) {
      try {
        final normalized = _normalizeLocalPhone(metaPhone.trim());
        if (_isValidLocalPhone(normalized)) {
          return normalized;
        }
      } catch (_) {
        // Continue evaluating other fallbacks if normalization fails
      }
    }

    // Fallback to email prefix if no phone available
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      final digitsOnly = email
          .split('@')
          .first
          .replaceAll(RegExp(r'[^0-9]'), '');
      if (_isValidLocalPhone(digitsOnly)) {
        return _normalizeLocalPhone(digitsOnly);
      }
      return '';
    }

    // Last resort: empty string
    return '';
  }

  String _resolveUserName(
    User user,
    Map<String, dynamic> metadata,
    String resolvedPhone,
  ) {
    final metaName = metadata['name'];
    if (metaName is String && metaName.trim().isNotEmpty) {
      return metaName.trim();
    }

    final email = user.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    final digits = resolvedPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final suffixStart = digits.length >= 4 ? digits.length - 4 : 0;
      return '사용자${digits.substring(suffixStart)}';
    }

    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    return '사용자${millis.substring(millis.length >= 4 ? millis.length - 4 : 0)}';
  }

  bool _resolveIsVerified(Map<String, dynamic> metadata) {
    final value = metadata['is_verified'];
    if (value is bool) return value;
    return true;
  }

  String _resolveCreatedAt(Map<String, dynamic> metadata, String fallback) {
    final value = metadata['created_at'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return fallback;
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

        await _supabase.from('users').update(updates).eq('id', currentUser!.id);
      }
    } catch (e) {
      throw Exception('프로필 업데이트 실패: $e');
    }
  }

  /// 비밀번호 설정/업데이트
  Future<void> updatePassword(String password) async {
    if (!isAuthenticated) {
      throw Exception('로그인이 필요합니다');
    }

    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
      print('✅ 비밀번호 업데이트 완료');
    } catch (e) {
      print('❌ 비밀번호 업데이트 실패: $e');
      throw Exception('비밀번호 설정 실패: $e');
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
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(
        session.expiresAt! * 1000,
      );
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

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(
      session!.expiresAt! * 1000,
    );
    final now = DateTime.now();

    if (expiryTime.isBefore(now)) return 0;

    return expiryTime.difference(now).inMinutes;
  }

  /// 특정 기능에 대한 접근 권한 확인
  bool canUploadProduct() => isAuthenticated;
  bool canPurchase() => isAuthenticated;
  bool canEditProduct(String sellerId) =>
      isAuthenticated && currentUser?.id == sellerId;
  bool canDeleteProduct(String sellerId) =>
      isAuthenticated && currentUser?.id == sellerId;
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

  /// Phone+Password 로그인 (SMS 인증으로 가입한 사용자용)
  Future<UserModel?> signInWithPhonePassword({
    required String phone,
    required String password,
  }) async {
    try {
      print('📱 전화번호 로그인 시도: $phone');

      final normalizedPhone = _normalizeLocalPhone(phone);

      // users 테이블에 해당 전화번호가 존재하는지 먼저 확인
      final legacyPhone = _formatDisplayPhoneLegacy(normalizedPhone);
      final existingUser = await _supabase
          .from('users')
          .select('id, phone')
          .or('phone.eq.$normalizedPhone,phone.eq.$legacyPhone')
          .maybeSingle();

      if (existingUser == null) {
        throw Exception('가입 이력이 없는 전화번호입니다. 먼저 회원가입을 진행해주세요.');
      }

      // SMS 인증으로 가입한 사용자는 E.164 형식으로 Auth에 등록됨
      final e164 = _formatToE164KR(normalizedPhone);
      print('📱 E.164 형식: $e164');

      // 여러 방법으로 로그인 시도
      try {
        // 방법 1: 전화번호로 로그인
        await _supabase.auth.signInWithPassword(
          phone: e164,
          password: password,
        );
        print('✅ 전화번호 로그인 성공');
      } catch (phoneError) {
        print('⚠️ 전화번호 로그인 실패, 이메일 방법 시도: $phoneError');

        // 방법 2: synthetic email로 로그인 시도
        final syntheticEmail = _syntheticEmailFromPhone(normalizedPhone);
        print('📧 Synthetic email 시도: $syntheticEmail');

        await _supabase.auth.signInWithPassword(
          email: syntheticEmail,
          password: password,
        );
        print('✅ 이메일 로그인 성공');
      }

      // users 테이블에서 프로필 로드
      final profile = await getUserProfile();
      _cache.clear();

      if (profile != null) {
        print('✅ 사용자 프로필 로드 완료: ${profile.name}');
        return profile;
      } else {
        print('⚠️ 프로필 없음, 기본 프로필로 진행');
        return await getUserProfile(); // RLS 우회된 기본 프로필 반환
      }
    } catch (e) {
      print('❌ 전화번호 로그인 실패: $e');
      throw Exception('로그인 실패: 전화번호 또는 비밀번호를 확인해주세요.');
    }
  }

  /// Phone+Password 회원가입 (전화번호를 계정 ID로 사용, 이메일은 내부용)
  Future<UserModel?> signUpWithPhonePassword({
    required String phone,
    required String password,
    required String nickname,
    String role = '일반',
  }) async {
    final normalizedPhone = _normalizeLocalPhone(phone);

    // 중복 체크 (전화번호 기준)
    final exists = await _supabase
        .from('users')
        .select('id')
        .eq('phone', normalizedPhone)
        .maybeSingle();
    if (exists != null) {
      throw Exception('이미 가입된 전화번호입니다. 다른 방법으로 로그인해주세요.');
    }

    final syntheticEmail = _syntheticEmailFromPhone(normalizedPhone);

    // 1) Try phone+password sign-up with E.164
    try {
      final e164 = _formatToE164KR(normalizedPhone);
      final signUpRes = await _supabase.auth.signUp(
        phone: e164,
        password: password,
        data: {'name': nickname, 'phone': _displayPhoneFromE164(e164)},
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
            'phone': normalizedPhone,
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
          data: {'name': nickname, 'phone': normalizedPhone},
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
              'phone': normalizedPhone,
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
    if (e164.isEmpty) return '';

    final digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // Strip country code (82 for Korea)
    final local = digits.startsWith('82') ? digits.substring(2) : digits;

    // Re-add leading 0 if needed
    final full = local.startsWith('0') ? local : '0$local';

    // Validate length (should be 10 or 11 digits for Korean numbers)
    if (full.length != 10 && full.length != 11) {
      return full; // Return as-is if not standard Korean format
    }

    return full; // Keep as numeric string without dashes
  }

  String _normalizeLocalPhone(String phone) {
    if (phone.isEmpty) return '';

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return ''; // Return empty instead of throwing
    }

    // Handle Korean mobile numbers
    if (digits.length == 11 && digits.startsWith('010')) {
      return digits; // Already in correct format
    }

    // Handle 10-digit numbers (missing leading 0)
    if (digits.length == 10 && digits.startsWith('10')) {
      return '0$digits';
    }

    // Handle international format (+8210...)
    if (digits.startsWith('8210') && digits.length == 13) {
      return '0' + digits.substring(2); // Remove 82, add leading 0
    }

    // Return as-is for other formats
    return digits;
  }

  bool _isValidLocalPhone(String phone) {
    if (phone.isEmpty) return false;
    return RegExp(r'^01[0-9]-?[0-9]{4}-?[0-9]{4}$').hasMatch(phone);
  }

  String _formatDisplayPhoneLegacy(String digits) {
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    return digits;
  }

  /// 카카오 로그인
  Future<bool> signInWithKakao({String? redirectPath}) async {
    if (!KakaoConfig.isConfigured) {
      throw Exception('카카오 SDK가 설정되지 않았습니다');
    }

    try {
      final scopeString = KakaoConfig.scopes.join(' ');

      // Platform-specific redirect URL configuration
      // Web: Use Supabase OAuth callback URL
      // Mobile (Android/iOS): Use deep link
      final redirectTo = kIsWeb
          ? KakaoConfig.buildWebRedirectUri(redirectPath: redirectPath)
          : KakaoConfig.buildNativeRedirectUri(redirectPath: redirectPath);

      final launchMode = kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication;

      final opened = await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: redirectTo,
        authScreenLaunchMode: launchMode,
        scopes: scopeString,
        queryParams: {'scope': scopeString},
      );
      return opened;
    } catch (error) {
      throw Exception('카카오 로그인 실패: $error');
    }
  }

  /// 카카오 로그아웃 (카카오 토큰도 함께 해제)
  Future<void> signOutWithKakao() async {
    try {
      // 카카오 토큰 해제
      if (KakaoConfig.isConfigured) {
        try {
          await kakao.UserApi.instance.logout();
        } catch (e) {
          print('Kakao logout error (ignored): $e');
        }
      }

      // 일반 로그아웃 진행
      await signOut();
    } catch (e) {
      throw Exception('로그아웃 실패: $e');
    }
  }
}
