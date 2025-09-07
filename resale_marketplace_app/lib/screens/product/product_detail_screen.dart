import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../widgets/common_app_bar.dart';
import '../../theme/app_theme.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/product_service.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../services/shop_service.dart';
import '../../services/transaction_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_guard.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  final UserService _userService = UserService();
  final ShopService _shopService = ShopService();
  final TransactionService _transactionService = TransactionService();
  final PageController _pageController = PageController();
  
  ProductModel? _product;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isUpdating = false;
  int _currentImageIndex = 0;
  @override
  void initState() {
    super.initState();
    _loadProductDetail();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '상품 상세',
        showBackButton: true,
        actions: [
          if (_product != null && _currentUser != null && _product!.sellerId == _currentUser!.id)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('수정하기'),
                    ],
                  ),
                ),
                if (_product!.status == '판매중')
                  const PopupMenuItem(
                    value: 'complete',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text('거래완료'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제하기', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _product == null
              ? _buildErrorState()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상품 이미지
                            _buildImageSection(),
                            
                            // 상품 정보
                            _buildProductInfo(),
                            
                            // 판매자 정보
                            _buildSellerInfo(),
                            
                            // 상품 설명
                            _buildProductDescription(),
                          ],
                        ),
                      ),
                    ),
                    
                    // 하단 버튼
                    _buildBottomButtons(),
                  ],
                ),
    );
  }

  Widget _buildImageSection() {
    if (_product == null) return const SizedBox.shrink();
    
    if (_product!.images.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Colors.grey[300],
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 100,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: _product!.images.length,
            itemBuilder: (context, index) {
              return Image.network(
                _product!.images[index],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              );
            },
          ),
          
          // 이미지 인디케이터
          if (_product!.images.length > 1)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${_product!.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    if (_product == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상품 상태 표시
          if (_product!.status == '판매완료')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Text(
                '판매완료',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          
          Text(
            _product!.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _product!.formattedPrice,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '카테고리: ${_product!.category}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          // 대신팔기 정보
          if (_product!.resaleEnabled && _product!.status == '판매중')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.store, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '대신팔기 가능',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          '수수료: ${_product!.formattedResaleFee} (${_product!.resaleFeePercentage?.toInt() ?? 0}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentUser != null && _currentUser!.id != _product!.sellerId)
                    ElevatedButton(
                      onPressed: _handleResale,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(80, 36),
                      ),
                      child: const Text('대신팔기'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    if (_product == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[300],
            backgroundImage: _product!.sellerProfileImage != null
                ? NetworkImage(_product!.sellerProfileImage!)
                : null,
            child: _product!.sellerProfileImage == null
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _product!.sellerName ?? '판매자',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '등록일: ${_formatDate(_product!.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (_currentUser != null && _currentUser!.id != _product!.sellerId)
            OutlinedButton(
              onPressed: () {
                // 판매자 프로필 보기 (추후 구현)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필 보기 기능 준비중입니다')),
                );
              },
              child: const Text('프로필'),
            ),
        ],
      ),
    );
  }

  Widget _buildProductDescription() {
    if (_product == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상품 설명',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _product!.description ?? '상품 설명이 없습니다.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_product == null || _currentUser == null) return const SizedBox.shrink();
    
    // 본인 상품인 경우
    if (_product!.sellerId == _currentUser!.id) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  context.push('/product/edit/${_product!.id}');
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                ),
                child: const Text('수정하기'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _product!.status == '판매완료' ? null : _markAsSold,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _product!.status == '판매완료' 
                      ? Colors.grey 
                      : Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                ),
                child: Text(
                  _product!.status == '판매완료' ? '판매완료' : '거래완료',
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // 다른 사용자 상품인 경우
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _product!.status == '판매완료' ? null : _startChat,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
              child: const Text('채팅하기'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _product!.status == '판매완료' ? null : _buyProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: _product!.status == '판매완료' 
                    ? Colors.grey 
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
              ),
              child: Text(
                _product!.status == '판매완료' ? '판매완료' : '구매하기',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '상품을 불러올 수 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadProductDetail,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  // 상품 상세 정보 로드
  Future<void> _loadProductDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final product = await _productService.getProductById(widget.productId);
      final currentUser = await _userService.getCurrentUser();

      setState(() {
        _product = product;
        _currentUser = currentUser;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상품 정보를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 메뉴 액션 처리
  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        context.push('/product/edit/${_product!.id}');
        break;
      case 'complete':
        _markAsSold();
        break;
      case 'delete':
        _showDeleteConfirmDialog();
        break;
    }
  }

  // 거래완료 처리
  Future<void> _markAsSold() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래완료'),
        content: const Text('정말로 거래를 완료하시겠습니까?\n완료 후에는 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '완료',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isUpdating = true;
      });

      try {
        final success = await _productService.markAsSold(widget.productId);
        if (success) {
          setState(() {
            _product = _product!.copyWith(status: '판매완료');
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('거래가 완료되었습니다'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('거래완료 처리에 실패했습니다');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('거래완료 처리 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  // 상품 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상품 삭제'),
        content: const Text('정말로 이 상품을 삭제하시겠습니까?\n삭제 후에는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct();
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // 상품 삭제
  Future<void> _deleteProduct() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final success = await _productService.deleteProduct(widget.productId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('상품이 삭제되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } else {
        throw Exception('상품 삭제에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상품 삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  // 대신팔기 처리
  Future<void> _handleResale() async {
    final authProvider = context.read<AuthProvider>();
    
    if (!authProvider.isAuthenticated) {
      _showLoginDialog('대신팔기를 신청하려면 로그인이 필요합니다.');
      return;
    }

    if (_product == null || _currentUser == null) return;

    try {
      // 사용자의 샵 정보 가져오기
      final userShop = await _shopService.getShopByOwnerId(_currentUser!.id);
      if (userShop == null) {
        throw Exception('샵 정보를 찾을 수 없습니다. 먼저 샵을 생성해주세요.');
      }

      // 대신팔기 수수료 확인 다이얼로그
      final confirmed = await _showResaleConfirmDialog();
      if (confirmed != true) return;

      setState(() {
        _isUpdating = true;
      });

      // 대신팔기 상품으로 추가 (기본 수수료 사용)
      final success = await _shopService.addResaleProduct(
        shopId: userShop.id,
        productId: _product!.id,
        commissionPercentage: _product!.resaleFeePercentage ?? 0,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('대신팔기 상품으로 추가되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('대신팔기 추가에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('대신팔기 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  // 대신팔기 확인 다이얼로그
  Future<bool?> _showResaleConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대신팔기 신청'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 상품을 내 샵에서 대신 판매하시겠습니까?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '상품: ${_product!.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('가격: ${_product!.formattedPrice}'),
                  Text('수수료: ${_product!.formattedResaleFee} (${_product!.resaleFeePercentage?.toInt() ?? 0}%)'),
                  Text('내 수익: ${_formatPrice(_product!.resaleFee)}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text(
              '신청',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    if (price >= 10000) {
      if (price % 10000 == 0) {
        return '${(price / 10000).toInt()}만원';
      } else {
        return '${(price / 10000).toStringAsFixed(1)}만원';
      }
    } else {
      return '${_numberWithCommas(price)}원';
    }
  }
  
  String _numberWithCommas(int number) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return number.toString().replaceAllMapped(
      formatter,
      (match) => '${match[1]},',
    );
  }

  // 채팅 시작
  Future<void> _startChat() async {
    final authProvider = context.read<AuthProvider>();
    
    if (!authProvider.isAuthenticated) {
      _showLoginDialog('채팅을 시작하려면 로그인이 필요합니다.');
      return;
    }

    if (_product == null || _currentUser == null) return;

    try {
      // 채팅 서비스 import 필요
      final chatService = ChatService();
      
      // 채팅방 생성 또는 기존 채팅방 찾기
      final chat = await chatService.createChat(
        participants: [_currentUser!.id, _product!.sellerId],
        productId: _product!.id,
      );

      if (chat != null) {
        // 채팅방으로 이동
        if (mounted) {
          context.push('/chat/room/${chat.id}');
        }
      } else {
        throw Exception('채팅방 생성에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('채팅방 생성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 구매하기
  Future<void> _buyProduct() async {
    final authProvider = context.read<AuthProvider>();
    
    if (!authProvider.isAuthenticated) {
      _showLoginDialog('구매하려면 로그인이 필요합니다.');
      return;
    }

    if (_product == null || _currentUser == null) return;

    try {
      // 구매 확인 다이얼로그
      final confirmed = await _showBuyConfirmDialog();
      if (confirmed != true) return;

      setState(() {
        _isUpdating = true;
      });

      // 채팅방 먼저 생성
      final chatService = ChatService();
      final chat = await chatService.createChat(
        participants: [_currentUser!.id, _product!.sellerId],
        productId: _product!.id,
      );

      if (chat == null) {
        throw Exception('채팅방 생성에 실패했습니다');
      }

      // 거래 생성
      final transaction = await _transactionService.createTransaction(
        productId: _product!.id,
        buyerId: _currentUser!.id,
        sellerId: _product!.sellerId,
        price: _product!.price,
        resaleFee: _product!.resaleFee,
        chatId: chat.id,
        transactionType: '일반거래',
      );

      if (transaction != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('거래가 시작되었습니다. 채팅방에서 거래를 진행해주세요.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 채팅방으로 이동
          context.push('/chat/room/${chat.id}');
        }
      } else {
        throw Exception('거래 생성에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구매 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  // 구매 확인 다이얼로그
  Future<bool?> _showBuyConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구매 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 상품을 구매하시겠습니까?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '상품: ${_product!.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('가격: ${_product!.formattedPrice}'),
                  Text('판매자: ${_product!.sellerName ?? '판매자'}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '구매 버튼을 누르면 채팅방이 생성되고 판매자와 거래를 진행할 수 있습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text(
              '구매',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 상품 공유
  void _shareProduct() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공유 기능 준비중입니다')),
    );
  }

  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
  
  // 로그인 다이얼로그 표시
  void _showLoginDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그인 필요'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                final currentPath = GoRouterState.of(context).uri.toString();
                context.push('/login?redirect=$currentPath');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text(
                '로그인',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
