import 'dart:math';

import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../utils/uuid.dart';
import 'product_service.dart';

class ShopService {
  final SupabaseClient _client = SupabaseConfig.client;
  final Random _random = Random();
  final ProductService _productService = ProductService();

  bool _isMissingOwnerRelationship(PostgrestException error) {
    if (error.code == 'PGRST200') return true;
    final message = error.message;
    if (message is String && message.contains('PGRST200')) return true;
    if (message != null && message.toString().contains('PGRST200')) return true;
    return false;
  }

  bool _isUndefinedColumn(PostgrestException error, String column) {
    if (error.code == '42703') return true;
    final message = error.message;
    if (message is String && message.contains(column)) return true;
    if (message != null && message.toString().contains(column)) return true;
    return false;
  }

  // 샵 생성 (회원가입 시 자동 생성) - DB 트리거에 의해 자동 생성되므로 수동 생성은 불필요
  Future<ShopModel?> createShop({
    required String ownerId,
    required String name,
    String? description,
  }) async {
    try {
      if (!UuidUtils.isValid(ownerId)) {
        throw Exception('잘못된 사용자 ID입니다. 다시 로그인 후 시도해주세요.');
      }
      // 이미 존재하는 샵이 있는지 확인
      final existingShop = await getShopByOwnerId(ownerId);
      if (existingShop != null) {
        final userRecord = await _client
            .from('users')
            .select('shop_id')
            .eq('id', ownerId)
            .maybeSingle();

        if (userRecord != null && userRecord['shop_id'] == null) {
          await _client
              .from('users')
              .update({'shop_id': existingShop.id})
              .eq('id', ownerId);
        }

        return existingShop;
      }

      final baseShareUrl = _buildBaseShareUrl(ownerId);
      var candidate = baseShareUrl;
      var attempt = 0;
      PostgrestException? lastDuplicateError;

      while (attempt < 6) {
        try {
          final response = await _client
              .from('shops')
              .insert({
                'owner_id': ownerId,
                'name': name,
                'description': description ?? '$name님의 개인 샵입니다.',
                'share_url': candidate,
              })
              .select()
              .single();

          await _client
              .from('users')
              .update({'shop_id': response['id']})
              .eq('id', ownerId);

          return ShopModel.fromJson(response);
        } on PostgrestException catch (error) {
          final isShareUrlConflict = (error.message ?? '').contains(
            'shops_share_url_key',
          );

          if (!isShareUrlConflict) {
            rethrow;
          }

          lastDuplicateError = error;
          attempt += 1;
          candidate = _buildShareUrlWithSuffix(baseShareUrl);
          await Future.delayed(Duration(milliseconds: 30 * attempt));
        }
      }

      final fallbackShareUrl = _buildRandomShareUrl();
      try {
        final response = await _client
            .from('shops')
            .insert({
              'owner_id': ownerId,
              'name': name,
              'description': description ?? '$name님의 개인 샵입니다.',
              'share_url': fallbackShareUrl,
            })
            .select()
            .single();

        await _client
            .from('users')
            .update({'shop_id': response['id']})
            .eq('id', ownerId);

        return ShopModel.fromJson(response);
      } on PostgrestException catch (error) {
        if ((error.message ?? '').contains('shops_share_url_key') &&
            lastDuplicateError != null) {
          throw lastDuplicateError;
        }
        rethrow;
      }
    } catch (e) {
      print('Error creating shop: $e');
      return null;
    }
  }

  // 회원가입 시 자동 샵 생성 확인 및 생성
  Future<ShopModel?> ensureUserShop(String userId, String userName) async {
    try {
      // 기존 샵 확인
      final existingShop = await getShopByOwnerId(userId);
      if (existingShop != null) {
        return existingShop;
      }

      // 샵이 없으면 생성
      return await createShop(
        ownerId: userId,
        name: '$userName의 샵',
        description: '$userName님의 개인 샵입니다.',
      );
    } catch (e) {
      print('Error ensuring user shop: $e');
      return null;
    }
  }

