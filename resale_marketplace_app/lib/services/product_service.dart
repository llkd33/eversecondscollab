import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/product_model.dart';

class ProductService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 상품 생성
  Future<ProductModel?> createProduct({
    required String title,
    required int price,
    required String category,
    required String sellerId,
    String? description,
    List<String>? images,
    bool resaleEnabled = false,
    int? resaleFee,
    double? resaleFeePercentage,
  }) async {
    try {
      // 수수료 계산 (퍼센티지가 있으면 자동 계산)
      int calculatedResaleFee = resaleFee ?? 0;
      if (resaleEnabled && resaleFeePercentage != null && resaleFeePercentage > 0) {
        calculatedResaleFee = (price * resaleFeePercentage / 100).round();
      }

      final response = await _client.from('products').insert({
        'title': title,
        'price': price,
        'description': description,
        'images': images ?? [],
        'category': category,
        'seller_id': sellerId,
        'resale_enabled': resaleEnabled,
        'resale_fee': calculatedResaleFee,
        'resale_fee_percentage': resaleFeePercentage ?? 0,
        'status': '판매중',
      }).select().single();

      return ProductModel.fromJson(response);
    } catch (e) {
      print('Error creating product: $e');
      rethrow;
    }
  }

  // 상품 ID로 조회
  Future<ProductModel?> getProductById(String productId) async {
    try {
      final response = await _client
          .from('products')
          .select('*, users!seller_id(name, profile_image)')
          .eq('id', productId)
          .single();

      final product = ProductModel.fromJson(response);
      
      // 판매자 정보 추가
      if (response['users'] != null) {
        return product.copyWith(
          sellerName: response['users']['name'],
          sellerProfileImage: response['users']['profile_image'],
        );
      }
      
      return product;
    } catch (e) {
      print('Error getting product by id: $e');
      return null;
    }
  }

  // 상품 목록 조회 (필터링 포함)
  Future<List<ProductModel>> getProducts({
    String? category,
    String? status,
    String? searchQuery,
    bool? resaleEnabled,
    String? sellerId,
    int limit = 20,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var query = _client
          .from('products')
          .select('*, users!seller_id(name, profile_image)');

      // 필터 적용
      if (category != null) query = query.eq('category', category);
      if (status != null) query = query.eq('status', status);
      if (resaleEnabled != null) query = query.eq('resale_enabled', resaleEnabled);
      if (sellerId != null) query = query.eq('seller_id', sellerId);
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      // 정렬 및 페이징
      final response = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      final supabaseList = (response as List).map((item) {
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
      return supabaseList;
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  // 내 상품 목록 조회
  Future<List<ProductModel>> getMyProducts(String userId) async {
    return getProducts(sellerId: userId);
  }

  // 대신팔기 가능한 상품 목록 조회
  Future<List<ProductModel>> getResaleProducts() async {
    return getProducts(
      resaleEnabled: true,
      status: '판매중',
    );
  }

  // 상품 업데이트
  Future<bool> updateProduct({
    required String productId,
    String? title,
    int? price,
    String? description,
    List<String>? images,
    String? category,
    bool? resaleEnabled,
    double? resaleFeePercentage,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (price != null) updates['price'] = price;
      if (description != null) updates['description'] = description;
      if (images != null) updates['images'] = images;
      if (category != null) updates['category'] = category;
      if (resaleEnabled != null) updates['resale_enabled'] = resaleEnabled;
      if (resaleFeePercentage != null) {
        updates['resale_fee_percentage'] = resaleFeePercentage;
      }
      if (status != null) updates['status'] = status;

      await _client
          .from('products')
          .update(updates)
          .eq('id', productId);

      return true;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  // 상품 판매완료 처리
  Future<bool> markAsSold(String productId) async {
    return updateProduct(productId: productId, status: '판매완료');
  }

  // 상품 삭제
  Future<bool> deleteProduct(String productId) async {
    try {
      await _client
          .from('products')
          .delete()
          .eq('id', productId);

      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  // 카테고리별 상품 개수 조회
  Future<Map<String, int>> getProductCountByCategory() async {
    try {
      final response = await _client
          .from('products')
          .select('category')
          .eq('status', '판매중');

      final counts = <String, int>{};
      for (final item in response) {
        final category = item['category'] as String;
        counts[category] = (counts[category] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      print('Error getting product count by category: $e');
      return {};
    }
  }

  // 인기 상품 조회 (조회수 또는 찜 기반)
  Future<List<ProductModel>> getPopularProducts({int limit = 10}) async {
    try {
      // 현재는 최신 상품을 인기 상품으로 대체
      // 추후 조회수나 찜 기능 구현 시 수정
      return getProducts(
        status: '판매중',
        limit: limit,
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      print('Error getting popular products: $e');
      return [];
    }
  }

  // 상품 검색 (제목, 설명, 카테고리 기반)
  Future<List<ProductModel>> searchProducts({
    required String query,
    String? category,
    int? minPrice,
    int? maxPrice,
    String? sortBy,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var supabaseQuery = _client
          .from('products')
          .select('*, users!seller_id(name, profile_image)')
          .eq('status', '판매중');

      // 카테고리 필터
      if (category != null && category.isNotEmpty) {
        supabaseQuery = supabaseQuery.eq('category', category);
      }
      
      // 가격 필터
      if (minPrice != null) {
        supabaseQuery = supabaseQuery.gte('price', minPrice);
      }
      if (maxPrice != null) {
        supabaseQuery = supabaseQuery.lte('price', maxPrice);
      }

      // 검색어 필터 (제목 또는 설명에서 검색)
      if (query.isNotEmpty) {
        supabaseQuery = supabaseQuery.or('title.ilike.%$query%,description.ilike.%$query%');
      }
      
      // 정렬 설정 및 범위 지정
      String orderColumn = 'created_at';
      bool ascending = false;
      
      if (sortBy != null) {
        switch (sortBy) {
          case 'price_low':
            orderColumn = 'price';
            ascending = true;
            break;
          case 'price_high':
            orderColumn = 'price';
            ascending = false;
            break;
          case 'popular':
          case 'recent':
          default:
            orderColumn = 'created_at';
            ascending = false;
            break;
        }
      }

      final response = await supabaseQuery
          .order(orderColumn, ascending: ascending)
          .range(offset, offset + limit - 1);

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
      print('Error searching products: $e');
      return [];
    }
  }

  // 카테고리별 상품 조회
  Future<List<ProductModel>> getProductsByCategory({
    required String category,
    int limit = 20,
    int offset = 0,
  }) async {
    return getProducts(
      category: category,
      status: '판매중',
      limit: limit,
      offset: offset,
      orderBy: 'created_at',
      ascending: false,
    );
  }

  // 최신 상품 조회
  Future<List<ProductModel>> getLatestProducts({
    int limit = 20,
    int offset = 0,
  }) async {
    return getProducts(
      status: '판매중',
      limit: limit,
      offset: offset,
      orderBy: 'created_at',
      ascending: false,
    );
  }

  // 상품 이미지 업로드
  Future<String?> uploadProductImage(File imageFile, String fileName) async {
    try {
      final bytes = await imageFile.readAsBytes();
      await _client.storage
          .from('product-images')
          .uploadBinary(fileName, bytes);

      final url = _client.storage
          .from('product-images')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      print('Error uploading product image: $e');
      return null;
    }
  }

  // 여러 상품 이미지 업로드
  Future<List<String>> uploadProductImages(
    List<File> imageFiles,
    String userId,
  ) async {
    final uploadedUrls = <String>[];
    
    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        final bytes = await file.readAsBytes();
        await _client.storage
            .from('product-images')
            .uploadBinary(fileName, bytes);
        
        final url = _client.storage
            .from('product-images')
            .getPublicUrl(fileName);
        
        uploadedUrls.add(url);
      }
      
      return uploadedUrls;
    } catch (e) {
      print('Error uploading product images: $e');
      // 실패한 경우 이미 업로드된 이미지 삭제
      for (final url in uploadedUrls) {
        final fileName = url.split('/').last;
        await deleteProductImage(fileName);
      }
      return [];
    }
  }

  // 상품 이미지 삭제
  Future<bool> deleteProductImage(String fileName) async {
    try {
      await _client.storage
          .from('product-images')
          .remove([fileName]);

      return true;
    } catch (e) {
      print('Error deleting product image: $e');
      return false;
    }
  }
}
