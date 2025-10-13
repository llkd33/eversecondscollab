import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomSearchBar extends StatefulWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterPressed;
  final TextEditingController? controller;
  final bool showFilter;

  const CustomSearchBar({
    super.key,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onFilterPressed,
    this.controller,
    this.showFilter = true,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late TextEditingController _controller;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isSearching ? AppTheme.primaryColor : Colors.transparent,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                onTap: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
                onEditingComplete: () {
                  setState(() {
                    _isSearching = false;
                  });
                },
                decoration: InputDecoration(
                  hintText: widget.hintText ?? '상품명, 브랜드, 판매자명으로 검색',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: _isSearching ? AppTheme.primaryColor : Colors.grey[500],
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _controller.clear();
                            widget.onChanged?.call('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
          ),
          if (widget.showFilter) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.tune,
                  color: AppTheme.primaryColor,
                ),
                onPressed: widget.onFilterPressed ?? () {
                  _showFilterBottomSheet(context);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _selectedCategory = '전체';
  RangeValues _priceRange = const RangeValues(0, 1000000);
  String _selectedLocation = '전체';
  bool _resaleOnly = false;
  String _sortBy = '최신순';

  final List<String> _categories = [
    '전체', '의류', '전자기기', '생활용품', '도서', '스포츠', '뷰티', '기타'
  ];

  final List<String> _locations = [
    '전체', '서울', '경기', '인천', '부산', '대구', '광주', '대전', '울산', '세종'
  ];

  final List<String> _sortOptions = [
    '최신순', '가격 낮은순', '가격 높은순', '인기순', '거리순'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 헤더
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '필터',
                  style: AppStyles.headingSmall,
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = '전체';
                      _priceRange = const RangeValues(0, 1000000);
                      _selectedLocation = '전체';
                      _resaleOnly = false;
                      _sortBy = '최신순';
                    });
                  },
                  child: const Text('초기화'),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리
                  _buildSectionTitle('카테고리'),
                  _buildCategoryChips(),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // 가격 범위
                  _buildSectionTitle('가격 범위'),
                  _buildPriceRange(),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // 지역
                  _buildSectionTitle('지역'),
                  _buildLocationDropdown(),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // 대신팔기 전용
                  _buildResaleOnlySwitch(),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // 정렬
                  _buildSectionTitle('정렬'),
                  _buildSortOptions(),
                  
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
          
          // 적용 버튼
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: 필터 적용 로직
                },
                child: const Text('적용하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppStyles.headingSmall.copyWith(fontSize: 14),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _categories.map((category) {
        final isSelected = _selectedCategory == category;
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedCategory = category;
            });
          },
          backgroundColor: Colors.grey[200],
          selectedColor: AppTheme.primaryColor,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceRange() {
    return Column(
      children: [
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 1000000,
          divisions: 20,
          labels: RangeLabels(
            '₩${(_priceRange.start / 1000).round()}K',
            '₩${(_priceRange.end / 1000).round()}K',
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
            Text('₩${(_priceRange.start / 1000).round()}K'),
            Text('₩${(_priceRange.end / 1000).round()}K'),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedLocation,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      items: _locations.map((location) {
        return DropdownMenuItem(
          value: location,
          child: Text(location),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLocation = value!;
        });
      },
    );
  }

  Widget _buildResaleOnlySwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '대신팔기 가능 상품만',
              style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '대신팔기가 가능한 상품만 보기',
              style: AppStyles.bodySmall,
            ),
          ],
        ),
        Switch(
          value: _resaleOnly,
          onChanged: (value) {
            setState(() {
              _resaleOnly = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Column(
      children: _sortOptions.map((option) {
        return RadioListTile<String>(
          title: Text(option),
          value: option,
          groupValue: _sortBy,
          onChanged: (value) {
            setState(() {
              _sortBy = value!;
            });
          },
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }
}