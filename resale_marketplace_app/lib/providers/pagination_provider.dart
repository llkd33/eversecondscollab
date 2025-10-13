import 'package:flutter/material.dart';
import '../widgets/common/loading_widget.dart';
import 'package:provider/provider.dart';

/// 페이지네이션 상태 관리를 위한 추상 클래스
abstract class PaginationProvider<T> extends ChangeNotifier {
  // 페이지네이션 상태
  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  
  // 페이지네이션 설정
  static const int defaultPageSize = 20;
  int _currentPage = 0;
  int _pageSize = defaultPageSize;
  
  // 검색 및 필터
  String? _searchQuery;
  Map<String, dynamic> _filters = {};
  
  // Getters
  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  String? get searchQuery => _searchQuery;
  Map<String, dynamic> get filters => Map.unmodifiable(_filters);
  bool get isEmpty => _items.isEmpty && !_isLoading;
  bool get hasData => _items.isNotEmpty;
  
  /// 데이터 페치 메서드 (하위 클래스에서 구현)
  Future<List<T>> fetchData({
    required int offset,
    required int limit,
    String? search,
    Map<String, dynamic>? filters,
  });
  
  /// 초기 로드
  Future<void> loadInitial({
    String? search,
    Map<String, dynamic>? filters,
    int? pageSize,
  }) async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _searchQuery = search;
    _filters = filters ?? {};
    _pageSize = pageSize ?? defaultPageSize;
    
    notifyListeners();
    
