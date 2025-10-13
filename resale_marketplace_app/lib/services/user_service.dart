import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';
import '../models/shop_model.dart';
import '../utils/test_session.dart';
import 'shop_service.dart';
import 'image_compression_service.dart';

class UserService {
  final SupabaseClient _client = SupabaseConfig.client;

  bool _isMissingShopRelationship(PostgrestException error) {
    if (error.code == 'PGRST200') return true;
    final message = error.message;
    if (message is String && message.contains('PGRST200')) return true;
    if (message != null && message.toString().contains('PGRST200')) return true;
    return false;
  }

  // 현재 로그인한 사용자 정보 가져오기
  Future<UserModel?> getCurrentUser() async {
    if (TestSession.enabled) {
      print('Using test user: ${TestSession.testUser.id}');
      return TestSession.testUser;
    }
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return null;

      Future<Map<String, dynamic>?> runQuery(bool includeShop) {
        final selectClause = includeShop
            ? '*, shops!shops_owner_id_fkey(*)'
            : '*';
        return _client
            .from('users')
            .select(selectClause)
            .eq('id', authUser.id)
            .maybeSingle();
      }

      Map<String, dynamic>? response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingShopRelationship(e)) {
          print(
            'Missing users -> shops relationship, retrying getCurrentUser without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      if (response != null) {
        return UserModel.fromJson(response);
      }

      // users 행이 없는 Auth 사용자에 대비해 정보를 동기화하고 재시도한다.
      final resolvedUser = await _syncUserFromAuth(authUser);
      return resolvedUser;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // 사용자 ID로 정보 가져오기
  Future<UserModel?> getUserById(String userId) async {
    try {
      Future<Map<String, dynamic>?> runQuery(bool includeShop) {
        final selectClause = includeShop
            ? '*, shops!shops_owner_id_fkey(*)'
            : '*';
        return _client
            .from('users')
            .select(selectClause)
            .eq('id', userId)
            .maybeSingle();
      }

      Map<String, dynamic>? response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingShopRelationship(e)) {
          print(
            'Missing users -> shops relationship, retrying getUserById without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      print('Error getting user by id: $e');
      return null;
    }
  }

  // 전화번호로 사용자 확인
  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final variants = <String>{cleaned};
      if (cleaned.length == 11) {
        variants.add(
          '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}',
        );
      }

      final filter = variants.map((p) => 'phone.eq.$p').join(',');

      Future<Map<String, dynamic>?> runQuery(bool includeShop) {
        final selectClause = includeShop
            ? '*, shops!shops_owner_id_fkey(*)'
            : '*';
        return _client
            .from('users')
            .select(selectClause)
            .or(filter)
            .maybeSingle();
      }

      Map<String, dynamic>? response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingShopRelationship(e)) {
          print(
            'Missing users -> shops relationship, retrying getUserByPhone without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      print('Error getting user by phone: $e');
      return null;
    }
  }

  // 새 사용자 생성
  Future<UserModel?> createUser({
    required String email,
    required String name,
    required String phone,
    String? profileImage,
  }) async {
    try {
      final tempPassword = _generateSecurePassword();

      // Auth에 사용자 생성
      final authResponse = await _client.auth.signUp(
        email: email,
        password: tempPassword,
        data: {'name': name, 'phone': phone},
      );

      if (authResponse.user == null) {
        throw Exception('인증 사용자 생성에 실패했습니다. 다시 시도해주세요.');
      }

      // Users 테이블에 추가 (DB 트리거가 자동으로 샵을 생성함)
      final userResponse = await _client
          .from('users')
          .insert({
            'id': authResponse.user!.id,
            'email': email,
            'name': name,
            'phone': phone,
            'profile_image': profileImage,
            'is_verified': false,
            'role': '일반',
          })
          .select()
          .single();

      // 샵 생성 확인 (트리거가 실행되지 않은 경우 수동 생성)
      await _ensureUserShopCreated(authResponse.user!.id, name);

      return UserModel.fromJson(userResponse);
    } catch (e) {
      print('Error creating user: $e');
      return null;
    }
  }

  // 사용자 샵 생성 확인 및 생성
  Future<void> _ensureUserShopCreated(String userId, String userName) async {
    try {
      final shopService = ShopService();
      final shop = await shopService.ensureUserShop(userId, userName);

      if (shop != null) {
        final userRecord = await _client
            .from('users')
            .select('shop_id')
            .eq('id', userId)
            .maybeSingle();

        if (userRecord != null && userRecord['shop_id'] == null) {
          await _client
              .from('users')
              .update({'shop_id': shop.id})
              .eq('id', userId);
        }
      }
    } catch (e) {
      print('Error ensuring user shop: $e');
    }
  }

  // 사용자 정보 업데이트
  Future<bool> updateUser({
    required String userId,
    String? name,
    String? profileImage,
    String? role,
    bool? isVerified,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (profileImage != null) updates['profile_image'] = profileImage;
      if (role != null) updates['role'] = role;
      if (isVerified != null) updates['is_verified'] = isVerified;

      await _client.from('users').update(updates).eq('id', userId);

      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // 사용자 프로필 업데이트
  Future<bool> updateUserProfile({
    required String userId,
    String? name,
    String? profileImage,
    String? bankName,
    String? accountHolder,
    bool? showAccountForNormal,
  }) async {
    bool tableUpdated = false;
    bool metadataUpdated = false;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (profileImage != null) updates['profile_image'] = profileImage;
    if (bankName != null) updates['bank_name'] = bankName;
    if (accountHolder != null) updates['account_holder'] = accountHolder;
    if (showAccountForNormal != null) {
      updates['show_account_for_normal'] = showAccountForNormal;
    }

    if (updates.isNotEmpty) {
      try {
        await _client.from('users').update(updates).eq('id', userId);
        tableUpdated = true;
      } on PostgrestException catch (e) {
        print('Users 테이블 업데이트 실패: ${e.message}');

        final missingColumn = _extractMissingColumn(e.message);
        if (missingColumn != null) {
          updates.remove(missingColumn);
          if (updates.isNotEmpty) {
            try {
              await _client.from('users').update(updates).eq('id', userId);
              tableUpdated = true;
            } catch (retryError) {
              print('Users 테이블 재시도 실패: $retryError');
    }
  }

  String _generateSecurePassword({int length = 32}) {
    final random = Random.secure();
    final buffer = StringBuffer();

    while (buffer.length < length) {
      final bytes = List<int>.generate(length, (_) => random.nextInt(256));
      buffer.write(base64Url.encode(bytes));
    }

    return buffer.toString().substring(0, length);
  }
}
      } catch (e) {
        print('Error updating user profile: $e');
      }
    }

    final metadataUpdates = <String, dynamic>{};
    if (bankName != null) metadataUpdates['bank_name'] = bankName;
    if (accountHolder != null)
      metadataUpdates['account_holder'] = accountHolder;
    if (showAccountForNormal != null) {
      metadataUpdates['show_account_for_normal'] = showAccountForNormal;
    }

    if (metadataUpdates.isNotEmpty) {
      metadataUpdated = await _updateAuthMetadata(metadataUpdates);
    }

    return tableUpdated || metadataUpdated;
  }

  String? _extractMissingColumn(String? message) {
    if (message == null) return null;
    final patterns = [
      RegExp(r"'([a-zA-Z0-9_]+)' column"),
      RegExp(r'column "([a-zA-Z0-9_]+)" does not exist'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }

    return null;
  }

  Future<bool> _updateAuthMetadata(Map<String, dynamic> updates) async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return false;

      final metadata = Map<String, dynamic>.from(authUser.userMetadata ?? {});
      metadata.addAll(updates);

      final response = await _client.auth.updateUser(
        UserAttributes(data: metadata),
      );
      if (response.user == null) {
        print('Auth metadata 업데이트 실패: 응답에 user가 없습니다');
        return false;
      }
      return true;
    } catch (e) {
      print('Auth metadata 업데이트 실패: $e');
      return false;
    }
  }

  // 프로필 이미지 업로드
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      print('📷 프로필 이미지 업로드 시작');

      // 프로필 이미지 압축
      final compressedFile = await ImageCompressionService.compressImage(
        imageFile,
        maxWidth: 800,
        maxHeight: 800,
        quality: 90,
        maxFileSize: 1 * 1024 * 1024, // 1MB
      );

      if (compressedFile == null) {
        print('⚠️ 프로필 이미지 압축 실패');
        return null;
      }

      final bytes = await compressedFile.readAsBytes();
      final fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      print(
        '📦 압축된 프로필 이미지 업로드: ${(bytes.length / 1024).toStringAsFixed(1)}KB',
      );

      await _client.storage
          .from('profile-images')
          .uploadBinary(fileName, bytes);

      final url = _client.storage.from('profile-images').getPublicUrl(fileName);

      // 임시 압축 파일 삭제
      if (compressedFile.path != imageFile.path) {
        try {
          await compressedFile.delete();
        } catch (e) {
          print('임시 파일 삭제 실패: $e');
        }
      }

      return url;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  // 전화번호 인증 상태 업데이트
  Future<bool> verifyPhone(String userId) async {
    try {
      await _client
          .from('users')
          .update({'is_verified': true})
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Error verifying phone: $e');
      return false;
    }
  }

  // 사용자 샵 정보 가져오기
  Future<ShopModel?> getUserShop(String userId) async {
    try {
      final response = await _client
          .from('shops')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ShopModel.fromJson(response);
    } catch (e) {
      print('Error getting user shop: $e');
      return null;
    }
  }

  // 사용자 역할 업데이트 (관리자 기능)
  Future<bool> updateUserRole(String userId, String role) async {
    try {
      await _client.from('users').update({'role': role}).eq('id', userId);

      return true;
    } catch (e) {
      print('Error updating user role: $e');
      return false;
    }
  }

  // 모든 사용자 목록 가져오기 (관리자 기능)
  Future<List<UserModel>> getAllUsers({
    int limit = 50,
    int offset = 0,
    String? role,
  }) async {
    try {
      Future<List<dynamic>> runQuery(bool includeShop) async {
        var query = _client
            .from('users')
            .select(includeShop ? '*, shops!shops_owner_id_fkey(*)' : '*');

        if (role != null) {
          query = query.eq('role', role);
        }

        final response = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        if (response is List) return response;
        return [];
      }

      List<dynamic> response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingShopRelationship(e)) {
          print(
            'Missing users -> shops relationship, retrying getAllUsers without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      return response.map((user) => UserModel.fromJson(user)).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // 사용자 삭제 (soft delete - 실제로는 비활성화)
  Future<bool> deleteUser(String userId) async {
    try {
      // Auth에서 사용자 삭제
      await _client.auth.admin.deleteUser(userId);

      // DB에서도 삭제
      await _client.from('users').delete().eq('id', userId);

      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // 사용자 통계 가져오기
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      // 판매 상품 수
      final productCount = await _client
          .from('products')
          .select('id')
          .eq('seller_id', userId)
          .count();

      // 거래 수
      final transactionCount = await _client
          .from('transactions')
          .select('id')
          .or('buyer_id.eq.$userId,seller_id.eq.$userId,reseller_id.eq.$userId')
          .count();

      // 받은 리뷰 수
      final reviewCount = await _client
          .from('reviews')
          .select('id')
          .eq('reviewed_user_id', userId)
          .count();

      return {
        'product_count': productCount,
        'transaction_count': transactionCount,
        'review_count': reviewCount,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {};
    }
  }

  Future<UserModel?> _syncUserFromAuth(User authUser) async {
    try {
      final metadata = authUser.userMetadata ?? <String, dynamic>{};
      final now = DateTime.now();
      final resolvedPhone = _resolvePhone(authUser, metadata);
      final resolvedName = _resolveName(authUser, metadata, resolvedPhone);

      final payload = <String, dynamic>{
        'id': authUser.id,
        'email': authUser.email,
        'name': resolvedName,
        'phone': resolvedPhone,
        'is_verified': metadata['is_verified'] is bool
            ? metadata['is_verified']
            : true,
        'role': _resolveRole(metadata['role']),
        'profile_image': metadata['profile_image'],
        'shop_id': metadata['shop_id'],
        'created_at': _resolveCreatedAt(metadata['created_at'], now),
        'updated_at': now.toIso8601String(),
      };

      payload.removeWhere((key, value) => value == null);

      try {
        await _client.from('users').upsert(payload);
      } catch (e) {
        print('Error syncing auth user to users table: $e');
      }

      Future<Map<String, dynamic>?> runQuery(bool includeShop) {
        final selectClause = includeShop
            ? '*, shops!shops_owner_id_fkey(*)'
            : '*';
        return _client
            .from('users')
            .select(selectClause)
            .eq('id', authUser.id)
            .maybeSingle();
      }

      Map<String, dynamic>? retry;
      try {
        retry = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingShopRelationship(e)) {
          print(
            'Missing users -> shops relationship, retrying auth sync lookup without join',
          );
          retry = await runQuery(false);
        } else {
          rethrow;
        }
      }

      if (retry != null) {
        return UserModel.fromJson(retry);
      }

      return UserModel(
        id: authUser.id,
        email: authUser.email,
        name: resolvedName.isNotEmpty ? resolvedName : '사용자',
        phone: resolvedPhone,
        isVerified: payload['is_verified'] as bool? ?? true,
        profileImage: payload['profile_image'] as String?,
        role: payload['role'] as String? ?? '일반',
        shopId: payload['shop_id'] as String?,
        createdAt:
            DateTime.tryParse(payload['created_at'] as String? ?? '') ?? now,
        updatedAt: now,
      );
    } catch (e) {
      print('Error creating fallback user model: $e');
      return null;
    }
  }

  String _resolveRole(dynamic rawRole) {
    if (rawRole is String && rawRole.trim().isNotEmpty) {
      return rawRole.trim();
    }
    return '일반';
  }

  String _resolvePhone(User authUser, Map<String, dynamic> metadata) {
    final authPhone = authUser.phone;
    if (authPhone is String && authPhone.isNotEmpty) {
      final normalized = _normalizePhone(authPhone);
      if (_isValidPhoneFormat(normalized)) {
        return normalized;
      }
    }

    final metaPhone = metadata['phone'];
    if (metaPhone is String && metaPhone.trim().isNotEmpty) {
      final normalized = _normalizePhone(metaPhone.trim());
      if (_isValidPhoneFormat(normalized)) {
        return normalized;
      }
    }

    final email = authUser.email;
    if (email is String && email.isNotEmpty) {
      final prefix = email.split('@').first;
      final normalized = _normalizePhone(prefix);
      if (_isValidPhoneFormat(normalized)) {
        return normalized;
      }
    }

    return '';
  }

  String _normalizePhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 11 && digitsOnly.startsWith('01')) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
    }
    return digitsOnly;
  }

  bool _isValidPhoneFormat(String phone) {
    if (phone.isEmpty) return false;
    return RegExp(r'^01[0-9]-?[0-9]{4}-?[0-9]{4}$').hasMatch(phone);
  }

  String _resolveName(
    User authUser,
    Map<String, dynamic> metadata,
    String resolvedPhone,
  ) {
    final metaName = metadata['name'];
    if (metaName is String && metaName.trim().isNotEmpty) {
      return metaName.trim();
    }

    final email = authUser.email;
    if (email is String && email.isNotEmpty) {
      return email.split('@').first;
    }

    final digits = resolvedPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final suffixStart = digits.length >= 4 ? digits.length - 4 : 0;
      return '사용자${digits.substring(suffixStart)}';
    }

    return '사용자';
  }

  String _resolveCreatedAt(dynamic rawCreatedAt, DateTime fallback) {
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      return rawCreatedAt;
    }
    if (rawCreatedAt is DateTime) {
      return rawCreatedAt.toIso8601String();
    }
    return fallback.toIso8601String();
  }
}
