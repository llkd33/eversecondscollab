import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

      // 검색어가 있는 경우 검색 기록에 저장 (백그라운드에서 실행)
      if (query != null && query.trim().isNotEmpty) {
        // 검색 기록 저장은 비동기로 처리하여 검색 결과 반환을 지연시키지 않음
        saveSearchTerm(query.trim()).catchError((e) {
          print('검색어 저장 중 오류: $e');
        });
      }

      return SearchResult(
        products: products,
        totalCount: products.length,
        hasMore: products.length == searchFilter.limit,
        filter: searchFilter,
      );
    } catch (error) {
      throw Exception('상품 검색에 실패했습니다. 다시 시도해주세요.');
    }
  }

  /// 인기 검색어 조회
  Future<List<String>> getPopularSearchTerms({int limit = 10}) async {
    try {
      // 실제로는 서버에서 검색 통계를 기반으로 인기 검색어를 가져와야 함
      // 현재는 기본 인기 검색어와 최근 검색어를 조합하여 반환
      final basePopularTerms = ['아이폰', '맥북', '에어팟', '갤럭시', '아이패드', '닌텐도', '스위치', '애플워치'];
      final recentTerms = await getRecentSearchTerms(limit: 5);
      
      final combinedTerms = <String>{};
      combinedTerms.addAll(recentTerms);
      combinedTerms.addAll(basePopularTerms);
      
      return combinedTerms.take(limit).toList();
    } catch (e) {
      print('인기 검색어 조회 실패: $e');
      return ['아이폰', '맥북', '에어팟', '갤럭시', '아이패드'];
    }
  }

  /// 최근 검색어 조회
  Future<List<String>> getRecentSearchTerms({int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchHistory = prefs.getStringList('search_history') ?? [];
      return searchHistory.take(limit).toList();
    } catch (e) {
      print('최근 검색어 조회 실패: $e');
      return [];
    }
  }

  /// 검색어 저장
  Future<void> saveSearchTerm(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchHistory = prefs.getStringList('search_history') ?? [];
      
      // 기존에 있던 검색어 제거 (중복 방지)
      searchHistory.remove(searchTerm.trim());
      
      // 맨 앞에 추가
      searchHistory.insert(0, searchTerm.trim());
      
      // 최대 50개까지만 저장
      if (searchHistory.length > 50) {
        searchHistory.removeRange(50, searchHistory.length);
      }
      
      await prefs.setStringList('search_history', searchHistory);
    } catch (e) {
      print('검색어 저장 실패: $e');
    }
  }

  /// 검색 기록 삭제
  Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
    } catch (e) {
      print('검색 기록 삭제 실패: $e');
    }
  }

  /// 특정 검색어 삭제
  Future<void> removeSearchTerm(String searchTerm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchHistory = prefs.getStringList('search_history') ?? [];
      searchHistory.remove(searchTerm);
      await prefs.setStringList('search_history', searchHistory);
    } catch (e) {
      print('검색어 삭제 실패: $e');
    }
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
      throw Exception('추천 상품을 불러오는데 실패했습니다. 다시 시도해주세요.');
    }
  }

  /// 자동완성 검색어 조회
  Future<List<String>> getAutoCompleteTerms(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // 실제로는 서버에서 자동완성 데이터를 가져와야 함
      // 현재는 기본적인 매칭 로직으로 구현
      final popularTerms = await getPopularSearchTerms(limit: 20);
      final recentTerms = await getRecentSearchTerms(limit: 20);
      
      final allTerms = <String>{};
      allTerms.addAll(popularTerms);
      allTerms.addAll(recentTerms);
      
      // 쿼리와 매칭되는 항목 필터링
      final matchedTerms = allTerms
          .where((term) => term.toLowerCase().contains(query.toLowerCase()))
          .take(limit)
          .toList();
      
      return matchedTerms;
    } catch (e) {
      print('자동완성 검색어 조회 실패: $e');
      return [];
    }
  }

  /// 검색 제안어 조회 (제품명 기반)
  Future<List<String>> getSearchSuggestions(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // 제품 테이블에서 제목을 기반으로 검색 제안어 생성
      final response = await _supabase
          .from('products')
          .select('title')
          .ilike('title', '%${query.trim()}%')
          .eq('status', '판매중')
          .limit(limit * 2); // 중복 제거를 위해 더 많이 가져옴
      
      final titles = (response as List)
          .map((item) => item['title'] as String)
          .toSet() // 중복 제거
          .take(limit)
          .toList();
      
      return titles;
    } catch (e) {
      print('검색 제안어 조회 실패: $e');
      return [];
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
