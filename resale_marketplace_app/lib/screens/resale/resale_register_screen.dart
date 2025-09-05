import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/product_service.dart';
import '../../services/auth_service.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class ResaleRegisterScreen extends StatefulWidget {
  final ProductModel? originalProduct; // 기존 상품 (있는 경우)
  
  const ResaleRegisterScreen({
    super.key,
    this.originalProduct,
  });

  @override
  State<ResaleRegisterScreen> createState() => _ResaleRegisterScreenState();
}

class _ResaleRegisterScreenState extends State<ResaleRegisterScreen> {
  final ProductService _productService = ProductService();
  final AuthService _authService = AuthService();
  
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  
  // 대신판매 옵션
  bool _includeDelivery = true; // 배송 포함 여부
  bool _allowNegotiation = true; // 가격 협상 가능 여부
  String _condition = '새상품'; // 상품 상태
  
  // 수수료 타입
  String _commissionType = 'percentage'; // percentage or fixed
  double _commissionRate = 10.0; // 퍼센트
  int _commissionFixed = 0; // 고정 금액
  
  @override
  void initState() {
    super.initState();
    _loadUser();
    
    // 기존 상품이 있으면 정보 채우기
    if (widget.originalProduct != null) {
      _titleController.text = widget.originalProduct!.title;
      _descriptionController.text = widget.originalProduct!.description;
      _priceController.text = widget.originalProduct!.price.toString();
      _condition = widget.originalProduct!.condition;
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
  }
  
  Future<void> _registerResale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null) {
      _showError('로그인이 필요합니다');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // 대신판매 상품 등록
      final resaleProduct = await _productService.createProduct(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: int.parse(_priceController.text),
        condition: _condition,
        images: widget.originalProduct?.images ?? [],
        categoryId: widget.originalProduct?.categoryId ?? 'general',
        sellerId: _currentUser!.id,
        isResale: true,
        originalProductId: widget.originalProduct?.id,
        resaleInfo: {
          'commission_type': _commissionType,
          'commission_rate': _commissionRate,
          'commission_fixed': _commissionFixed,
          'include_delivery': _includeDelivery,
          'allow_negotiation': _allowNegotiation,
          'original_seller_id': widget.originalProduct?.sellerId,
        },
      );
      
      if (resaleProduct != null && mounted) {
        _showSuccess('대신팔기 상품이 등록되었습니다');
        Navigator.pop(context, true);
      } else {
        _showError('등록에 실패했습니다');
      }
    } catch (e) {
      _showError('오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('대신팔기 등록'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대신팔기 안내
              _buildInfoSection(theme),
              const SizedBox(height: 24),
              
              // 상품 정보
              _buildProductInfoSection(theme),
              const SizedBox(height: 24),
              
              // 가격 및 수수료 설정
              _buildPriceSection(theme),
              const SizedBox(height: 24),
              
              // 판매 옵션
              _buildOptionsSection(theme),
              const SizedBox(height: 24),
              
              // 대신판매 조건
              _buildTermsSection(theme),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
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
            onPressed: _isLoading ? null : _registerResale,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '대신팔기 등록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '대신팔기란?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 판매자를 대신하여 상품을 판매하는 서비스입니다\n'
            '• 상품 촬영, 설명 작성, 구매자 응대를 대행합니다\n'
            '• 판매 완료 시 설정한 수수료를 받습니다\n'
            '• 대신판매자 인증을 받은 회원만 이용 가능합니다',
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductInfoSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '상품 정보',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: '상품명',
            hintText: '상품명을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '상품명을 입력하세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: '상품 설명',
            hintText: '상품의 상태, 특징 등을 상세히 작성하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '상품 설명을 입력하세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        // 상품 상태 선택
        DropdownButtonFormField<String>(
          value: _condition,
          decoration: InputDecoration(
            labelText: '상품 상태',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: ['새상품', '거의새것', '사용감있음', '하자있음']
              .map((condition) => DropdownMenuItem(
                    value: condition,
                    child: Text(condition),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _condition = value!;
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildPriceSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '가격 및 수수료',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '판매 가격',
            suffixText: '원',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '판매 가격을 입력하세요';
            }
            final price = int.tryParse(value);
            if (price == null || price <= 0) {
              return '올바른 가격을 입력하세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // 수수료 타입 선택
        Text(
          '수수료 방식',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('퍼센트'),
                value: 'percentage',
                groupValue: _commissionType,
                onChanged: (value) {
                  setState(() {
                    _commissionType = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('고정금액'),
                value: 'fixed',
                groupValue: _commissionType,
                onChanged: (value) {
                  setState(() {
                    _commissionType = value!;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_commissionType == 'percentage')
          Slider(
            value: _commissionRate,
            min: 5,
            max: 30,
            divisions: 25,
            label: '${_commissionRate.toStringAsFixed(0)}%',
            onChanged: (value) {
              setState(() {
                _commissionRate = value;
              });
            },
          )
        else
          TextFormField(
            controller: _commissionController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: '수수료 금액',
              suffixText: '원',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _commissionFixed = int.tryParse(value) ?? 0;
              });
            },
          ),
        // 예상 수령액 표시
        if (_priceController.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '예상 수수료',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  _calculateCommission(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildOptionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '판매 옵션',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('배송 대행'),
          subtitle: const Text('포장 및 배송을 대행합니다'),
          value: _includeDelivery,
          onChanged: (value) {
            setState(() {
              _includeDelivery = value;
            });
          },
        ),
        SwitchListTile(
          title: const Text('가격 협상 허용'),
          subtitle: const Text('구매자와 가격 협상이 가능합니다'),
          value: _allowNegotiation,
          onChanged: (value) {
            setState(() {
              _allowNegotiation = value;
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildTermsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '대신판매 조건',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 상품은 대신판매자가 직접 확인 후 판매됩니다\n'
            '• 판매 완료 시 설정한 수수료가 차감됩니다\n'
            '• 상품 상태가 설명과 다를 경우 판매가 취소될 수 있습니다\n'
            '• 판매 기간은 등록일로부터 30일입니다',
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  String _calculateCommission() {
    final price = int.tryParse(_priceController.text) ?? 0;
    if (price == 0) return '0원';
    
    int commission;
    if (_commissionType == 'percentage') {
      commission = (price * _commissionRate / 100).round();
    } else {
      commission = _commissionFixed;
    }
    
    return '${commission.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }
}