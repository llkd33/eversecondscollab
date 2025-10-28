import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

/// 상품 목록 상태 관리 Provider
/// 불필요한 setState 호출을 줄이고 효율적인 상태 관리를 제공
class ProductProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();
  
  // 상품 목록
  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;
  
  // 로딩 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  // 페이지네이션
  int _currentPage = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  
  // 필터 옵션
  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;
  String? _searchQuery;
  String? _sortBy;
  
  // 캐시 관리
  final Map<String, List<ProductModel>> _cache = {};
  final Duration _cacheValidDuration = const Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};
  
  /// 캐시 키 생성
  String _getCacheKey() {
    return '${_selectedCategory ?? 'all'}_${_searchQuery ?? ''}_${_sortBy ?? 'latest'}';
  }
  
  /// 캐시가 유효한지 확인
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheValidDuration;
  }
  
  /// 상품 목록 로드 (캐싱 포함)
  Future<void> loadProducts({
    bool refresh = false,
    String? category,
    String? searchQuery,
    String? sortBy,
  }) async {
    // 필터 업데이트
    if (category != null) _selectedCategory = category;
    if (searchQuery != null) _searchQuery = searchQuery;
    if (sortBy != null) _sortBy = sortBy;
    
    // 캐시 확인
    final cacheKey = _getCacheKey();
    if (!refresh && _cache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      _products = _cache[cacheKey]!;
      notifyListeners();
      return;
    }
    
    // 리프레시인 경우 초기화
    if (refresh) {
      _products.clear();
      _currentPage = 0;
      _hasMore = true;
    }
    
    // 이미 로딩 중이면 리턴
    if (_isLoading) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final newProducts = await _productService.getProducts(
        category: _selectedCategory == '전체' ? null : _selectedCategory,
        searchQuery: _searchQuery?.isEmpty ?? true ? null : _searchQuery,
        status: '판매중',
        limit: 20,
        offset: _currentPage * 20,
        orderBy: _sortBy ?? 'created_at',
        ascending: false,
      );
      
      if (refresh) {
        _products = newProducts;
      } else {
        _products.addAll(newProducts);
      }
      
      // 캐시 업데이트
      _cache[cacheKey] = List.from(_products);
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      _hasMore = newProducts.length >= 20;
      _currentPage++;
      
    } catch (e) {
      _errorMessage = '상품을 불러오는데 실패했습니다';
      if (kDebugMode) {
        print('Error loading products: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 더 많은 상품 로드
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading) return;
    await loadProducts();
  }
  
  /// 카테고리 변경
  void changeCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    loadProducts(refresh: true);
  }
  
  /// 검색어 변경
  void changeSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    loadProducts(refresh: true);
  }
  
  /// 정렬 변경
  void changeSortBy(String sortBy) {
    if (_sortBy == sortBy) return;
    _sortBy = sortBy;
    loadProducts(refresh: true);
  }
  
  /// 캐시 클리어
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }
  
  /// 특정 상품 업데이트
  void updateProduct(ProductModel product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      notifyListeners();
    }
  }
  
  /// 특정 상품 삭제
  void removeProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }
  
  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