  // 샵 ID로 조회
  Future<ShopModel?> getShopById(String shopId) async {
    try {
      if (!UuidUtils.isValid(shopId)) {
        print('getShopById skipped: invalid UUID "$shopId"');
        return null;
      }
      Future<Map<String, dynamic>?> runQuery(bool includeUser) {
        final selectClause = includeUser
            ? '*, users!owner_id(name, profile_image)'
            : '*';
        return _client
            .from('shops')
            .select(selectClause)
            .eq('id', shopId)
            .maybeSingle();
      }

      Map<String, dynamic>? response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingOwnerRelationship(e)) {
          print(
            'Missing shops -> users relationship, retrying getShopById without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      if (response == null) {
        return null;
      }

      return ShopModel.fromJson(response);
    } catch (e) {
      print('Error getting shop by id: $e');
      return null;
    }
  }

  // 사용자 ID로 샵 조회
  Future<ShopModel?> getShopByOwnerId(String ownerId) async {
    try {
      if (!UuidUtils.isValid(ownerId)) {
        print('getShopByOwnerId skipped: invalid UUID "$ownerId"');
        return null;
      }
      Future<Map<String, dynamic>?> runQuery(bool includeUser) {
        final selectClause = includeUser
            ? '*, users!owner_id(name, profile_image)'
            : '*';
        return _client
            .from('shops')
            .select(selectClause)
            .eq('owner_id', ownerId)
            .maybeSingle();
      }

      Map<String, dynamic>? response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingOwnerRelationship(e)) {
          print(
            'Missing shops -> users relationship, retrying getShopByOwnerId without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      if (response == null) {
        return null;
      }

      return ShopModel.fromJson(response);
    } catch (e) {
      print('Error getting shop by owner id: $e');
      return null;
    }
  }

  // 공유 URL로 샵 조회
  Future<ShopModel?> getShopByShareUrl(String shareUrl) async {
    try {
      Future<Map<String, dynamic>?> runQuery(bool includeUser) {
        final selectClause = includeUser
            ? '*, users!owner_id(name, profile_image)'
            : '*';
        return _client
            .from('shops')
            .select(selectClause)
            .eq('share_url', shareUrl)
            .maybeSingle();
      }

      Map<String, dynamic>? response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingOwnerRelationship(e)) {
          print(
            'Missing shops -> users relationship, retrying getShopByShareUrl without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      if (response == null) {
        return null;
      }

      return ShopModel.fromJson(response);
    } catch (e) {
      print('Error getting shop by share url: $e');
      return null;
    }
  }

