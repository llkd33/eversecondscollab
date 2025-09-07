import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';

class ShopService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 샵 생성 (회원가입 시 자동 생성) - DB 트리거에 의해 자동 생성되므로 수동 생성은 불필요
  Future<ShopModel?> createShop({
    required String ownerId,
    required String name,
    String? description,
  }) async {
    try {
      // 이미 존재하는 샵이 있는지 확인
      final existingShop = await getShopByOwnerId(ownerId);
      if (existingShop != null) {
        return existingShop;
      }

      // 샵 URL 생성 (사용자 ID 기반)
      final shareUrl = 'shop-${ownerId.replaceAll('-', '').substring(0, 12)}';
      
      final response = await _client.from('shops').insert({
        'owner_id': ownerId,
        'name': name,
        'description': description ?? '$name님의 개인 샵입니다.',
        'share_url': shareUrl,
      }).select().single();

      // 사용자 테이블의 shop_id 업데이트
      await _client
          .from('users')
          .update({'shop_id': response['id']})
          .eq('id', ownerId);

      return ShopModel.fromJson(response);
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
      final response = await _client
          .from('shops')
          .select('*, users!owner_id(name, profile_image)')
          .eq('id', shopId)
          .single();

      return ShopModel.fromJson(response);
    } catch (e) {
      print('Error getting shop by id: $e');
      return null;
    }
  }

  // 사용자 ID로 샵 조회
  Future<ShopModel?> getShopByOwnerId(String ownerId) async {
    try {
      final response = await _client
          .from('shops')
          .select('*, users!owner_id(name, profile_image)')
          .eq('owner_id', ownerId)
          .single();

      return ShopModel.fromJson(response);
    } catch (e) {
      print('Error getting shop by owner id: $e');
      return null;
    }
  }

  // 공유 URL로 샵 조회
  Future<ShopModel?> getShopByShareUrl(String shareUrl) async {
    try {
      final response = await _client
          .from('shops')
          .select('*, users!owner_id(name, profile_image)')
          .eq('share_url', shareUrl)
          .single();

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
      final updates = <String, dynamic>{};
      if (name != null) {
        if (!ShopModel.isValidShopName(name)) {
          throw ArgumentError('Invalid shop name');
        }
        updates['name'] = name;
      }
      if (description != null) updates['description'] = description;

      if (updates.isEmpty) return true;

      await _client
          .from('shops')
          .update(updates)
          .eq('id', shopId);

      return true;
    } catch (e) {
      print('Error updating shop: $e');
      return false;
    }
  }

  // 샵의 직접 등록 상품 조회
  Future<List<ProductModel>> getShopProducts(String shopId) async {
    try {
      final shop = await getShopById(shopId);
      if (shop == null) return [];

      final response = await _client
          .from('products')
          .select('*, users!seller_id(name, profile_image)')
          .eq('seller_id', shop.ownerId)
          .eq('status', '판매중')
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final product = ProductModel.fromJson(item);
        
        // 판매자 정보 추가
        if (item['users'] != null) {
          return product.copyWith(
            sellerName: item['users']['name'],
            sellerProfileImage: item['users']['profile_image'],
          );
        }
        
        return product;
      }).toList();
    } catch (e) {
      print('Error getting shop products: $e');
      return [];
    }
  }

  // 샵의 대신팔기 상품 조회
  Future<List<ProductModel>> getShopResaleProducts(String shopId) async {
    try {
      // 대신팔기 상품은 shop_products 테이블을 통해 관리
      final response = await _client
          .from('shop_products')
          .select('''
            products!product_id (
              *,
              users!seller_id(name, profile_image)
            )
          ''')
          .eq('shop_id', shopId)
          .eq('is_resale', true);

      return (response as List).map((item) {
        final productData = item['products'];
        final product = ProductModel.fromJson(productData);
        
        // 판매자 정보 추가
        if (productData['users'] != null) {
          return product.copyWith(
            sellerName: productData['users']['name'],
            sellerProfileImage: productData['users']['profile_image'],
          );
        }
        
        return product;
      }).toList();
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
        'total_product_count': (ownProductCount.count ?? 0) + (resaleProductCount.count ?? 0),
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
      // 상품 수가 많은 샵 순으로 정렬
      final response = await _client
          .from('shops')
          .select('*, users!owner_id(name, profile_image)')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((shop) => ShopModel.fromJson(shop))
          .toList();
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
      final response = await _client
          .from('shops')
          .select('*, users!owner_id(name, profile_image)')
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((shop) => ShopModel.fromJson(shop))
          .toList();
    } catch (e) {
      print('Error searching shops: $e');
      return [];
    }
  }

  // 샵 삭제 (실제로는 비활성화)
  Future<bool> deleteShop(String shopId) async {
    try {
      // 대신팔기 관계 모두 삭제
      await _client
          .from('shop_resale_products')
          .delete()
          .eq('shop_id', shopId);

      // 샵 삭제
      await _client
          .from('shops')
          .delete()
          .eq('id', shopId);

      return true;
    } catch (e) {
      print('Error deleting shop: $e');
      return false;
    }
  }
}