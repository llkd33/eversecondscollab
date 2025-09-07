import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../utils/error_handler.dart';

enum SortOption {
  latest,
  priceAsc,
  priceDesc,
  popular,
  distance,
}

class SearchFilter {
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final String? location;
  final bool? isResaleEnabled;
  final List<String>? conditions;
  final SortOption sortBy;
  final int page;
  final int limit;

  const SearchFilter({
    this.category,
    this.minPrice,
    this.maxPrice,
    this.location,
    this.isResaleEnabled,
    this.conditions,
    this.sortBy = SortOption.latest,
    this.page = 1,
    this.limit = 20,
  });

  SearchFilter copyWith({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? location,
    bool? isResaleEnabled,
    List<String>? conditions,
    SortOption? sortBy,
    int? page,
    int? limit,
  }) {
    return SearchFilter(
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      location: location ?? this.location,
      isResaleEnabled: isResaleEnabled ?? this.isResaleEnabled,
      conditions: conditions ?? this.conditions,
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'min_price': minPrice,
      'max_price': maxPrice,
      'location': location,
      'is_resale_enabled': isResaleEnabled,
      'conditions': conditions,
      'sort_by': sortBy.name,
      'page': page,
      'limit': limit,
    };
  }
}

class SearchResult {
  final List<Product> products;
  final int totalCount;
  final bool hasMore;
  final SearchFilter filter;

  const SearchResult({
    required this.products,
    required this.totalCount,
    required this.hasMore,
    required this.filter,
  });
}

