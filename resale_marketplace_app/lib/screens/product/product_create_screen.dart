import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';
import '../../utils/responsive.dart';

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
  final List<File> _imageFiles = [];
  final List<String> _uploadedImageUrls = [];
  bool _isLoading = false;
  
  final List<String> _categories = [
    '의류',
    '전자기기',
    '생활용품',
    '스포츠/레저',
    '도서/문구',
    '뷰티/미용',
    '식품',
    '반려동물',
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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이미지 선택 섹션
                  _buildImageSection(),
                  const Divider(height: 1),
                  
                  // 기본 정보 입력
                  Responsive.responsiveContainer(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleField(),
                        SizedBox(height: context.isMobile ? 20 : 24),
                        _buildCategorySelector(),
                        SizedBox(height: context.isMobile ? 20 : 24),
                        _buildPriceField(),
                        SizedBox(height: context.isMobile ? 20 : 24),
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
          
          // 로딩 오버레이
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text(
                        '상품을 등록하고 있습니다...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '이미지 업로드 및 상품 정보를 저장 중입니다.\n잠시만 기다려주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
            padding: context.responsivePadding,
            child: Row(
              children: [
                Text(
                  '상품 이미지',
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 14),
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
                      fontSize: Responsive.responsiveFontSize(context, 11),
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: context.isMobile ? 104 : 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(
                left: context.isMobile ? 16 : 32,
                right: context.isMobile ? 16 : 32,
                bottom: 16,
              ),
              children: [
                // 이미지 추가 버튼
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: context.isMobile ? 88 : 110,
                    height: context.isMobile ? 88 : 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, 
                          size: context.isMobile ? 28 : 32, 
                          color: Colors.grey[600]
                        ),
                        SizedBox(height: context.isMobile ? 4 : 6),
                        Text(
                          '${_imageFiles.length}/10',
                          style: TextStyle(
                            fontSize: Responsive.responsiveFontSize(context, 13),
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
            final imageSize = context.isMobile ? 88.0 : 110.0;
            
            return Padding(
              padding: EdgeInsets.only(left: context.isMobile ? 12 : 16),
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _moveImageToFirst(index),
                    child: Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(file),
                          fit: BoxFit.cover,
                        ),
                        border: index == 0 
                            ? Border.all(color: AppTheme.primaryColor, width: 2)
                            : null,
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
                          color: Colors.black.withValues(alpha: 0.6),
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
          }),
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
      style: TextStyle(
        fontSize: Responsive.responsiveFontSize(context, 16),
      ),
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
        padding: EdgeInsets.symmetric(
          vertical: context.isMobile ? 12 : 16,
        ),
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
                fontSize: Responsive.responsiveFontSize(context, 16),
                color: Colors.grey[700],
              ),
            ),
            Row(
              children: [
                Text(
                  _selectedCategory,
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 16),
                  ),
                ),
                SizedBox(width: context.isMobile ? 8 : 12),
                Icon(Icons.arrow_forward_ios, 
                  size: context.isMobile ? 16 : 18, 
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
        hintText: '가격 (예: 50,000)',
        suffixText: '원',
        border: InputBorder.none,
        suffixStyle: TextStyle(
          fontSize: Responsive.responsiveFontSize(context, 16),
          color: Colors.grey[700],
        ),
        helperText: '최소 100원 이상, 최대 1억원 이하',
        helperStyle: TextStyle(
          fontSize: Responsive.responsiveFontSize(context, 12),
          color: Colors.grey[600],
        ),
      ),
      style: TextStyle(
        fontSize: Responsive.responsiveFontSize(context, 16),
      ),
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
        if (price == null) {
          return '올바른 숫자를 입력해주세요';
        }
        if (price < 100) {
          return '최소 100원 이상 입력해주세요';
        }
        if (price > 100000000) {
          return '최대 1억원 이하로 입력해주세요';
        }
        return null;
      },
    );
  }
  
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _descriptionController,
          maxLines: context.isMobile ? 5 : 6,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: '상품 설명을 입력해주세요.\n\n브랜드, 모델명, 구매시기, 사용감 등을 작성하면 판매가 더 쉬워요.',
            border: InputBorder.none,
            counterStyle: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 12),
            ),
          ),
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 16),
            height: 1.4,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '상품 설명을 입력해주세요';
            }
            if (value.trim().length > 500) {
              return '상품 설명은 500자 이하로 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, 
                    size: 16, 
                    color: Colors.orange[600]
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '상품 설명 작성 팁',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• 브랜드, 모델명을 정확히 기재해주세요\n• 구매 시기와 사용 기간을 알려주세요\n• 사용감이나 하자 여부를 솔직히 작성해주세요\n• 교환/환불 정책을 명시해주세요',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
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
                            overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
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
    if (!_resaleEnabled) {
      setState(() {
        _resaleFeeController.text = '';
      });
      return;
    }
    
    if (_priceController.text.isEmpty) {
      setState(() {
        _resaleFeeController.text = '';
      });
      return;
    }
    
    final price = int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
    if (price <= 0) {
      setState(() {
        _resaleFeeController.text = '';
      });
      return;
    }
    
    // 수수료 계산
    final fee = (price * _resaleFeePercentage / 100).round();
    
    // 최소 수수료 보장 (100원)
    final finalFee = fee < 100 ? 100 : fee;
    
    // 수수료가 상품 가격을 초과하지 않도록 제한
    final maxFee = (price * 0.5).round(); // 최대 50%
    final limitedFee = finalFee > maxFee ? maxFee : finalFee;
    
    setState(() {
      _resaleFeeController.text = _formatNumber(limitedFee);
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
      builder: (context) => SizedBox(
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
      _showErrorMessage('최대 10장까지 선택 가능합니다');
      return;
    }
    
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      
      if (images.isEmpty) return;
      
      // 이미지 검증 및 필터링
      const maxFileSize = 10 * 1024 * 1024; // 10MB
      final validImages = <XFile>[];
      final invalidImages = <String>[];
      
      for (final image in images) {
        final file = File(image.path);
        
        // 파일 존재 여부 확인
        if (!await file.exists()) {
          invalidImages.add('${image.name}: 파일을 찾을 수 없습니다');
          continue;
        }
        
        // 파일 크기 검증
        final fileSize = await file.length();
        if (fileSize > maxFileSize) {
          invalidImages.add('${image.name}: 파일 크기가 너무 큽니다 (최대 10MB)');
          continue;
        }
        
        // 파일 형식 검증
        final extension = image.path.split('.').last.toLowerCase();
        final validExtensions = ['jpg', 'jpeg', 'png', 'webp'];
        if (!validExtensions.contains(extension)) {
          invalidImages.add('${image.name}: 지원하지 않는 형식입니다 (jpg, png, webp만 가능)');
          continue;
        }
        
        validImages.add(image);
      }
      
      // 유효하지 않은 이미지에 대한 알림
      if (invalidImages.isNotEmpty && mounted) {
        final message = invalidImages.length == 1 
            ? invalidImages.first
            : '${invalidImages.length}개 이미지에 문제가 있습니다:\n${invalidImages.take(3).join('\n')}${invalidImages.length > 3 ? '\n...' : ''}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      // 유효한 이미지 추가
      if (validImages.isNotEmpty) {
        setState(() {
          final remainingSlots = 10 - _imageFiles.length;
          final imagesToAdd = validImages.take(remainingSlots);
          _imageFiles.addAll(imagesToAdd.map((x) => File(x.path)));
        });
        
        // 추가된 이미지 수 알림
        final addedCount = validImages.take(10 - (_imageFiles.length - validImages.length)).length;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${addedCount}장의 이미지가 추가되었습니다'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // 최대 개수 초과 시 알림
          if (validImages.length > (10 - (_imageFiles.length - addedCount))) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('최대 10장까지만 선택할 수 있어 일부 이미지가 제외되었습니다'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Image picker error: $e');
      if (mounted) {
        String errorMessage = '이미지 선택 중 오류가 발생했습니다';
        
        if (e.toString().contains('permission')) {
          errorMessage = '갤러리 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.';
        } else if (e.toString().contains('camera')) {
          errorMessage = '카메라 접근에 문제가 있습니다. 다시 시도해주세요.';
        }
        
        _showErrorMessage(errorMessage);
      }
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
  
  void _moveImageToFirst(int index) {
    if (index == 0) return;
    
    setState(() {
      final image = _imageFiles.removeAt(index);
      _imageFiles.insert(0, image);
      
      if (_uploadedImageUrls.length > index) {
        final url = _uploadedImageUrls.removeAt(index);
        _uploadedImageUrls.insert(0, url);
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('대표 이미지로 설정되었습니다'),
        duration: Duration(seconds: 1),
      ),
    );
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
    
    // 추가 검증
    if (_titleController.text.trim().isEmpty) {
      _showErrorMessage('상품명을 입력해주세요');
      return;
    }
    
    if (_priceController.text.isEmpty) {
      _showErrorMessage('가격을 입력해주세요');
      return;
    }
    
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorMessage('상품 설명을 입력해주세요');
      return;
    }
    
    // 이미지 선택은 선택 사항(없어도 등록 가능)
    
    // 대신팔기 설정 검증
    if (_resaleEnabled) {
      if (_resaleFeePercentage < 5 || _resaleFeePercentage > 30) {
        _showErrorMessage('대신팔기 수수료는 5%~30% 사이로 설정해주세요');
        return;
      }
      
      final price = int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
      final calculatedFee = (price * _resaleFeePercentage / 100).round();
      
      if (calculatedFee < 100) {
        _showErrorMessage('대신팔기 수수료는 최소 100원 이상이어야 합니다');
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 현재 사용자 가져오기
      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
      }
      
      // 이미지 업로드
      List<String> uploadedUrls = [];
      if (_imageFiles.isNotEmpty) {
        try {
          uploadedUrls = await _productService.uploadProductImages(
            _imageFiles,
            currentUser.id,
          );
          
          if (uploadedUrls.isEmpty) {
            throw Exception('이미지 업로드에 실패했습니다. 네트워크 연결을 확인해주세요.');
          }
          
          if (uploadedUrls.length != _imageFiles.length) {
            throw Exception('일부 이미지 업로드에 실패했습니다. 다시 시도해주세요.');
          }
        } catch (e) {
          throw Exception('이미지 업로드 실패: ${e.toString().replaceAll('Exception: ', '')}');
        }
      }
      
      // 상품 생성
      final price = int.parse(_priceController.text.replaceAll(',', ''));
      final resaleFee = _resaleEnabled
          ? (price * _resaleFeePercentage / 100).round()
          : 0;
      
      final product = await _productService.createProduct(
        title: _titleController.text.trim(),
        price: price,
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        sellerId: currentUser.id,
        images: uploadedUrls,
        resaleEnabled: _resaleEnabled,
        resaleFee: resaleFee,
        resaleFeePercentage: _resaleEnabled ? _resaleFeePercentage : 0,
      );
      
      if (product != null && mounted) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '상품이 성공적으로 등록되었습니다!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_resaleEnabled)
                        Text(
                          '대신팔기 수수료: ${_resaleFeePercentage.toInt()}% (${_formatNumber(resaleFee)}원)',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // 상품 등록 완료 후 이전 화면으로 돌아가면서 결과 전달
        context.pop(product);
      } else {
        throw Exception('상품 등록에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      // 에러 로깅
      print('Product creation error: $e');
      
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        
        // 특정 에러에 대한 사용자 친화적 메시지
        if (errorMessage.contains('network') || errorMessage.contains('connection')) {
          errorMessage = '네트워크 연결을 확인하고 다시 시도해주세요.';
        } else if (errorMessage.contains('permission') || errorMessage.contains('unauthorized')) {
          errorMessage = '권한이 없습니다. 다시 로그인해주세요.';
        } else if (errorMessage.contains('storage') || errorMessage.contains('upload')) {
          errorMessage = '이미지 업로드에 실패했습니다. 이미지 크기를 확인하고 다시 시도해주세요.';
        }
        
        _showErrorMessage(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
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
