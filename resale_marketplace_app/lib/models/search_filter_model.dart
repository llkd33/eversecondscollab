/// 🔍 Search Filter Model
/// Advanced search filters for product discovery
class SearchFilterModel {
  final String? query;
  final String? category;
  final int? minPrice;
  final int? maxPrice;
  final String? location;
  final ProductCondition? condition;
  final bool? resaleEnabled;
  final SortBy sortBy;
  final bool ascending;
  final Set<String> selectedTags;

  SearchFilterModel({
    this.query,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.location,
    this.condition,
    this.resaleEnabled,
    this.sortBy = SortBy.newest,
    this.ascending = false,
    this.selectedTags = const {},
  });

  /// Copy with method for easy updates
  SearchFilterModel copyWith({
    String? query,
    String? category,
    int? minPrice,
    int? maxPrice,
    String? location,
    ProductCondition? condition,
    bool? resaleEnabled,
    SortBy? sortBy,
    bool? ascending,
    Set<String>? selectedTags,
  }) {
    return SearchFilterModel(
      query: query ?? this.query,
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      location: location ?? this.location,
      condition: condition ?? this.condition,
      resaleEnabled: resaleEnabled ?? this.resaleEnabled,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      selectedTags: selectedTags ?? this.selectedTags,
    );
  }

  /// Check if any filters are applied
  bool get hasFilters {
    return category != null ||
        minPrice != null ||
        maxPrice != null ||
        location != null ||
        condition != null ||
        resaleEnabled != null ||
        selectedTags.isNotEmpty;
  }

  /// Get active filter count
  int get activeFilterCount {
    int count = 0;
    if (category != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (location != null) count++;
    if (condition != null) count++;
    if (resaleEnabled != null) count++;
    if (selectedTags.isNotEmpty) count += selectedTags.length;
    return count;
  }

  /// Clear all filters
  SearchFilterModel clearFilters() {
    return SearchFilterModel(
      query: query,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'category': category,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'location': location,
      'condition': condition?.name,
      'resaleEnabled': resaleEnabled,
      'sortBy': sortBy.name,
      'ascending': ascending,
      'selectedTags': selectedTags.toList(),
    };
  }

  /// Create from JSON
  factory SearchFilterModel.fromJson(Map<String, dynamic> json) {
    return SearchFilterModel(
      query: json['query'],
      category: json['category'],
      minPrice: json['minPrice'],
      maxPrice: json['maxPrice'],
      location: json['location'],
      condition: json['condition'] != null
          ? ProductCondition.values.firstWhere((e) => e.name == json['condition'])
          : null,
      resaleEnabled: json['resaleEnabled'],
      sortBy: json['sortBy'] != null
          ? SortBy.values.firstWhere((e) => e.name == json['sortBy'])
          : SortBy.newest,
      ascending: json['ascending'] ?? false,
      selectedTags: Set<String>.from(json['selectedTags'] ?? []),
    );
  }
}

/// Product Condition enum
enum ProductCondition {
  brandNew,
  likeNew,
  used,
  needsRepair;

  String get displayName {
    switch (this) {
      case ProductCondition.brandNew:
        return '새 상품';
      case ProductCondition.likeNew:
        return '거의 새것';
      case ProductCondition.used:
        return '사용감 있음';
      case ProductCondition.needsRepair:
        return '수리 필요';
    }
  }
}

/// Sort options
enum SortBy {
  newest,
  oldest,
  priceLowToHigh,
  priceHighToLow,
  popular,
  nearest;

  String get displayName {
    switch (this) {
      case SortBy.newest:
        return '최신순';
      case SortBy.oldest:
        return '오래된순';
      case SortBy.priceLowToHigh:
        return '가격 낮은순';
      case SortBy.priceHighToLow:
        return '가격 높은순';
      case SortBy.popular:
        return '인기순';
      case SortBy.nearest:
        return '가까운순';
    }
  }

  String get orderByColumn {
    switch (this) {
      case SortBy.newest:
        return 'created_at';
      case SortBy.oldest:
        return 'created_at';
      case SortBy.priceLowToHigh:
        return 'price';
      case SortBy.priceHighToLow:
        return 'price';
      case SortBy.popular:
        return 'view_count';
      case SortBy.nearest:
        return 'distance';
    }
  }

  bool get isAscending {
    return this == SortBy.oldest || this == SortBy.priceLowToHigh;
  }
}

/// Search history entry
class SearchHistoryEntry {
  final String query;
  final DateTime timestamp;

  SearchHistoryEntry({
    required this.query,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      query: json['query'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Saved search
class SavedSearch {
  final String id;
  final String name;
  final SearchFilterModel filter;
  final DateTime createdAt;
  final bool notificationsEnabled;

  SavedSearch({
    required this.id,
    required this.name,
    required this.filter,
    required this.createdAt,
    this.notificationsEnabled = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'filter': filter.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
    };
  }

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'],
      name: json['name'],
      filter: SearchFilterModel.fromJson(json['filter']),
      createdAt: DateTime.parse(json['createdAt']),
      notificationsEnabled: json['notificationsEnabled'] ?? false,
    );
  }
}