class SearchService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 상품 검색
  Future<SearchResult> searchProducts({
    String? query,
    SearchFilter? filter,
  }) async {
    try {
      final searchFilter = filter ?? const SearchFilter();
      
      // 기본 쿼리 구성
      var queryBuilder = _supabase
          .from('products')
          .select('''
            *,
            seller:users!products_seller_id_fkey(
              id, name, profile_image_url, level, rating
            ),
            shop:shops!products_shop_id_fkey(
              id, name, description
            )
          ''');

      // 검색어 필터링
      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'title.ilike.%$query%,description.ilike.%$query%,category.ilike.%$query%'
        );
      }

      // 카테고리 필터링
      if (searchFilter.category != null) {
        queryBuilder = queryBuilder.eq('category', searchFilter.category!);
      }

      // 가격 범위 필터링
      if (searchFilter.minPrice != null) {
        queryBuilder = queryBuilder.gte('price', searchFilter.minPrice!);
      }
      if (searchFilter.maxPrice != null) {
        queryBuilder = queryBuilder.lte('price', searchFilter.maxPrice!);
      }

      // 지역 필터링
      if (searchFilter.location != null) {
        queryBuilder = queryBuilder.eq('location', searchFilter.location!);
      }

      // 대신팔기 가능 여부
      if (searchFilter.isResaleEnabled != null) {
        queryBuilder = queryBuilder.eq('is_resale_enabled', searchFilter.isResaleEnabled!);
      }

      // 상품 상태 필터링
      if (searchFilter.conditions != null && searchFilter.conditions!.isNotEmpty) {
        queryBuilder = queryBuilder.in_('condition', searchFilter.conditions!);
      }

      // 판매중인 상품만
      queryBuilder = queryBuilder.eq('status', '판매중');

      // 정렬
      queryBuilder = _applySorting(queryBuilder, searchFilter.sortBy);

      // 페이징
      final offset = (searchFilter.page - 1) * searchFilter.limit;
      queryBuilder = queryBuilder.range(offset, offset + searchFilter.limit - 1);

      final response = await queryBuilder;
      
      // 전체 개수 조회
      final countResponse = await _getSearchCount(query, searchFilter);
      
      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      return SearchResult(
        products: products,
        totalCount: countResponse,
        hasMore: products.length == searchFilter.limit,
        filter: searchFilter,
      );
    } catch (error, stackTrace) {
      throw AppError.fromException(
        Exception('Failed to search products: $error'),
        stackTrace: stackTrace,
      );
    }
  }

  /// 인기 검색어 조회
  Future<List<String>> getPopularSearchTerms({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('search_logs')
          .select('search_term, count(*)')
          .gte('created_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
          .order('count', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => item['search_term'] as String)
          .toList();
    } catch (error) {
      // 에러 시 기본 인기 검색어 반환
      return ['아이폰', '맥북', '에어팟', '갤럭시', '아이패드'];
    }
  }

  /// 최근 검색어 조회
  Future<List<String>> getRecentSearchTerms({int limit = 10}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('user_search_history')
          .select('search_term')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => item['search_term'] as String)
          .toList();
    } catch (error) {
      return [];
    }
  }

  /// 검색어 저장
  Future<void> saveSearchTerm(String searchTerm) async {
    try {
      final user = _supabase.auth.currentUser;
      
      // 검색 로그 저장 (통계용)
      await _supabase.from('search_logs').insert({
        'search_term': searchTerm,
        'user_id': user?.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 사용자 검색 기록 저장
      if (user != null) {
        await _supabase.from('user_search_history').upsert({
          'user_id': user.id,
          'search_term': searchTerm,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (error) {
      // 검색어 저장 실패는 무시 (핵심 기능이 아니므로)
    }
  }

  /// 검색 기록 삭제
  Future<void> clearSearchHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('user_search_history')
          .delete()
          .eq('user_id', user.id);
    } catch (error) {
      throw AppError.fromException(
        Exception('Failed to clear search history: $error'),
      );
    }
  }

  /// 카테고리 목록 조회
  Future<List<String>> getCategories() async {
    try {
      final response = await _supabase
          .from('products')
          .select('category')
          .not('category', 'is', null);

      final categories = (response as List)
          .map((item) => item['category'] as String)
          .toSet()
          .toList();

      categories.sort();
      return categories;
    } catch (error) {
      // 기본 카테고리 반환
      return [
        '전자기기',
        '의류',
        '도서',
        '생활용품',
        '스포츠',
        '뷰티',
        '기타',
      ];
    }
  }

  /// 지역 목록 조회
  Future<List<String>> getLocations() async {
    try {
      final response = await _supabase
          .from('products')
          .select('location')
          .not('location', 'is', null);

      final locations = (response as List)
          .map((item) => item['location'] as String)
          .toSet()
          .toList();

      locations.sort();
      return locations;
    } catch (error) {
      // 기본 지역 반환
      return [
        '서울특별시',
        '부산광역시',
        '대구광역시',
        '인천광역시',
        '광주광역시',
        '대전광역시',
        '울산광역시',
        '세종특별자치시',
        '경기도',
        '강원도',
        '충청북도',
        '충청남도',
        '전라북도',
        '전라남도',
        '경상북도',
        '경상남도',
        '제주특별자치도',
      ];
    }
  }

  /// 추천 상품 조회
  Future<List<Product>> getRecommendedProducts({
    String? userId,
    int limit = 10,
  }) async {
    try {
      // 사용자 기반 추천 (구매/관심 기록 기반)
      if (userId != null) {
        // TODO: 실제 추천 알고리즘 구현
        // 현재는 인기 상품으로 대체
      }

      // 인기 상품 조회 (조회수, 찜 수 기반)
      final response = await _supabase
          .from('products')
          .select('''
            *,
            seller:users!products_seller_id_fkey(
              id, name, profile_image_url, level, rating
            ),
            shop:shops!products_shop_id_fkey(
              id, name, description
            )
          ''')
          .eq('status', '판매중')
          .order('view_count', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (error, stackTrace) {
      throw AppError.fromException(
        Exception('Failed to get recommended products: $error'),
        stackTrace: stackTrace,
      );
    }
  }

  /// 정렬 적용
  PostgrestFilterBuilder _applySorting(
    PostgrestFilterBuilder queryBuilder,
    SortOption sortBy,
  ) {
    switch (sortBy) {
      case SortOption.latest:
        return queryBuilder.order('created_at', ascending: false);
      case SortOption.priceAsc:
        return queryBuilder.order('price', ascending: true);
      case SortOption.priceDesc:
        return queryBuilder.order('price', ascending: false);
      case SortOption.popular:
        return queryBuilder.order('view_count', ascending: false);
      case SortOption.distance:
        // TODO: 위치 기반 정렬 구현
        return queryBuilder.order('created_at', ascending: false);
    }
  }

  /// 검색 결과 개수 조회
  Future<int> _getSearchCount(String? query, SearchFilter filter) async {
    var countQuery = _supabase
        .from('products')
        .select('id', const FetchOptions(count: CountOption.exact));

    // 동일한 필터 조건 적용
    if (query != null && query.isNotEmpty) {
      countQuery = countQuery.or(
        'title.ilike.%$query%,description.ilike.%$query%,category.ilike.%$query%'
      );
    }

    if (filter.category != null) {
      countQuery = countQuery.eq('category', filter.category!);
    }

    if (filter.minPrice != null) {
      countQuery = countQuery.gte('price', filter.minPrice!);
    }
    if (filter.maxPrice != null) {
      countQuery = countQuery.lte('price', filter.maxPrice!);
    }

    if (filter.location != null) {
      countQuery = countQuery.eq('location', filter.location!);
    }

    if (filter.isResaleEnabled != null) {
      countQuery = countQuery.eq('is_resale_enabled', filter.isResaleEnabled!);
    }

    if (filter.conditions != null && filter.conditions!.isNotEmpty) {
      countQuery = countQuery.in_('condition', filter.conditions!);
    }

    countQuery = countQuery.eq('status', '판매중');

    final response = await countQuery;
    return response.count ?? 0;
  }
}