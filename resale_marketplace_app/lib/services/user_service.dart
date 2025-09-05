import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';
import '../models/shop_model.dart';

class UserService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 현재 로그인한 사용자 정보 가져오기
  Future<UserModel?> getCurrentUser() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return null;

      final response = await _client
          .from('users')
          .select('*, shops(*)')
          .eq('id', authUser.id)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // 사용자 ID로 정보 가져오기
  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('*, shops(*)')
          .eq('id', userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error getting user by id: $e');
      return null;
    }
  }

  // 전화번호로 사용자 확인
  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final response = await _client
          .from('users')
          .select('*, shops(*)')
          .eq('phone', phone)
          .maybeSingle();

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
      // Auth에 사용자 생성
      final authResponse = await _client.auth.signUp(
        email: email,
        password: phone, // 임시로 전화번호를 비밀번호로 사용
        data: {
          'name': name,
          'phone': phone,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create auth user');
      }

      // Users 테이블에 추가
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

      return UserModel.fromJson(userResponse);
    } catch (e) {
      print('Error creating user: $e');
      return null;
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

      await _client
          .from('users')
          .update(updates)
          .eq('id', userId);

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
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (profileImage != null) updates['profile_image'] = profileImage;

      await _client
          .from('users')
          .update(updates)
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  // 프로필 이미지 업로드
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _client.storage
          .from('profile-images')
          .uploadBinary(fileName, bytes);

      final url = _client.storage
          .from('profile-images')
          .getPublicUrl(fileName);

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
          .single();

      return ShopModel.fromJson(response);
    } catch (e) {
      print('Error getting user shop: $e');
      return null;
    }
  }

  // 사용자 역할 업데이트 (관리자 기능)
  Future<bool> updateUserRole(String userId, String role) async {
    try {
      await _client
          .from('users')
          .update({'role': role})
          .eq('id', userId);

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
      var query = _client
          .from('users')
          .select('*, shops(*)');

      if (role != null) {
        query = query.eq('role', role);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (response as List)
          .map((user) => UserModel.fromJson(user))
          .toList();
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
      await _client
          .from('users')
          .delete()
          .eq('id', userId);

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
}
