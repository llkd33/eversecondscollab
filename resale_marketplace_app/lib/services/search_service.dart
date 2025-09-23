import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

enum SortOption { latest, priceAsc, priceDesc, popular, distance }

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
}

class SearchResult {
  final List<ProductModel> products;
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
      var queryBuilder = _supabase.from('products').select('*');

      // 검색어 필터링
      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'title.ilike.%$query%,description.ilike.%$query%,category.ilike.%$query%',
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
        queryBuilder = queryBuilder.eq(
          'is_resale_enabled',
          searchFilter.isResaleEnabled!,
        );
      }

      // 판매중인 상품만
      queryBuilder = queryBuilder.eq('status', '판매중');

      // 정렬 및 페이징을 포함한 최종 쿼리 실행
      final offset = (searchFilter.page - 1) * searchFilter.limit;

      final response = await queryBuilder
          .order(
            _getSortColumn(searchFilter.sortBy),
            ascending: _getSortAscending(searchFilter.sortBy),
          )
          .range(offset, offset + searchFilter.limit - 1);

      final products = (response as List)
          .map((json) => ProductModel.fromJson(json))
          .toList();

      return SearchResult(
        products: products,
        totalCount: products.length,
        hasMore: products.length == searchFilter.limit,
        filter: searchFilter,
      );
    } catch (error) {
      throw Exception('Failed to search products: $error');
    }
  }

  /// 인기 검색어 조회
  Future<List<String>> getPopularSearchTerms({int limit = 10}) async {
    // 기본 인기 검색어 반환
    return ['아이폰', '맥북', '에어팟', '갤럭시', '아이패드'];
  }

  /// 최근 검색어 조회
  Future<List<String>> getRecentSearchTerms({int limit = 10}) async {
    // 기본 빈 리스트 반환
    return [];
  }

  /// 검색어 저장
  Future<void> saveSearchTerm(String searchTerm) async {
    // 검색어 저장 로직 (현재는 빈 구현)
  }

  /// 검색 기록 삭제
  Future<void> clearSearchHistory() async {
    // 검색 기록 삭제 로직 (현재는 빈 구현)
  }

  /// 카테고리 목록 조회
  Future<List<String>> getCategories() async {
    return ['전자기기', '의류', '도서', '생활용품', '스포츠', '뷰티', '기타'];
  }

  /// 지역 목록 조회
  Future<List<String>> getLocations() async {
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

  /// 추천 상품 조회
  Future<List<ProductModel>> getRecommendedProducts({
    String? userId,
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .select('*')
          .eq('status', '판매중')
          .order('view_count', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ProductModel.fromJson(json))
          .toList();
    } catch (error) {
      throw Exception('Failed to get recommended products: $error');
    }
  }

  String _getSortColumn(SortOption sortBy) {
    switch (sortBy) {
      case SortOption.latest:
        return 'created_at';
      case SortOption.priceAsc:
      case SortOption.priceDesc:
        return 'price';
      case SortOption.popular:
        return 'view_count';
      case SortOption.distance:
        return 'created_at';
    }
  }

  bool _getSortAscending(SortOption sortBy) {
    switch (sortBy) {
      case SortOption.latest:
        return false;
      case SortOption.priceAsc:
        return true;
      case SortOption.priceDesc:
        return false;
      case SortOption.popular:
        return false;
      case SortOption.distance:
        return false;
    }
  }
}
