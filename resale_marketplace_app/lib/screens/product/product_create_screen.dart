import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/user_service.dart';

class ProductCreateScreen extends StatefulWidget {
  const ProductCreateScreen({super.key});

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _resaleFeeController = TextEditingController();
  
  final ProductService _productService = ProductService();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();
  
  String _selectedCategory = '의류';
  bool _resaleEnabled = false;
  double _resaleFeePercentage = 10.0;
  List<File> _imageFiles = [];
  List<String> _uploadedImageUrls = [];
  bool _isLoading = false;
  
  final List<String> _categories = [
    '의류',
    '전자기기',
    '생활용품',
    '가구/인테리어',
    '도서/문구',
    '스포츠/레저',
    '뷰티/미용',
    '식품',
    '반려동물용품',
    '기타'
  ];
  
  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _resaleFeeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CommonAppBar(
        title: '상품 등록',
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_hasUnsavedChanges()) {
              _showExitConfirmDialog();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitProduct,
            child: Text(
              '완료',
              style: TextStyle(
                color: _isLoading ? Colors.grey : AppTheme.primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지 선택 섹션
                    _buildImageSection(),
                    const Divider(height: 1),
                    
                    // 기본 정보 입력
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleField(),
                          const SizedBox(height: 20),
                          _buildCategorySelector(),
                          const SizedBox(height: 20),
                          _buildPriceField(),
                          const SizedBox(height: 20),
                          _buildDescriptionField(),
                        ],
                      ),
                    ),
                    
