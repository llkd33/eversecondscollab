import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final _commissionRateController = TextEditingController();
  
  String _selectedCategory = '전자기기';
  bool _resaleEnabled = false;
  bool _isCommissionRate = true; // true: 퍼센트, false: 고정금액
  List<XFile> _selectedImages = [];

  final List<String> _categories = [
    '전자기기',
    '의류',
    '생활용품',
    '도서',
    '스포츠/레저',
    '기타',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _commissionRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 등록'),
        actions: [
          TextButton(
            onPressed: _submitProduct,
            child: const Text('등록'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이미지 선택
              _ImageSection(),
              
              const SizedBox(height: 24),
              
              // 상품 정보
              _ProductInfoSection(),
              
              const SizedBox(height: 24),
              
              // 대신팔기 설정
              _ResaleSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '상품 사진',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '최대 10장까지 등록 가능합니다.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // 이미지 추가 버튼
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt, color: Colors.grey),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedImages.length}/10',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 선택된 이미지들
              ..._selectedImages.map((image) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.remove(image);
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
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
    );
  }

  Widget _ProductInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상품명
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '상품명',
            hintText: '상품명을 입력해주세요',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '상품명을 입력해주세요';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // 카테고리
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(
            labelText: '카테고리',
            border: OutlineInputBorder(),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value!;
            });
          },
        ),
        
        const SizedBox(height: 16),
        
        // 가격
        TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: '가격',
            hintText: '가격을 입력해주세요',
            border: OutlineInputBorder(),
            prefixText: '₩ ',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '가격을 입력해주세요';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // 상품 설명
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '상품 설명',
            hintText: '상품에 대한 자세한 설명을 입력해주세요',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '상품 설명을 입력해주세요';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _ResaleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '대신팔기 허용',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Switch(
              value: _resaleEnabled,
              onChanged: (value) {
                setState(() {
                  _resaleEnabled = value;
                });
              },
            ),
          ],
        ),
        
        if (_resaleEnabled) ...[
          const SizedBox(height: 16),
          
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
                child: RadioListTile<bool>(
                  title: const Text('퍼센트 (%)'),
                  value: true,
                  groupValue: _isCommissionRate,
                  onChanged: (value) {
                    setState(() {
                      _isCommissionRate = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('고정금액'),
                  value: false,
                  groupValue: _isCommissionRate,
                  onChanged: (value) {
                    setState(() {
                      _isCommissionRate = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          TextFormField(
            controller: _commissionRateController,
            decoration: InputDecoration(
              labelText: _isCommissionRate ? '수수료율 (%)' : '수수료 금액',
              hintText: _isCommissionRate ? '예: 10' : '예: 5000',
              border: const OutlineInputBorder(),
              suffixText: _isCommissionRate ? '%' : '원',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (_resaleEnabled && (value == null || value.isEmpty)) {
                return '수수료를 입력해주세요';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '대신팔기를 허용하면 다른 사용자들이 이 상품을 자신의 샵에 등록하여 판매할 수 있습니다. 판매가 성사되면 설정한 수수료를 받게 됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    setState(() {
      _selectedImages.addAll(images);
      if (_selectedImages.length > 10) {
        _selectedImages = _selectedImages.take(10).toList();
      }
    });
  }

  void _submitProduct() {
    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('상품 사진을 최소 1장 이상 등록해주세요'),
          ),
        );
        return;
      }
      
      // TODO: 상품 등록 API 호출
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상품이 등록되었습니다'),
        ),
      );
      
      Navigator.pop(context);
    }
  }
}