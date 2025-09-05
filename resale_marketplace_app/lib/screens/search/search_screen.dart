import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/product_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card.dart';
import '../../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<ProductModel> _searchResults = [];
  List<String> _recentSearches = [];
  List<String> _popularSearches = [
    '아이폰',
    '나이키',
    '노트북',
    '가방',
    '시계',
    '운동화',
    '패딩',
    '에어팟',
  ];
  
  bool _isLoading = false;
  String _selectedCategory = '전체';
  String _sortBy = 'recent'; // recent, price_low, price_high, popular
  RangeValues _priceRange = const RangeValues(0, 1000000);
  
  // 필터 옵션
  final List<String> _categories = [
    '전체',
    '의류',
    '전자기기',
    '생활용품',
    '도서/문구',
    '스포츠/레저',
    '뷰티/미용',
    '기타',
  ];
  
  final Map<String, String> _sortOptions = {
    'recent': '최신순',
    'price_low': '가격 낮은순',
    'price_high': '가격 높은순',
    'popular': '인기순',
  };
  
  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchFocusNode.requestFocus();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    setState(() {
      _recentSearches = list;
    });
  }
  
  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(_recentSearches);
    list.remove(query);
    list.insert(0, query);
    final trimmed = list.length > 10 ? list.sublist(0, 10) : list;
    setState(() {
      _recentSearches = trimmed;
    });
    await prefs.setStringList('recent_searches', trimmed);
  }
  
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    _saveRecentSearch(query);
    
    try {
      // 검색 수행
      final results = await _productService.searchProducts(
        query: query,
        category: _selectedCategory == '전체' ? null : _selectedCategory,
        minPrice: _priceRange.start.toInt(),
        maxPrice: _priceRange.end.toInt(),
        sortBy: _sortBy,
      );
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 중 오류가 발생했습니다')),
        );
      }
    }
  }
  
  void _clearRecentSearches() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('recent_searches');
    });
    setState(() => _recentSearches.clear());
  }
  
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        selectedCategory: _selectedCategory,
        selectedSort: _sortBy,
        priceRange: _priceRange,
        categories: _categories,
        sortOptions: _sortOptions,
        onApply: (category, sort, price) {
          setState(() {
            _selectedCategory = category;
            _sortBy = sort;
            _priceRange = price;
          });
          
          // 현재 검색어로 다시 검색
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 8),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: '검색어를 입력하세요',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults.clear();
                        });
                      },
                    )
                  : null,
            ),
            onSubmitted: _performSearch,
            onChanged: (value) {
              setState(() {}); // suffixIcon 업데이트
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedCategory != '전체' || _sortBy != 'recent')
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isNotEmpty
              ? _buildSearchResults(theme)
              : _searchController.text.isEmpty
                  ? _buildSearchSuggestions(theme)
                  : _buildEmptyResults(theme),
    );
  }
  
  Widget _buildSearchResults(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          child: Row(
            children: [
              Text(
                '${_searchResults.length}개의 결과',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _sortOptions[_sortBy] ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final product = _searchResults[index];
              return ProductCard(
                product: product,
                onTap: () {
                  context.push('/product/detail/${product.id}');
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildSearchSuggestions(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 최근 검색어
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 검색어',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _clearRecentSearches,
                  child: Text(
                    '전체 삭제',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                return InkWell(
                  onTap: () {
                    _searchController.text = search;
                    _performSearch(search);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          search,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _recentSearches.remove(search);
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          // 인기 검색어
          Text(
            '인기 검색어',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches.asMap().entries.map((entry) {
              final index = entry.key;
              final search = entry.value;
              
              return InkWell(
                onTap: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: index < 3
                        ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                        : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: index < 3
                        ? Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index < 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (index < 3) const SizedBox(width: 6),
                      Text(
                        search,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: index < 3 ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyResults(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '검색 결과가 없습니다',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '다른 검색어를 입력해보세요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// 필터 바텀시트
class _FilterBottomSheet extends StatefulWidget {
  final String selectedCategory;
  final String selectedSort;
  final RangeValues priceRange;
  final List<String> categories;
  final Map<String, String> sortOptions;
  final Function(String, String, RangeValues) onApply;
  
  const _FilterBottomSheet({
    required this.selectedCategory,
    required this.selectedSort,
    required this.priceRange,
    required this.categories,
    required this.sortOptions,
    required this.onApply,
  });
  
  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _selectedCategory;
  late String _selectedSort;
  late RangeValues _priceRange;
  
  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedSort = widget.selectedSort;
    _priceRange = widget.priceRange;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = '전체';
                      _selectedSort = 'recent';
                      _priceRange = const RangeValues(0, 1000000);
                    });
                  },
                  child: const Text('초기화'),
                ),
                Text(
                  '필터',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
          const Divider(),
          // 필터 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리
                  Text(
                    '카테고리',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // 정렬
                  Text(
                    '정렬',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.sortOptions.entries.map((entry) {
                    return RadioListTile<String>(
                      title: Text(entry.value),
                      value: entry.key,
                      groupValue: _selectedSort,
                      onChanged: (value) {
                        setState(() {
                          _selectedSort = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                  
                  // 가격 범위
                  Text(
                    '가격 범위',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 1000000,
                    divisions: 100,
                    labels: RangeLabels(
                      _formatPrice(_priceRange.start),
                      _formatPrice(_priceRange.end),
                    ),
                    onChanged: (values) {
                      setState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatPrice(_priceRange.start),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        _formatPrice(_priceRange.end),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 적용 버튼
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_selectedCategory, _selectedSort, _priceRange);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '적용',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatPrice(double price) {
    if (price >= 10000) {
      return '${(price / 10000).toStringAsFixed(0)}만원';
    }
    return '${price.toStringAsFixed(0)}원';
  }
}
