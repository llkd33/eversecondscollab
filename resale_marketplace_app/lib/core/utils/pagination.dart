/// 페이지네이션 상태 관리 클래스
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const PaginationState({
    required this.items,
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }

  @override
  String toString() {
    return 'PaginationState(items: ${items.length}, isLoading: $isLoading, '
        'hasMore: $hasMore, currentPage: $currentPage, error: $error)';
  }
}
