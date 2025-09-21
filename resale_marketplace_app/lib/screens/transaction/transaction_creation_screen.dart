import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../services/transaction_service.dart';
import '../../services/chat_service.dart';
import '../../models/product_model.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/safe_network_image.dart';

class TransactionCreationScreen extends StatefulWidget {
  final ProductModel product;
  final String buyerId;
  final String sellerId;
  final String? resellerId;
  final String? chatId;

  const TransactionCreationScreen({
    super.key,
    required this.product,
    required this.buyerId,
    required this.sellerId,
    this.resellerId,
    this.chatId,
  });

  @override
  State<TransactionCreationScreen> createState() =>
      _TransactionCreationScreenState();
}

class _TransactionCreationScreenState extends State<TransactionCreationScreen> {
  final TransactionService _transactionService = TransactionService();
  final ChatService _chatService = ChatService();

  String _selectedTransactionType = TransactionType.normal;
  int _resaleFee = 0;
  final _resaleFeeController = TextEditingController();
  bool _isLoading = false;

  // 대신판매 거래 여부
  bool get isResaleTransaction => widget.resellerId != null;

  @override
  void initState() {
    super.initState();
    if (isResaleTransaction) {
      // 대신판매 수수료 기본값 설정 (10%)
      _resaleFee = (widget.product.price * 0.1).round();
      _resaleFeeController.text = _resaleFee.toString();
    }
  }

  @override
  void dispose() {
    _resaleFeeController.dispose();
    super.dispose();
  }

  // 거래 생성
  Future<void> _createTransaction() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 채팅방이 없으면 생성
      String? chatId = widget.chatId;
      if (chatId == null) {
        final chat = await _chatService.createChat(
          participants: [widget.buyerId, widget.sellerId],
          productId: widget.product.id,
          resellerId: widget.resellerId,
          isResaleChat: isResaleTransaction,
          originalSellerId: isResaleTransaction ? widget.sellerId : null,
        );
        chatId = chat?.id;
      }

      // 거래 생성
      final transaction = await _transactionService.createTransaction(
        productId: widget.product.id,
        buyerId: widget.buyerId,
        sellerId: widget.sellerId,
        price: widget.product.price,
        resellerId: widget.resellerId,
        resaleFee: _resaleFee,
        chatId: chatId,
        transactionType: _selectedTransactionType,
      );

      if (transaction != null && mounted) {
        // 거래 상세 화면으로 이동
        context.goNamed(
          'transaction-detail',
          pathParameters: {'id': transaction.id},
        );
      } else {
        _showError('거래 생성에 실패했습니다.');
      }
    } catch (e) {
      _showError('오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 에러 메시지 표시
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('거래 시작하기'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 정보
            _buildProductInfo(theme),
            const SizedBox(height: 24),

            // 거래 타입 선택
            _buildTransactionTypeSection(theme),
            const SizedBox(height: 24),

            // 대신판매 수수료 설정 (대신판매 거래인 경우만)
            if (isResaleTransaction) ...[
              _buildResaleFeeSection(theme),
              const SizedBox(height: 24),
            ],

            // 거래 금액 요약
            _buildPriceSummary(theme),
            const SizedBox(height: 24),

            // 거래 주의사항
            _buildNoticeSection(theme),
          ],
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
            onPressed: _isLoading ? null : _createTransaction,
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
                    '거래 시작',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 상품 이미지
          SafeNetworkImage(
            imageUrl: widget.product.images.isNotEmpty
                ? widget.product.images[0]
                : null,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 16),
          // 상품 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.product.formattedPrice,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '거래 방식',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // 일반거래
        _buildTransactionTypeCard(
          theme: theme,
          type: TransactionType.normal,
          title: '일반거래',
          description: '판매자와 직접 거래합니다',
          icon: Icons.handshake,
          isSelected: _selectedTransactionType == TransactionType.normal,
        ),
        const SizedBox(height: 8),
        // 안전거래
        _buildTransactionTypeCard(
          theme: theme,
          type: TransactionType.safe,
          title: '안전거래',
          description: '플랫폼이 거래를 중개합니다',
          icon: Icons.security,
          isSelected: _selectedTransactionType == TransactionType.safe,
          badge: '추천',
        ),
      ],
    );
  }

  Widget _buildTransactionTypeCard({
    required ThemeData theme,
    required String type,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    String? badge,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTransactionType = type;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: type,
              groupValue: _selectedTransactionType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTransactionType = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResaleFeeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '대신판매 수수료',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '대신판매 서비스 이용 수수료입니다',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resaleFeeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '수수료 금액',
                  suffixText: '원',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _resaleFee = int.tryParse(value) ?? 0;
                  });
                },
              ),
              const SizedBox(height: 8),
              // 수수료 비율 표시
              Text(
                '판매가의 ${(_resaleFee / widget.product.price * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSummary(ThemeData theme) {
    final sellerAmount = widget.product.price - _resaleFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '거래 금액 요약',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // 상품 가격
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('상품 가격', style: theme.textTheme.bodyMedium),
              Text(
                widget.product.formattedPrice,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (isResaleTransaction) ...[
            const SizedBox(height: 8),
            // 대신판매 수수료
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('대신판매 수수료', style: theme.textTheme.bodyMedium),
                Text(
                  '-${_formatPrice(_resaleFee)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // 판매자 수령액
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '판매자 수령액',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatPrice(sellerAmount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
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
                '거래 주의사항',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _selectedTransactionType == TransactionType.safe
                ? '• 안전거래는 플랫폼이 중개하여 안전한 거래를 보장합니다\n'
                      '• 구매자는 상품을 받은 후 구매확정을 해야 합니다\n'
                      '• 판매자는 입금 확인 후 배송을 시작해야 합니다'
                : '• 일반거래는 당사자 간 직접 거래입니다\n'
                      '• 거래 시 발생하는 문제에 대한 책임은 당사자에게 있습니다\n'
                      '• 안전한 거래를 위해 안전거래를 권장합니다',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  }
}