                    const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                    
                    // 대신팔기 설정
                    _buildResaleSection(),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildImageSection() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                const Text(
                  '상품 이미지',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '선택',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              children: [
                // 이미지 추가 버튼
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, 
                          size: 28, 
                          color: Colors.grey[600]
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_imageFiles.length}/10',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          
          // 선택된 이미지들
          ..._imageFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(file),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // 대표 이미지 표시
                  if (index == 0)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '대표',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // 삭제 버튼
                  Positioned(
                    right: 4,
                    top: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      maxLength: 40,
      decoration: const InputDecoration(
        hintText: '상품명',
        border: InputBorder.none,
        counterText: '',
      ),
      style: const TextStyle(fontSize: 16),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '상품명을 입력해주세요';
        }
        if (value.length < 2) {
          return '상품명은 2자 이상 입력해주세요';
        }
        return null;
      },
    );
  }
  
  Widget _buildCategorySelector() {
    return InkWell(
      onTap: _showCategoryPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '카테고리',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            Row(
              children: [
                Text(
                  _selectedCategory,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, 
                  size: 16, 
                  color: Colors.grey[400]
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _ThousandsSeparatorInputFormatter(),
      ],
      decoration: InputDecoration(
        hintText: '가격',
        suffixText: '원',
        border: InputBorder.none,
        suffixStyle: TextStyle(
          fontSize: 16,
          color: Colors.grey[700],
        ),
      ),
      style: const TextStyle(fontSize: 16),
      onChanged: (value) {
        if (_resaleEnabled) {
          _updateResaleFee();
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '가격을 입력해주세요';
        }
        final price = int.tryParse(value.replaceAll(',', ''));
        if (price == null || price < 100) {
          return '100원 이상 입력해주세요';
        }
        return null;
      },
    );
  }
  
  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 5,
      maxLength: 500,
      decoration: const InputDecoration(
        hintText: '상품 설명을 입력해주세요.\n\n브랜드, 모델명, 구매시기, 사용감 등을 작성하면 판매가 더 쉬워요.',
        border: InputBorder.none,
      ),
      style: const TextStyle(fontSize: 16, height: 1.4),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '상품 설명을 입력해주세요';
        }
        if (value.length < 10) {
          return '상품 설명은 10자 이상 입력해주세요';
        }
        return null;
      },
    );
  }
  
  Widget _buildResaleSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, 
                        size: 20, 
                        color: AppTheme.primaryColor
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '대신팔기 허용',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '다른 사용자가 내 상품을 대신 판매할 수 있어요',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Switch(
                value: _resaleEnabled,
                onChanged: (value) {
                  setState(() {
                    _resaleEnabled = value;
                    if (value && _priceController.text.isNotEmpty) {
                      _updateResaleFee();
                    }
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          
          if (_resaleEnabled) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '수수료 설정',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primaryColor,
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: AppTheme.primaryColor,
                            overlayColor: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _resaleFeePercentage,
                            min: 5,
                            max: 30,
                            divisions: 25,
                            label: '${_resaleFeePercentage.toInt()}%',
                            onChanged: (value) {
                              setState(() {
                                _resaleFeePercentage = value;
                                _updateResaleFee();
                              });
                            },
                          ),
                        ),
                      ),
                      Container(
                        width: 50,
                        alignment: Alignment.center,
                        child: Text(
                          '${_resaleFeePercentage.toInt()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '예상 수수료',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          _resaleFeeController.text.isEmpty
                              ? '가격을 입력해주세요'
                              : '${_resaleFeeController.text}원',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _resaleFeeController.text.isEmpty
                                ? Colors.grey
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 수수료가 높을수록 대신팔기 확률이 올라가요!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _updateResaleFee() {
    if (_priceController.text.isEmpty) return;
    
    final price = int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
    final fee = (price * _resaleFeePercentage / 100).round();
    
    setState(() {
      _resaleFeeController.text = _formatNumber(fee);
    });
  }
  
  String _formatNumber(int number) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return number.toString().replaceAllMapped(
      formatter,
      (match) => '${match[1]},',
    );
  }
  
  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '카테고리 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return ListTile(
                    title: Text(category),
                    trailing: _selectedCategory == category
                        ? Icon(Icons.check, color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImages() async {
    if (_imageFiles.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최대 10장까지 선택 가능합니다')),
      );
      return;
    }
    
    final List<XFile> images = await _picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        final remainingSlots = 10 - _imageFiles.length;
        final imagesToAdd = images.take(remainingSlots);
        _imageFiles.addAll(imagesToAdd.map((x) => File(x.path)));
      });
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
      if (_uploadedImageUrls.length > index) {
        _uploadedImageUrls.removeAt(index);
      }
    });
  }
  
  bool _hasUnsavedChanges() {
    return _titleController.text.isNotEmpty ||
        _priceController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _imageFiles.isNotEmpty;
  }
  
  void _showExitConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작성 중인 내용이 있습니다'),
        content: const Text('정말 나가시겠습니까?\n작성 중인 내용은 저장되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text(
              '나가기',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // 이미지는 선택사항이므로 체크 제거
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 현재 사용자 가져오기
      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      // 이미지 업로드 (이미지가 있는 경우에만)
      if (_imageFiles.isNotEmpty) {
        _uploadedImageUrls = await _productService.uploadProductImages(
          _imageFiles,
          currentUser.id,
        );
      }
      
      // 상품 생성
      final price = int.parse(_priceController.text.replaceAll(',', ''));
      final resaleFee = _resaleEnabled
          ? int.parse(_resaleFeeController.text.replaceAll(',', ''))
          : 0;
      
      final product = await _productService.createProduct(
        title: _titleController.text.trim(),
        price: price,
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        sellerId: currentUser.id,
        images: _uploadedImageUrls,
        resaleEnabled: _resaleEnabled,
        resaleFee: resaleFee,
        resaleFeePercentage: _resaleEnabled ? _resaleFeePercentage : 0,
      );
      
      if (product != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('상품이 등록되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        context.pop(product);
      } else {
        throw Exception('상품 등록에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상품 등록 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// 천 단위 구분자 입력 포맷터
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    final number = int.tryParse(newValue.text.replaceAll(',', ''));
    if (number == null) {
      return oldValue;
    }
    
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = number.toString().replaceAllMapped(
      formatter,
      (match) => '${match[1]},',
    );
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}