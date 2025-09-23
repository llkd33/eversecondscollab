import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/product_model.dart';
import '../utils/uuid.dart';

class ProductService {
  final SupabaseClient _client = SupabaseConfig.client;
  static const _productSellerSelect = '*, users!seller_id(name, profile_image)';

  bool _isMissingSellerRelationship(PostgrestException error) {
    if (error.code == 'PGRST200') return true;
    final message = error.message;
    if (message is String && message.contains('PGRST200')) return true;
    if (message != null && message.toString().contains('PGRST200')) return true;
    return false;
  }

  Future<List<ProductModel>> getProductsByIds(
    List<String> ids, {
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    if (ids.isEmpty) return [];

    var buildQuery = (bool includeSeller) {
      return _client
          .from('products')
          .select(includeSeller ? _productSellerSelect : '*')
          .inFilter('id', ids)
          .order(orderBy, ascending: ascending);
    };

    Future<List<Map<String, dynamic>>> runQuery(bool includeSeller) async {
      final response = await buildQuery(includeSeller);
      if (response is! List) return [];
      final items = response.cast<Map<String, dynamic>>();
      if (!includeSeller) await _attachSellerInfo(items);
      return items;
    }

    try {
      final items = await runQuery(true);
      return items.map(ProductModel.fromJson).toList();
    } on PostgrestException catch (e) {
      if (_isMissingSellerRelationship(e)) {
        print(
          'Missing products -> users relationship, retrying getProductsByIds without join',
        );
        final fallback = await runQuery(false);
        return fallback.map(ProductModel.fromJson).toList();
      }
      print('Error getting products by ids: $e');
      return [];
    } catch (e) {
      print('Error getting products by ids: $e');
      return [];
    }
  }

  Future<void> _attachSellerInfo(List<Map<String, dynamic>> rows) async {
    final sellerIds = <String>{};
    for (final row in rows) {
      final sellerId = row['seller_id'] as String?;
      if (sellerId != null && sellerId.isNotEmpty && row['users'] == null) {
        sellerIds.add(sellerId);
      }
    }

    if (sellerIds.isEmpty) return;

    try {
      final sellerResponse = await _client
          .from('users')
          .select('id, name, profile_image')
          .inFilter('id', sellerIds.toList());

      if (sellerResponse is! List) return;

      final sellers = <String, Map<String, dynamic>>{};
      for (final item in sellerResponse) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String?;
          if (id != null) sellers[id] = item;
        }
      }

      for (final row in rows) {
        final sellerId = row['seller_id'] as String?;
        if (sellerId != null && sellers.containsKey(sellerId)) {
          row['users'] = sellers[sellerId];
        }
      }
    } catch (e) {
      print('Failed to attach seller info fallback: $e');
    }
  }

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
      if (resaleEnabled &&
          resaleFeePercentage != null &&
          resaleFeePercentage > 0) {
        calculatedResaleFee = (price * resaleFeePercentage / 100).round();
      }

      // 수수료가 상품 가격보다 클 수 없음
      if (calculatedResaleFee > price) {
        calculatedResaleFee = price;
      }

      print('Creating product with data:');
      print('- title: $title');
      print('- price: $price');
      print('- category: $category');
      print('- sellerId: $sellerId');
      print('- resaleEnabled: $resaleEnabled');
      print('- calculatedResaleFee: $calculatedResaleFee');
      print('- resaleFeePercentage: $resaleFeePercentage');

      final response = await _client
          .from('products')
          .insert({
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
          })
          .select()
          .single();

      print('Product created successfully: ${response['id']}');
      return ProductModel.fromJson(response);
    } catch (e) {
      print('Error creating product: $e');
      print('Error details: ${e.toString()}');
      if (e is PostgrestException) {
        print('PostgrestException details:');
        print('- code: ${e.code}');
        print('- message: ${e.message}');
        print('- details: ${e.details}');
        print('- hint: ${e.hint}');
      }
      rethrow;
    }
  }

  // 상품 ID로 조회
  Future<ProductModel?> getProductById(String productId) async {
    if (!UuidUtils.isValid(productId)) {
      print('getProductById skipped: invalid UUID "$productId"');
      return null;
    }

    Future<Map<String, dynamic>?> runQuery(bool includeSeller) async {
      final selectClause = includeSeller ? _productSellerSelect : '*';
      final builder = _client
          .from('products')
          .select(selectClause)
          .eq('id', productId);

      final result = includeSeller
          ? await builder.single()
          : await builder.maybeSingle();

      if (result is Map<String, dynamic>) {
        if (!includeSeller) {
          await _attachSellerInfo([result]);
        }
        return result;
      }
      return null;
    }

    try {
      final response = await runQuery(true);
      if (response != null) return ProductModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (_isMissingSellerRelationship(e)) {
        print(
          'Missing products -> users relationship, retrying getProductById without join',
        );
        final fallback = await runQuery(false);
        if (fallback != null) return ProductModel.fromJson(fallback);
      }
      print('Error getting product by id: $e');
    } catch (e) {
      print('Error getting product by id: $e');
    }
    return null;
  }

  // 상품 목록 조회 (필터링 포함)
  Future<List<ProductModel>> getProducts({
    String? category,
    String? status,
    String? searchQuery,
    bool? resaleEnabled,
    String? sellerId,
    int? minPrice,
    int? maxPrice,
    int limit = 20,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    var buildQuery = (bool includeSeller) {
      var query = _client
          .from('products')
          .select(includeSeller ? _productSellerSelect : '*');

      if (category != null) query = query.eq('category', category);
      if (status != null) query = query.eq('status', status);
      if (resaleEnabled != null) {
        query = query.eq('resale_enabled', resaleEnabled);
      }
      if (sellerId != null) query = query.eq('seller_id', sellerId);
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'title.ilike.%$searchQuery%,description.ilike.%$searchQuery%',
        );
      }
      if (minPrice != null) {
        query = query.gte('price', minPrice);
      }
      if (maxPrice != null) {
        query = query.lte('price', maxPrice);
      }
      return query;
    };

    Future<List<ProductModel>> runQuery(bool includeSeller) async {
      final response = await buildQuery(
        includeSeller,
      ).order(orderBy, ascending: ascending).range(offset, offset + limit - 1);

      if (response is! List) return [];
      final items = response.cast<Map<String, dynamic>>();
      if (!includeSeller) {
        await _attachSellerInfo(items);
      }
      return items.map(ProductModel.fromJson).toList();
    }

    try {
      return await runQuery(true);
    } on PostgrestException catch (e) {
      if (_isMissingSellerRelationship(e)) {
        print(
          'Missing products -> users relationship, retrying getProducts without join',
        );
        return await runQuery(false);
      }
      print('Error getting products: $e');
      return [];
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
    return getProducts(resaleEnabled: true, status: '판매중');
  }

  // 대신팔기 가능한 상품 목록 조회 (필터링 포함)
  Future<List<ProductModel>> getResaleEnabledProducts({
    String? category,
    String? searchQuery,
    int? minPrice,
    int? maxPrice,
    double? minCommissionRate,
    int limit = 20,
    int offset = 0,
  }) async {
    var buildQuery = (bool includeSeller) {
      var query = _client
          .from('products')
          .select(includeSeller ? _productSellerSelect : '*')
          .eq('resale_enabled', true)
          .eq('status', '판매중');

      if (category != null && category != '전체') {
        query = query.eq('category', category);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'title.ilike.%$searchQuery%,description.ilike.%$searchQuery%',
        );
      }

      if (minPrice != null) {
        query = query.gte('price', minPrice);
      }

      if (maxPrice != null) {
        query = query.lte('price', maxPrice);
      }

      if (minCommissionRate != null) {
        query = query.gte('resale_fee_percentage', minCommissionRate);
      }

      return query;
    };

    Future<List<ProductModel>> runQuery(bool includeSeller) async {
      final response = await buildQuery(
        includeSeller,
      ).order('created_at', ascending: false).range(offset, offset + limit - 1);

      if (response is! List) return [];
      final items = response.cast<Map<String, dynamic>>();
      if (!includeSeller) await _attachSellerInfo(items);
      return items.map(ProductModel.fromJson).toList();
    }

    try {
      return await runQuery(true);
    } on PostgrestException catch (e) {
      if (_isMissingSellerRelationship(e)) {
        print(
          'Missing products -> users relationship, retrying getResaleEnabledProducts without join',
        );
        return await runQuery(false);
      }
      print('Error getting resale enabled products: $e');
      return [];
    } catch (e) {
      print('Error getting resale enabled products: $e');
      return [];
    }
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
      if (!UuidUtils.isValid(productId)) {
        print('updateProduct skipped: invalid UUID "$productId"');
        return false;
      }
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (price != null) updates['price'] = price;
      if (description != null) updates['description'] = description;
      if (images != null) updates['images'] = images;
      if (category != null) updates['category'] = category;
      if (resaleEnabled != null) updates['resale_enabled'] = resaleEnabled;
      if (resaleFeePercentage != null) {
        updates['resale_fee_percentage'] = resaleFeePercentage;
        // 수수료 금액도 자동 계산하여 업데이트
        if (price != null) {
          updates['resale_fee'] = (price * resaleFeePercentage / 100).round();
        }
      }
      if (status != null) updates['status'] = status;

      await _client.from('products').update(updates).eq('id', productId);

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
      if (!UuidUtils.isValid(productId)) {
        print('deleteProduct skipped: invalid UUID "$productId"');
        return false;
      }
      await _client.from('products').delete().eq('id', productId);

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
    var buildQuery = (bool includeSeller) {
      var supabaseQuery = _client
          .from('products')
          .select(includeSeller ? _productSellerSelect : '*')
          .eq('status', '판매중');

      if (category != null && category.isNotEmpty) {
        supabaseQuery = supabaseQuery.eq('category', category);
      }

      if (minPrice != null) {
        supabaseQuery = supabaseQuery.gte('price', minPrice);
      }
      if (maxPrice != null) {
        supabaseQuery = supabaseQuery.lte('price', maxPrice);
      }

      if (query.isNotEmpty) {
        supabaseQuery = supabaseQuery.or(
          'title.ilike.%$query%,description.ilike.%$query%',
        );
      }

      return supabaseQuery;
    };

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

    Future<List<ProductModel>> runQuery(bool includeSeller) async {
      final response = await buildQuery(includeSeller)
          .order(orderColumn, ascending: ascending)
          .range(offset, offset + limit - 1);

      if (response is! List) return [];
      final items = response.cast<Map<String, dynamic>>();
      if (!includeSeller) await _attachSellerInfo(items);
      return items.map(ProductModel.fromJson).toList();
    }

    try {
      return await runQuery(true);
    } on PostgrestException catch (e) {
      if (_isMissingSellerRelationship(e)) {
        print(
          'Missing products -> users relationship, retrying searchProducts without join',
        );
        return await runQuery(false);
      }
      print('Error searching products: $e');
      return [];
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

      final url = _client.storage.from('product-images').getPublicUrl(fileName);

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
    final uploadedFileNames = <String>[];

    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        final extension = file.path.split('.').last.toLowerCase();
        final validExtensions = ['jpg', 'jpeg', 'png', 'webp'];

        if (!validExtensions.contains(extension)) {
          throw Exception('지원하지 않는 이미지 형식입니다: $extension');
        }

        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';

        final bytes = await file.readAsBytes();

        // 파일 크기 체크 (10MB 제한)
        if (bytes.length > 10 * 1024 * 1024) {
          throw Exception('이미지 파일 크기가 너무 큽니다 (최대 10MB)');
        }

        await _client.storage
            .from('product-images')
            .uploadBinary(fileName, bytes);

        final url = _client.storage
            .from('product-images')
            .getPublicUrl(fileName);

        uploadedUrls.add(url);
        uploadedFileNames.add(fileName);
      }

      return uploadedUrls;
    } catch (e) {
      print('Error uploading product images: $e');
      // 실패한 경우 이미 업로드된 이미지 삭제
      for (final fileName in uploadedFileNames) {
        await deleteProductImage(fileName);
      }
      rethrow;
    }
  }

  // 상품 이미지 삭제
  Future<bool> deleteProductImage(String fileName) async {
    try {
      await _client.storage.from('product-images').remove([fileName]);

      return true;
    } catch (e) {
      print('Error deleting product image: $e');
      return false;
    }
  }
}
