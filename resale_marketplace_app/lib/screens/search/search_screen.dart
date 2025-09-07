import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_input.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/product_card.dart';
import '../../services/search_service.dart';
import '../../models/product_model.dart';
import '../../utils/error_handler.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with ErrorHandlerMixin {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  
  List<Product> _searchResults = [];
  List<String> _popularSearchTerms = [];
  List<String> _recentSearchTerms = [];
  List<String> _categories = [];
  
  SearchFilter _currentFilter = const SearchFilter();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _searchService.getPopularSearchTerms(),
        _searchService.getRecentSearchTerms(),
        _searchService.getCategories(),
      ]);
      
      setState(() {
        _popularSearchTerms = results[0] as List<String>;
        _recentSearchTerms = results[1] as List<String>;
        _categories = results[2] as List<String>;
      });
    } catch (error) {
      showErrorSnackBar(context, error);
    }
  }

  Future<void> _performSearch({bool isNewSearch = true}) async {
    if (isNewSearch) {
      setState(() {
        _isLoading = true;
        _searchResults.clear();
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final query = _searchController.text.trim();
      
      // 검색어 저장
      if (query.isNotEmpty && isNewSearch) {
        await _searchService.saveSearchTerm(query);
      }
      
      final filter = isNewSearch 
          ? _currentFilter.copyWith(page: 1)
          : _currentFilter.copyWith(page: _currentFilter.page + 1);
      
      final result = await _searchService.searchProducts(
        query: query.isEmpty ? null : query,
        filter: filter,
      );
      
      setState(() {
        if (isNewSearch) {
          _searchResults = result.products;
        } else {
          _searchResults.addAll(result.products);
        }
        _currentFilter = result.filter;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      showErrorSnackBar(context, error, onRetry: () => _performSearch(isNewSearch: isNewSearch));
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchTermTap(String term) {
    _searchController.text = term;
    _performSearch();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        currentFilter: _currentFilter,
        categories: _categories,
        onApply: (filter) {
          setState(() {
            _currentFilter = filter;
          });
          _performSearch();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('검색'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 검색 바
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    hint: '상품명, 카테고리를 검색하세요',
                    onChanged: (value) {
                      // 실시간 검색은 성능상 제외
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                AppIconButton(
                  onPressed: () => _performSearch(),
                  icon: Icons.search,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                AppIconButton(
                  onPressed: _showFilterBottomSheet,
                  icon: Icons.tune,
                  color: _hasActiveFilters() ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          
          // 필터 태그
          if (_hasActiveFilters()) _buildFilterTags(),
          
          // 검색 결과 또는 추천 검색어
          Expanded(
            child: _searchResults.isEmpty && !_isLoading
                ? _buildSearchSuggestions()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTags() {
    final tags = <Widget>[];
    
    if (_currentFilter.category != null) {
      tags.add(_buildFilterTag(_currentFilter.category!, () {
        setState(() {
          _currentFilter = _currentFilter.copyWith(category: null);
        });
        _performSearch();
      }));
    }
    
    if (_currentFilter.minPrice != null || _currentFilter.maxPrice != null) {
      String priceText = '';
      if (_currentFilter.minPrice != null && _currentFilter.maxPrice != null) {
        priceText = '${_currentFilter.minPrice!.toInt()}원 - ${_currentFilter.maxPrice!.toInt()}원';
      } else if (_currentFilter.minPrice != null) {
        priceText = '${_currentFilter.minPrice!.toInt()}원 이상';
      } else {
        priceText = '${_currentFilter.maxPrice!.toInt()}원 이하';
      }
      
      tags.add(_buildFilterTag(priceText, () {
        setState(() {
          _currentFilter = _currentFilter.copyWith(
            minPrice: null,
            maxPrice: null,
          );
        });
        _performSearch();
      }));
    }
    
    if (_currentFilter.location != null) {
      tags.add(_buildFilterTag(_currentFilter.location!, () {
        setState(() {
          _currentFilter = _currentFilter.copyWith(location: null);
        });
        _performSearch();
      }));
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AppTheme.spacingSm,
              children: tags,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentFilter = const SearchFilter();
              });
              _performSearch();
            },
            child: const Text('전체 해제'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTag(String text, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.primaryColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingXs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearchTerms.isNotEmpty) ...[
            _buildSectionHeader('최근 검색어', onClear: () async {
              await _searchService.clearSearchHistory();
              setState(() {
                _recentSearchTerms.clear();
              });
            }),
            const SizedBox(height: AppTheme.spacingSm),
            _buildSearchTermChips(_recentSearchTerms),
            const SizedBox(height: AppTheme.spacingLg),
          ],
          
          _buildSectionHeader('인기 검색어'),
          const SizedBox(height: AppTheme.spacingSm),
          _buildSearchTermChips(_popularSearchTerms),
          const SizedBox(height: AppTheme.spacingLg),
          
          _buildSectionHeader('카테고리'),
          const SizedBox(height: AppTheme.spacingSm),
          _buildCategoryGrid(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onClear}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (onClear != null)
          TextButton(
            onPressed: onClear,
            child: const Text('전체 삭제'),
          ),
      ],
    );
  }

  Widget _buildSearchTermChips(List<String> terms) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: terms.map((term) => GestureDetector(
        onTap: () => _onSearchTermTap(term),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Text(
            term,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: AppTheme.spacingSm,
        mainAxisSpacing: AppTheme.spacingSm,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentFilter = _currentFilter.copyWith(category: category);
            });
            _performSearch();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoadingMore && 
            _hasMore && 
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _performSearch(isNewSearch: false);
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        itemCount: _searchResults.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _searchResults.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingMd),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: ProductCard(product: _searchResults[index]),
          );
        },
      ),
    );
  }

  bool _hasActiveFilters() {
    return _currentFilter.category != null ||
           _currentFilter.minPrice != null ||
           _currentFilter.maxPrice != null ||
           _currentFilter.location != null ||
           _currentFilter.isResaleEnabled != null ||
           (_currentFilter.conditions != null && _currentFilter.conditions!.isNotEmpty);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final SearchFilter currentFilter;
  final List<String> categories;
  final Function(SearchFilter) onApply;

  const _FilterBottomSheet({
    Key? key,
    required this.currentFilter,
    required this.categories,
    required this.onApply,
  }) : super(key: key);

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late SearchFilter _filter;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

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
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filter = const SearchFilter();
                      _minPriceController.clear();
                      _maxPriceController.clear();
                    });
                  },
                  child: const Text('초기화'),
                ),
                const Text(
                  '필터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(_filter);
                  },
                  child: const Text('적용'),
                ),
              ],
            ),
          ),
          
          // 필터 옵션들
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리
                  _buildFilterSection(
                    '카테고리',
                    _buildCategorySelector(),
                  ),
                  
                  // 가격 범위
                  _buildFilterSection(
                    '가격 범위',
                    _buildPriceRangeSelector(),
                  ),
                  
                  // 대신팔기 가능
                  _buildFilterSection(
                    '대신팔기',
                    _buildResaleSelector(),
                  ),
                  
                  // 정렬
                  _buildFilterSection(
                    '정렬',
                    _buildSortSelector(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        content,
        const SizedBox(height: AppTheme.spacingLg),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: [
        _buildChoiceChip('전체', _filter.category == null, () {
          setState(() {
            _filter = _filter.copyWith(category: null);
          });
        }),
        ...widget.categories.map((category) => _buildChoiceChip(
          category,
          _filter.category == category,
          () {
            setState(() {
              _filter = _filter.copyWith(category: category);
            });
          },
        )),
      ],
    );
  }

  Widget _buildPriceRangeSelector() {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: _minPriceController,
            hint: '최소 가격',
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final price = double.tryParse(value);
              setState(() {
                _filter = _filter.copyWith(minPrice: price);
              });
            },
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        const Text('~'),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: AppTextField(
            controller: _maxPriceController,
            hint: '최대 가격',
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final price = double.tryParse(value);
              setState(() {
                _filter = _filter.copyWith(maxPrice: price);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResaleSelector() {
    return Row(
      children: [
        _buildChoiceChip('전체', _filter.isResaleEnabled == null, () {
          setState(() {
            _filter = _filter.copyWith(isResaleEnabled: null);
          });
        }),
        const SizedBox(width: AppTheme.spacingSm),
        _buildChoiceChip('대신팔기 가능', _filter.isResaleEnabled == true, () {
          setState(() {
            _filter = _filter.copyWith(isResaleEnabled: true);
          });
        }),
      ],
    );
  }

  Widget _buildSortSelector() {
    return Column(
      children: [
        _buildRadioTile('최신순', SortOption.latest),
        _buildRadioTile('낮은 가격순', SortOption.priceAsc),
        _buildRadioTile('높은 가격순', SortOption.priceDesc),
        _buildRadioTile('인기순', SortOption.popular),
      ],
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRadioTile(String title, SortOption value) {
    return RadioListTile<SortOption>(
      title: Text(title),
      value: value,
      groupValue: _filter.sortBy,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _filter = _filter.copyWith(sortBy: value);
          });
        }
      },
      activeColor: AppTheme.primaryColor,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }
}