  // 샵 정보 업데이트
  Future<bool> updateShop({
    required String shopId,
    String? name,
    String? description,
  }) async {
    try {
      if (!UuidUtils.isValid(shopId)) {
        print('updateShop skipped: invalid UUID "$shopId"');
        return false;
      }
      final updates = <String, dynamic>{};
      if (name != null) {
        if (!ShopModel.isValidShopName(name)) {
          throw ArgumentError('Invalid shop name');
        }
        updates['name'] = name;
      }
      if (description != null) updates['description'] = description;

      if (updates.isEmpty) return true;

      await _client.from('shops').update(updates).eq('id', shopId);

      return true;
    } catch (e) {
      print('Error updating shop: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchShopProductIds(
    String shopId, {
    required bool isResale,
  }) async {
    Future<List<Map<String, dynamic>>> runQuery({
      required bool applyOrder,
    }) async {
      final query = _client
          .from('shop_products')
          .select('product_id')
          .eq('shop_id', shopId)
          .eq('is_resale', isResale);

      final request = applyOrder
          ? query.order('created_at', ascending: false)
          : query;

      final response = await request;
      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    }

    try {
      return await runQuery(applyOrder: true);
    } on PostgrestException catch (e) {
      if (_isUndefinedColumn(e, 'created_at')) {
        print('shop_products.created_at missing, retrying without order');
        return await runQuery(applyOrder: false);
      }
      rethrow;
    }
  }

  // 샵의 직접 등록 상품 조회
  Future<List<ProductModel>> getShopProducts(String shopId) async {
    try {
      final ownerRow = await _client
          .from('shops')
          .select('owner_id')
          .eq('id', shopId)
          .maybeSingle();

      if (ownerRow == null) return [];

      final ownerId = ownerRow['owner_id'] as String?;
      if (ownerId == null || ownerId.isEmpty) return [];

      final response = await _client
          .from('products')
          .select('id')
          .eq('seller_id', ownerId)
          .eq('status', ProductStatus.onSale)
          .order('created_at', ascending: false);

      if (response is! List || response.isEmpty) return [];

      final productIds = <String>[];
      for (final item in response) {
        final id = item['id'] as String?;
        if (id != null && id.isNotEmpty) {
          productIds.add(id);
        }
      }

      if (productIds.isEmpty) return [];

      final products = await _productService.getProductsByIds(productIds);

      if (products.isEmpty) return [];

      final orderMap = <String, int>{};
      for (var i = 0; i < productIds.length; i++) {
        orderMap[productIds[i]] = i;
      }

      products.sort((a, b) {
        final aIndex = orderMap[a.id] ?? 0;
        final bIndex = orderMap[b.id] ?? 0;
        return aIndex.compareTo(bIndex);
      });

      return products;
    } catch (e) {
      print('Error getting shop products: $e');
      return [];
    }
  }

  // 샵의 대신팔기 상품 조회
  Future<List<ProductModel>> getShopResaleProducts(String shopId) async {
    try {
      final rows = await _fetchShopProductIds(shopId, isResale: true);

      if (rows.isEmpty) return [];

      final productIds = <String>[];
      for (final item in rows) {
        final id = item['product_id'] as String?;
        if (id != null && id.isNotEmpty) {
          productIds.add(id);
        }
      }

      if (productIds.isEmpty) return [];

      final products = await _productService.getProductsByIds(productIds);

      if (products.isEmpty) return [];

      final orderMap = <String, int>{};
      for (var i = 0; i < productIds.length; i++) {
        orderMap[productIds[i]] = i;
      }

      products.sort((a, b) {
        final aIndex = orderMap[a.id] ?? 0;
        final bIndex = orderMap[b.id] ?? 0;
        return aIndex.compareTo(bIndex);
      });

      return products;
    } catch (e) {
      print('Error getting shop resale products: $e');
      return [];
    }
  }

  // 대신팔기 상품을 내 샵에 추가
  Future<bool> addResaleProduct({
    required String shopId,
    required String productId,
    required double commissionPercentage,
  }) async {
    try {
      if (!UuidUtils.isValid(shopId) || !UuidUtils.isValid(productId)) {
        print('addResaleProduct skipped: invalid UUIDs');
        return false;
      }
      // 상품 정보 확인
      final productResponse = await _client
          .from('products')
          .select('price, resale_enabled')
          .eq('id', productId)
          .single();

      if (!productResponse['resale_enabled']) {
        throw Exception('This product is not available for resale');
      }

      // 수수료 계산
      final price = productResponse['price'] as int;
      final commissionAmount = (price * commissionPercentage / 100).round();

      // 대신팔기 관계 생성
      await _client.from('shop_products').insert({
        'shop_id': shopId,
        'product_id': productId,
        'is_resale': true,
      });

      return true;
    } catch (e) {
      print('Error adding resale product: $e');
      return false;
    }
  }

  // 대신팔기 상품을 내 샵에서 제거
  Future<bool> removeResaleProduct({
    required String shopId,
    required String productId,
  }) async {
    try {
      if (!UuidUtils.isValid(shopId) || !UuidUtils.isValid(productId)) {
        print('removeResaleProduct skipped: invalid UUIDs');
        return false;
      }
      await _client
          .from('shop_products')
          .delete()
          .eq('shop_id', shopId)
          .eq('product_id', productId)
          .eq('is_resale', true);

      return true;
    } catch (e) {
      print('Error removing resale product: $e');
      return false;
    }
  }

  // 샵 통계 조회
  Future<Map<String, dynamic>> getShopStats(String shopId) async {
    try {
      if (!UuidUtils.isValid(shopId)) {
        print('getShopStats skipped: invalid UUID "$shopId"');
        return {};
      }
      final shop = await getShopById(shopId);
      if (shop == null) return {};

      // 직접 등록 상품 수
      final ownProductCount = await _client
          .from('products')
          .select('id')
          .eq('seller_id', shop.ownerId)
          .count();

      // 대신팔기 상품 수
      final resaleProductCount = await _client
          .from('shop_products')
          .select('id')
          .eq('shop_id', shopId)
          .eq('is_resale', true)
          .count();

      // 총 거래 수
      final transactionCount = await _client
          .from('transactions')
          .select('id')
          .or('seller_id.eq.${shop.ownerId},reseller_id.eq.${shop.ownerId}')
          .eq('status', '거래완료')
          .count();

      return {
        'own_product_count': ownProductCount.count ?? 0,
        'resale_product_count': resaleProductCount.count ?? 0,
        'total_product_count':
            (ownProductCount.count ?? 0) + (resaleProductCount.count ?? 0),
        'transaction_count': transactionCount.count ?? 0,
      };
    } catch (e) {
      print('Error getting shop stats: $e');
      return {};
    }
  }

  // 인기 샵 목록 조회
  Future<List<ShopModel>> getPopularShops({int limit = 10}) async {
    try {
      Future<List<dynamic>> runQuery(bool includeUser) async {
        final selectClause = includeUser
            ? '*, users!owner_id(name, profile_image)'
            : '*';
        final response = await _client
            .from('shops')
            .select(selectClause)
            .order('created_at', ascending: false)
            .limit(limit);

        if (response is List) return response;
        return [];
      }

      List<dynamic> response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingOwnerRelationship(e)) {
          print(
            'Missing shops -> users relationship, retrying getPopularShops without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      return response.map((shop) => ShopModel.fromJson(shop)).toList();
    } catch (e) {
      print('Error getting popular shops: $e');
      return [];
    }
  }

  // 샵 검색
  Future<List<ShopModel>> searchShops({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      Future<List<dynamic>> runQuery(bool includeUser) async {
        final selectClause = includeUser
            ? '*, users!owner_id(name, profile_image)'
            : '*';
        final response = await _client
            .from('shops')
            .select(selectClause)
            .or('name.ilike.%$query%,description.ilike.%$query%')
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        if (response is List) return response;
        return [];
      }

      List<dynamic> response;
      try {
        response = await runQuery(true);
      } on PostgrestException catch (e) {
        if (_isMissingOwnerRelationship(e)) {
          print(
            'Missing shops -> users relationship, retrying searchShops without join',
          );
          response = await runQuery(false);
        } else {
          rethrow;
        }
      }

      return response.map((shop) => ShopModel.fromJson(shop)).toList();
    } catch (e) {
      print('Error searching shops: $e');
      return [];
    }
  }

  // 샵 삭제 (실제로는 비활성화)
  Future<bool> deleteShop(String shopId) async {
    try {
      if (!UuidUtils.isValid(shopId)) {
        print('deleteShop skipped: invalid UUID "$shopId"');
        return false;
      }
      // 대신팔기 관계 모두 삭제
      await _client.from('shop_resale_products').delete().eq('shop_id', shopId);

      // 샵 삭제
      await _client.from('shops').delete().eq('id', shopId);

      return true;
    } catch (e) {
      print('Error deleting shop: $e');
      return false;
    }
  }

  String _buildBaseShareUrl(String ownerId) {
    final sanitized = ownerId.replaceAll('-', '');
    final truncated = sanitized.length >= 12
        ? sanitized.substring(0, 12)
        : sanitized.padRight(12, '0');
    return 'shop-$truncated';
  }

  String _buildShareUrlWithSuffix(String baseShareUrl) {
    return '$baseShareUrl-${_randomToken(6)}';
  }

  String _buildRandomShareUrl() {
    return 'shop-${_randomToken(12)}';
  }

  String _randomToken(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}