    try {
      final newItems = await fetchData(
        offset: 0,
        limit: _pageSize,
        search: _searchQuery,
        filters: _filters,
      );
      
      _items.addAll(newItems);
      _hasMore = newItems.length >= _pageSize;
      _currentPage = 1;
    } catch (e) {
      _error = e.toString();
      debugPrint('초기 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 다음 페이지 로드
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final offset = _currentPage * _pageSize;
      final newItems = await fetchData(
        offset: offset,
        limit: _pageSize,
        search: _searchQuery,
        filters: _filters,
      );
      
      _items.addAll(newItems);
      _hasMore = newItems.length >= _pageSize;
      _currentPage++;
    } catch (e) {
      _error = e.toString();
      debugPrint('더 불러오기 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 새로고침 (Pull to Refresh)
  Future<void> refresh() async {
    if (_isLoading) return;
    
    // 현재 설정을 유지하면서 처음부터 다시 로드
    await loadInitial(
      search: _searchQuery,
      filters: _filters,
      pageSize: _pageSize,
    );
  }
  
  /// 검색
  Future<void> search(String query) async {
    if (_searchQuery == query) return;
    
    await loadInitial(
      search: query,
      filters: _filters,
      pageSize: _pageSize,
    );
  }
  
  /// 필터 적용
  Future<void> applyFilters(Map<String, dynamic> newFilters) async {
    await loadInitial(
      search: _searchQuery,
      filters: newFilters,
      pageSize: _pageSize,
    );
  }
  
  /// 필터 초기화
  Future<void> clearFilters() async {
    await loadInitial(
      search: _searchQuery,
      filters: {},
      pageSize: _pageSize,
    );
  }
  
  /// 아이템 추가 (로컬)
  void addItem(T item) {
    _items.insert(0, item);
    notifyListeners();
  }
  
  /// 아이템 업데이트 (로컬)
  void updateItem(int index, T item) {
    if (index >= 0 && index < _items.length) {
      _items[index] = item;
      notifyListeners();
    }
  }
  
  /// 아이템 삭제 (로컬)
  void removeItem(T item) {
    _items.remove(item);
    notifyListeners();
  }
  
  /// 아이템 삭제 (인덱스)
  void removeItemAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }
  
  /// 캐시 클리어
  void clearCache() {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }
  
  /// 에러 재시도
  Future<void> retry() async {
    if (_items.isEmpty) {
      await loadInitial(
        search: _searchQuery,
        filters: _filters,
        pageSize: _pageSize,
      );
    } else {
      await loadMore();
    }
  }
}

/// 무한 스크롤 위젯
class InfiniteScrollView<T> extends StatefulWidget {
  final PaginationProvider<T> provider;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final ScrollController? scrollController;
  final double scrollThreshold;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final Widget? separator;
  
  const InfiniteScrollView({
    Key? key,
    required this.provider,
    required this.itemBuilder,
    this.emptyWidget,
    this.loadingWidget,
    this.errorWidget,
    this.scrollController,
    this.scrollThreshold = 200.0,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.separator,
  }) : super(key: key);
  
  @override
  State<InfiniteScrollView<T>> createState() => _InfiniteScrollViewState<T>();
}

class _InfiniteScrollViewState<T> extends State<InfiniteScrollView<T>> {
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.provider.items.isEmpty && !widget.provider.isLoading) {
        widget.provider.loadInitial();
      }
    });
  }
  
  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - widget.scrollThreshold) {
      widget.provider.loadMore();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.provider,
      child: Consumer<PaginationProvider<T>>(
        builder: (context, provider, child) {
          // 초기 로딩
          if (provider.isLoading && provider.items.isEmpty) {
            return widget.loadingWidget ?? _buildDefaultLoading();
          }
          
          // 에러 상태
          if (provider.error != null && provider.items.isEmpty) {
            return widget.errorWidget ?? _buildDefaultError(provider);
          }
          
          // 빈 상태
          if (provider.isEmpty) {
            return widget.emptyWidget ?? _buildDefaultEmpty();
          }
          
          // 데이터 리스트
          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView.separated(
              controller: _scrollController,
              shrinkWrap: widget.shrinkWrap,
              physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              itemCount: provider.items.length + (provider.hasMore ? 1 : 0),
              separatorBuilder: (context, index) => 
                  widget.separator ?? const SizedBox.shrink(),
              itemBuilder: (context, index) {
                // 마지막 아이템: 로딩 인디케이터
                if (index == provider.items.length) {
                  if (provider.isLoading) {
                    return _buildLoadingIndicator();
                  } else if (provider.error != null) {
                    return _buildRetryButton(provider);
                  } else {
                    return const SizedBox.shrink();
                  }
                }
                
                // 일반 아이템
                return widget.itemBuilder(
                  context,
                  provider.items[index],
                  index,
                );
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDefaultLoading() {
    return const LoadingWidget.center(message: '데이터를 불러오는 중...');
  }
  
  Widget _buildDefaultError(PaginationProvider<T> provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            '오류가 발생했습니다',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            provider.error ?? '',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: provider.retry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDefaultEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('데이터가 없습니다'),
        ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
  
  Widget _buildRetryButton(PaginationProvider<T> provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: TextButton(
          onPressed: provider.retry,
          child: const Text('다시 시도'),
        ),
      ),
    );
  }
}

/// 그리드뷰용 무한 스크롤 위젯
class InfiniteScrollGridView<T> extends StatefulWidget {
  final PaginationProvider<T> provider;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final ScrollController? scrollController;
  final double scrollThreshold;
  final EdgeInsets? padding;
  
  const InfiniteScrollGridView({
    Key? key,
    required this.provider,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 10.0,
    this.mainAxisSpacing = 10.0,
    this.emptyWidget,
    this.loadingWidget,
    this.errorWidget,
    this.scrollController,
    this.scrollThreshold = 200.0,
    this.padding,
  }) : super(key: key);
  
  @override
  State<InfiniteScrollGridView<T>> createState() => _InfiniteScrollGridViewState<T>();
}

class _InfiniteScrollGridViewState<T> extends State<InfiniteScrollGridView<T>> {
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.provider.items.isEmpty && !widget.provider.isLoading) {
        widget.provider.loadInitial();
      }
    });
  }
  
  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - widget.scrollThreshold) {
      widget.provider.loadMore();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.provider,
      child: Consumer<PaginationProvider<T>>(
        builder: (context, provider, child) {
          // 초기 로딩
          if (provider.isLoading && provider.items.isEmpty) {
            return widget.loadingWidget ?? 
                   const LoadingWidget.center(message: '데이터를 불러오는 중...');
          }
          
          // 에러 상태
          if (provider.error != null && provider.items.isEmpty) {
            return widget.errorWidget ?? _buildDefaultError(provider);
          }
          
          // 빈 상태
          if (provider.isEmpty) {
            return widget.emptyWidget ?? _buildDefaultEmpty();
          }
          
          // 데이터 그리드
          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: GridView.builder(
              controller: _scrollController,
              padding: widget.padding,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.crossAxisCount,
                childAspectRatio: widget.childAspectRatio,
                crossAxisSpacing: widget.crossAxisSpacing,
                mainAxisSpacing: widget.mainAxisSpacing,
              ),
              itemCount: provider.items.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                // 마지막 아이템: 로딩 인디케이터
                if (index == provider.items.length) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  } else if (provider.error != null) {
                    return Center(
                      child: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: provider.retry,
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }
                
                // 일반 아이템
                return widget.itemBuilder(
                  context,
                  provider.items[index],
                  index,
                );
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDefaultError(PaginationProvider<T> provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('오류가 발생했습니다'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: provider.retry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDefaultEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('데이터가 없습니다'),
        ],
      ),
    );
  }
}
