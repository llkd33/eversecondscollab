import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'pagination_provider.dart';

/// 상품 목록 페이지네이션 Provider
class ProductPaginationProvider extends PaginationProvider<ProductModel> {
  final ProductService _productService = ProductService();

  // 필터 옵션
  String? _category;
  double? _minPrice;
  double? _maxPrice;
  String? _status;
  String? _userId;
  String _sortBy = 'created_at';
  bool _sortDescending = true;

  // Getters
  String? get category => _category;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  String? get status => _status;
  String? get userId => _userId;
  String get sortBy => _sortBy;
  bool get sortDescending => _sortDescending;

  @override
  Future<List<ProductModel>> fetchData({
    required int offset,
    required int limit,
    String? search,
    Map<String, dynamic>? filters,
  }) async {
    try {
      // 필터 파싱
      _parseFilters(filters);

      final statusFilter = (_status != null && _status!.isNotEmpty)
          ? _status
          : ProductStatus.onSale;

      final minPriceInt = _minPrice != null ? _minPrice!.round() : null;
      final maxPriceInt = _maxPrice != null ? _maxPrice!.round() : null;

      final products = await _productService.getProducts(
        category: _category,
        status: statusFilter,
        searchQuery: search,
        sellerId: _userId,
        minPrice: minPriceInt,
        maxPrice: maxPriceInt,
        limit: limit,
        offset: offset,
        orderBy: _sortBy,
        ascending: !_sortDescending,
      );

      return products;
    } catch (e) {
      debugPrint('상품 데이터 페치 실패: $e');
      throw Exception('상품을 불러오는데 실패했습니다');
    }
  }

  /// 필터 파싱
  void _parseFilters(Map<String, dynamic>? filters) {
    if (filters == null) return;

    _category = filters['category'];
    _minPrice = filters['minPrice']?.toDouble();
    _maxPrice = filters['maxPrice']?.toDouble();
    _status = filters['status'];
    _userId = filters['userId'];
    _sortBy = filters['sortBy'] ?? 'created_at';
    _sortDescending = filters['sortDescending'] ?? true;
  }

  /// 카테고리 필터 설정
  Future<void> setCategory(String? category) async {
    if (_category == category) return;

    _category = category;
    await loadInitial(search: searchQuery, filters: _buildFilters());
  }

  /// 가격 범위 필터 설정
  Future<void> setPriceRange(double? min, double? max) async {
    if (_minPrice == min && _maxPrice == max) return;

    _minPrice = min;
    _maxPrice = max;
    await loadInitial(search: searchQuery, filters: _buildFilters());
  }

  /// 정렬 설정
  Future<void> setSorting(String sortBy, {bool descending = true}) async {
    if (_sortBy == sortBy && _sortDescending == descending) return;

    _sortBy = sortBy;
    _sortDescending = descending;
    await loadInitial(search: searchQuery, filters: _buildFilters());
  }

  /// 사용자별 필터 설정
  Future<void> setUserId(String? userId) async {
    if (_userId == userId) return;

    _userId = userId;
    await loadInitial(search: searchQuery, filters: _buildFilters());
  }

  /// 상태 필터 설정
  Future<void> setStatus(String? status) async {
    if (_status == status) return;

    _status = status;
    await loadInitial(search: searchQuery, filters: _buildFilters());
  }

  /// 필터 맵 생성
  Map<String, dynamic> _buildFilters() {
    return {
      if (_category != null) 'category': _category,
      if (_minPrice != null) 'minPrice': _minPrice,
      if (_maxPrice != null) 'maxPrice': _maxPrice,
      if (_status != null) 'status': _status,
      if (_userId != null) 'userId': _userId,
      'sortBy': _sortBy,
      'sortDescending': _sortDescending,
    };
  }

  /// 찜하기 토글
  Future<void> toggleFavorite(ProductModel product) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('로그인이 필요합니다');

      final isFavorite = await _checkIsFavorite(product.id, currentUser.id);

      if (isFavorite) {
        await Supabase.instance.client
            .from('user_favorites')
            .delete()
            .eq('product_id', product.id)
            .eq('user_id', currentUser.id);
      } else {
        await Supabase.instance.client.from('user_favorites').insert({
          'product_id': product.id,
          'user_id': currentUser.id,
        });
      }

      // 로컬 상태 업데이트
      final index = items.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        updateItem(index, items[index].copyWith());
      }
    } catch (e) {
      debugPrint('찜하기 토글 실패: $e');
      throw Exception('찜하기 처리에 실패했습니다');
    }
  }

  /// 찜 여부 확인
  Future<bool> _checkIsFavorite(String productId, String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_favorites')
          .select('id')
          .eq('product_id', productId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// 상품 삭제
  Future<void> deleteProduct(String productId) async {
    try {
      await _productService.deleteProduct(productId);

      // 로컬 상태에서 제거
      removeItem(items.firstWhere((p) => p.id == productId));
    } catch (e) {
      debugPrint('상품 삭제 실패: $e');
      throw Exception('상품 삭제에 실패했습니다');
    }
  }

  /// 상품 상태 변경
  Future<void> updateProductStatus(String productId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('products')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      // 로컬 상태 업데이트
      final index = items.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final product = items[index];
        updateItem(
          index,
          product.copyWith(status: newStatus, updatedAt: DateTime.now()),
        );
      }
    } catch (e) {
      debugPrint('상품 상태 변경 실패: $e');
      throw Exception('상품 상태 변경에 실패했습니다');
    }
  }
}

/// 사용자 상품 목록 Provider
class UserProductPaginationProvider extends ProductPaginationProvider {
  UserProductPaginationProvider(String userId) {
    setUserId(userId);
  }
}

/// 찜 목록 Provider
class FavoriteProductPaginationProvider
    extends PaginationProvider<ProductModel> {
  @override
  Future<List<ProductModel>> fetchData({
    required int offset,
    required int limit,
    String? search,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('로그인이 필요합니다');

      var query = Supabase.instance.client
          .from('user_favorites')
          .select(
            'products!inner(*, users!seller_id(name, profile_image), product_images(*))',
          )
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);

      final response = await query.range(offset, offset + limit - 1);

      // Product 모델로 변환
      return (response as List)
          .map((json) => ProductModel.fromJson(json['products']))
          .toList();
    } catch (e) {
      debugPrint('찜 목록 페치 실패: $e');
      throw Exception('찜 목록을 불러오는데 실패했습니다');
    }
  }
}

/// 카테고리별 상품 Provider
class CategoryProductPaginationProvider extends ProductPaginationProvider {
  CategoryProductPaginationProvider(String category) {
    setCategory(category);
  }
}

/// 검색 결과 Provider
class SearchProductPaginationProvider extends ProductPaginationProvider {
  SearchProductPaginationProvider(String searchQuery) {
    search(searchQuery);
  }
}
