import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/offline_banner.dart';
import '../../services/enhanced_search_service.dart';
import '../../models/product_model.dart';
import '../../models/search_filter_model.dart';
import '../../utils/error_handler.dart';
import '../../utils/app_logger.dart';

/// 🔍 고급 검색 화면 - Enhanced with better UX and performance
class EnhancedSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const EnhancedSearchScreen({super.key, this.initialQuery});

  @override
  State<EnhancedSearchScreen> createState() => _EnhancedSearchScreenState();
}

class _EnhancedSearchScreenState extends State<EnhancedSearchScreen>
    with ErrorHandlerMixin, SingleTickerProviderStateMixin {
  final _logger = AppLogger.scoped('EnhancedSearch');
  final TextEditingController _searchController = TextEditingController();
  final EnhancedSearchService _searchService = EnhancedSearchService();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _debounce;
  List<ProductModel> _searchResults = [];
  List<String> _searchSuggestions = [];
  List<SavedSearch> _savedSearches = [];
  SearchFilterModel _filter = SearchFilterModel();

  bool _isLoading = false;
  bool _showSuggestions = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _filter = _filter.copyWith(query: widget.initialQuery);
      _performSearch();
    } else {
      _loadSavedSearches();
    }
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSearches() async {
    try {
      final saved = await _searchService.getSavedSearches();
      if (mounted) {
        setState(() => _savedSearches = saved);
      }
    } catch (e) {
      _logger.w('Failed to load saved searches', e);
    }
  }

  void _onSearchTextChanged() {
    final query = _searchController.text;

    // Debounce search suggestions
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isNotEmpty && query.length >= 2) {
        _loadSuggestions(query);
      } else {
        setState(() {
          _searchSuggestions.clear();
          _showSuggestions = true;
        });
      }
    });
  }

  Future<void> _loadSuggestions(String query) async {
    try {
      final suggestions = await _searchService.getSearchSuggestions(query);
      if (mounted) {
        setState(() => _searchSuggestions = suggestions);
      }
    } catch (e) {
      _logger.w('Failed to load suggestions', e);
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _showSuggestions = false;
      _searchSuggestions.clear();
    });
    _searchFocusNode.unfocus();
    _animationController.forward();

    try {
      final searchFilter = _filter.copyWith(query: query.isEmpty ? null : query);
      final results = await _searchService.searchProducts(searchFilter);

      if (query.isNotEmpty) {
        await _searchService.saveToHistory(query);
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _filter = searchFilter;
        });
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error, onRetry: _performSearch);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _performSearch();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        currentFilter: _filter,
        onApply: (filter) {
          setState(() => _filter = filter);
          _performSearch();
        },
      ),
    );
  }

  void _showSaveSearchDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('검색 저장'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: '검색 이름을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                try {
                  await _searchService.saveSearch(name, _filter);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('검색이 저장되었습니다')),
                    );
                    _loadSavedSearches();
                  }
                } catch (e) {
                  _logger.e('Failed to save search', e);
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            if (_searchSuggestions.isNotEmpty && _showSuggestions)
              _buildSuggestionsList(),
            if (_filter.hasFilters) _buildFilterTags(),
            Expanded(
              child: OfflineBanner(
                child: _isLoading
                    ? const LoadingWidget.center(message: '검색 중...')
                    : _showSuggestions
                        ? _buildSavedSearches()
                        : _buildSearchResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Hero(
                  tag: 'search_bar',
                  child: Material(
                    color: Colors.transparent,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: widget.initialQuery == null,
                      decoration: InputDecoration(
                        hintText: '상품명, 카테고리를 검색하세요',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults.clear();
                                    _showSuggestions = true;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (value) => _performSearch(),
                      onTap: () => setState(() => _showSuggestions = true),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              IconButton.filled(
                onPressed: _showFilterBottomSheet,
                icon: Badge(
                  label: Text('${_filter.activeFilterCount}'),
                  isLabelVisible: _filter.hasFilters,
                  child: const Icon(Icons.tune, size: 20),
                ),
                color: _filter.hasFilters ? Colors.white : null,
                style: IconButton.styleFrom(
                  backgroundColor: _filter.hasFilters
                      ? AppTheme.primaryColor
                      : AppTheme.backgroundColor,
                ),
              ),
              if (_filter.hasFilters)
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  tooltip: '검색 저장',
                  onPressed: _showSaveSearchDialog,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchSuggestions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final suggestion = _searchSuggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, size: 18, color: Colors.grey),
            title: Text(
              suggestion,
              style: const TextStyle(fontSize: 14),
            ),
            trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
            onTap: () => _onSuggestionTap(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildFilterTags() {
    final tags = <Widget>[];

    if (_filter.category != null) {
      tags.add(_buildFilterTag('${_filter.category}', () {
        setState(() => _filter = _filter.copyWith(category: null));
        _performSearch();
      }));
    }

    if (_filter.minPrice != null || _filter.maxPrice != null) {
      String priceText = '';
      if (_filter.minPrice != null && _filter.maxPrice != null) {
        priceText = '${_filter.minPrice!.toInt()}원 ~ ${_filter.maxPrice!.toInt()}원';
      } else if (_filter.minPrice != null) {
        priceText = '${_filter.minPrice!.toInt()}원 이상';
      } else {
        priceText = '${_filter.maxPrice!.toInt()}원 이하';
      }
      tags.add(_buildFilterTag(priceText, () {
        setState(() => _filter = _filter.clearFilters());
        _performSearch();
      }));
    }

    if (_filter.condition != null) {
      tags.add(_buildFilterTag(_filter.condition!.displayName, () {
        setState(() => _filter = _filter.copyWith(condition: null));
        _performSearch();
      }));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: tags,
            ),
          ),
          if (tags.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() => _filter = _filter.clearFilters());
                _performSearch();
              },
              icon: const Icon(Icons.close, size: 16),
              label: const Text('전체 해제', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTag(String text, VoidCallback onRemove) {
    return Material(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.close,
                size: 14,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedSearches() {
    if (_savedSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '저장된 검색이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '필터를 설정하고 검색을 저장해보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: _savedSearches.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingMd),
      itemBuilder: (context, index) {
        final saved = _savedSearches[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(AppTheme.spacingMd),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bookmark,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            title: Text(
              saved.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${saved.filter.query ?? "전체"} · ${saved.filter.activeFilterCount}개 필터',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    saved.notificationsEnabled
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    color: saved.notificationsEnabled
                        ? AppTheme.primaryColor
                        : Colors.grey,
                  ),
                  onPressed: () async {
                    try {
                      await _searchService.toggleNotifications(saved.id);
                      _loadSavedSearches();
                    } catch (e) {
                      _logger.e('Failed to toggle notifications', e);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () async {
                    try {
                      await _searchService.deleteSavedSearch(saved.id);
                      _loadSavedSearches();
                    } catch (e) {
                      _logger.e('Failed to delete saved search', e);
                    }
                  },
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _filter = saved.filter;
                _searchController.text = saved.filter.query ?? '';
              });
              _performSearch();
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                '검색 결과가 없습니다',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '다른 키워드나 필터로 검색해보세요',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  '검색 결과',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_searchResults.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: AppTheme.spacingMd,
                mainAxisSpacing: AppTheme.spacingMd,
              ),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final product = _searchResults[index];
                return ProductCard(
                  product: product,
                  onTap: () => context.push('/product/detail/${product.id}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final SearchFilterModel currentFilter;
  final Function(SearchFilterModel) onApply;

  const _FilterBottomSheet({
    required this.currentFilter,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late SearchFilterModel _filter;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  static const List<String> _categories = [
    '의류', '가전제품', '도서', '가구/인테리어',
    '스포츠/레저', '취미/게임', '기타'
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;

    if (_filter.minPrice != null) {
      _minPriceController.text = _filter.minPrice!.toInt().toString();
    }
    if (_filter.maxPrice != null) {
      _maxPriceController.text = _filter.maxPrice!.toInt().toString();
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('카테고리', _buildCategorySelector()),
                  _buildSection('가격 범위', _buildPriceSelector()),
                  _buildSection('상품 상태', _buildConditionSelector()),
                  _buildSection('정렬', _buildSortSelector()),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '필터',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _filter = SearchFilterModel();
                  _minPriceController.clear();
                  _maxPriceController.clear();
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('초기화'),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(_filter);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('${_filter.activeFilterCount}개 필터 적용'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        content,
        const SizedBox(height: AppTheme.spacingXl),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip('전체', _filter.category == null, () {
          setState(() => _filter = _filter.copyWith(category: null));
        }),
        ..._categories.map((cat) => _buildChip(
          cat,
          _filter.category == cat,
          () => setState(() => _filter = _filter.copyWith(category: cat)),
        )),
      ],
    );
  }

  Widget _buildPriceSelector() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _minPriceController,
            decoration: InputDecoration(
              hintText: '최소',
              suffixText: '원',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final price = int.tryParse(value);
              setState(() => _filter = _filter.copyWith(minPrice: price));
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('~', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: TextField(
            controller: _maxPriceController,
            decoration: InputDecoration(
              hintText: '최대',
              suffixText: '원',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final price = int.tryParse(value);
              setState(() => _filter = _filter.copyWith(maxPrice: price));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConditionSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip('전체', _filter.condition == null, () {
          setState(() => _filter = _filter.copyWith(condition: null));
        }),
        ...ProductCondition.values.map((cond) => _buildChip(
          cond.displayName,
          _filter.condition == cond,
          () => setState(() => _filter = _filter.copyWith(condition: cond)),
        )),
      ],
    );
  }

  Widget _buildSortSelector() {
    return Column(
      children: SortBy.values.map((sort) {
        final isSelected = _filter.sortBy == sort;
        return Material(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => setState(() => _filter = _filter.copyWith(sortBy: sort)),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sort.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return Material(
      color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
