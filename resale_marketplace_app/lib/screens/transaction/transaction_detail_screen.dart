import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/transaction_service.dart';
import '../../services/auth_service.dart';
import '../../models/transaction_model.dart';
import '../../utils/app_router.dart';
import '../../theme/app_theme.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final TransactionService _transactionService = TransactionService();
  final AuthService _authService = AuthService();
  
  TransactionModel? _transaction;
  bool _isLoading = true;
  String? _currentUserId;
  
  // 사용자 역할
  bool get isBuyer => _transaction?.buyerId == _currentUserId;
  bool get isSeller => _transaction?.sellerId == _currentUserId;
  bool get isReseller => _transaction?.resellerId == _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }
  
  // 거래 정보 로드
  Future<void> _loadTransaction() async {
    try {
      // 현재 사용자 ID 가져오기
      final user = await _authService.getCurrentUser();
      _currentUserId = user?.id;
      
      final transaction = await _transactionService.getTransactionById(
        widget.transactionId,
      );
      
      if (mounted) {
        setState(() {
          _transaction = transaction;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading transaction: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 결제 확인 (구매자)
  Future<void> _confirmPayment() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결제 확인'),
        content: const Text('결제를 완료하셨습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final success = await _transactionService.confirmPayment(
        transactionId: widget.transactionId,
        paymentMethod: '카드결제', // 실제로는 선택하도록 구현
      );
      
      if (success) {
        _showMessage('결제가 확인되었습니다');
        _loadTransaction();
      } else {
        _showError('결제 확인에 실패했습니다');
      }
    }
  }
  
  // 배송 시작 (판매자)
  Future<void> _startShipping() async {
    final trackingNumberController = TextEditingController();
    final courierController = TextEditingController();
    
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배송 정보 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: trackingNumberController,
              decoration: const InputDecoration(
                labelText: '운송장 번호',
                hintText: '운송장 번호를 입력하세요',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: courierController,
              decoration: const InputDecoration(
                labelText: '택배사',
                hintText: '택배사를 입력하세요',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (trackingNumberController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'trackingNumber': trackingNumberController.text,
                  'courier': courierController.text,
                });
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      final success = await _transactionService.startShipping(
        transactionId: widget.transactionId,
        trackingNumber: result['trackingNumber']!,
        courier: result['courier'],
      );
      
      if (success) {
        _showMessage('배송이 시작되었습니다');
        _loadTransaction();
      } else {
        _showError('배송 시작에 실패했습니다');
      }
    }
  }
  
  // 수령 확인 (구매자)
  Future<void> _confirmReceipt() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수령 확인'),
        content: const Text('상품을 수령하셨습니까?\n수령 확인 후에는 취소할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('수령 확인'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final success = await _transactionService.confirmReceipt(
        transactionId: widget.transactionId,
      );
      
      if (success) {
        _showMessage('거래가 완료되었습니다');
        _loadTransaction();
      } else {
        _showError('수령 확인에 실패했습니다');
      }
    }
  }
  
  // 거래 취소
  Future<void> _cancelTransaction() async {
    final reasonController = TextEditingController();
    
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래 취소'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('거래를 취소하시겠습니까?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '취소 사유',
                hintText: '취소 사유를 입력하세요',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('돌아가기'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('거래 취소'),
          ),
        ],
      ),
    );
    
    if (reason != null) {
      final success = await _transactionService.updateTransactionStatus(
        transactionId: widget.transactionId,
        newStatus: TransactionStatus.canceled,
        reason: reason,
      );
      
      if (success) {
        _showMessage('거래가 취소되었습니다');
        _loadTransaction();
      } else {
        _showError('거래 취소에 실패했습니다');
      }
    }
  }
  
  // 메시지 표시
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  // 에러 메시지 표시
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('거래 정보를 불러올 수 없습니다'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 상세'),
        centerTitle: true,
        actions: [
          if (_transaction!.chatId != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRouter.chatRoom,
                  arguments: _transaction!.chatId,
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 거래 상태 헤더
            _buildStatusHeader(theme),
            // 상품 정보
            _buildProductInfo(theme),
            // 거래 정보
            _buildTransactionInfo(theme),
            // 거래 당사자 정보
            _buildParticipantInfo(theme),
            // 안전거래 프로세스 (안전거래인 경우)
            if (_transaction!.isSafeTransaction)
              _buildSafeTransactionProcess(theme),
            // 액션 버튼
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusHeader(ThemeData theme) {
    Color statusColor;
    IconData statusIcon;
    
    switch (_transaction!.status) {
      case TransactionStatus.ongoing:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case TransactionStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case TransactionStatus.canceled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusIcon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      color: statusColor.withOpacity(0.1),
      child: Column(
        children: [
          Icon(
            statusIcon,
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            _transaction!.status,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_transaction!.isSafeTransaction)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '안전거래',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildProductInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '상품 정보',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 상품 이미지
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _transaction!.productImage != null
                        ? Image.network(
                            _transaction!.productImage!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: theme.colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.image,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  // 상품 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _transaction!.productTitle ?? '상품명 없음',
                          style: theme.textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _transaction!.formattedPrice,
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
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '거래 정보',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    theme,
                    '거래 번호',
                    _transaction!.id.substring(0, 8).toUpperCase(),
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    theme,
                    '거래 방식',
                    _transaction!.transactionType,
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    theme,
                    '거래 일시',
                    _formatDateTime(_transaction!.createdAt),
                  ),
                  if (_transaction!.completedAt != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      theme,
                      '완료 일시',
                      _formatDateTime(_transaction!.completedAt!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildParticipantInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '거래 당사자',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 구매자
                  _buildParticipantRow(
                    theme,
                    '구매자',
                    _transaction!.buyerName ?? '알 수 없음',
                    isBuyer,
                  ),
                  const Divider(height: 24),
                  // 판매자
                  _buildParticipantRow(
                    theme,
                    '판매자',
                    _transaction!.sellerName ?? '알 수 없음',
                    isSeller,
                  ),
                  // 대신판매자 (있는 경우)
                  if (_transaction!.isResaleTransaction) ...[
                    const Divider(height: 24),
                    _buildParticipantRow(
                      theme,
                      '대신판매자',
                      _transaction!.resellerName ?? '알 수 없음',
                      isReseller,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 대신판매 수수료 정보
          if (_transaction!.isResaleTransaction) ...[
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '대신판매 수수료',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        _transaction!.formattedResaleFee,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '판매자 수령액',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        _formatPrice(_transaction!.sellerAmount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSafeTransactionProcess(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '안전거래 진행 상황',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProcessStep(
                    theme,
                    '결제 확인',
                    '구매자가 결제를 완료합니다',
                    1,
                    true, // TODO: 실제 상태에 따라 변경
                  ),
                  _buildProcessConnector(theme, true),
                  _buildProcessStep(
                    theme,
                    '배송 시작',
                    '판매자가 상품을 발송합니다',
                    2,
                    false,
                  ),
                  _buildProcessConnector(theme, false),
                  _buildProcessStep(
                    theme,
                    '수령 확인',
                    '구매자가 상품을 확인합니다',
                    3,
                    false,
                  ),
                  _buildProcessConnector(theme, false),
                  _buildProcessStep(
                    theme,
                    '거래 완료',
                    '정산이 완료됩니다',
                    4,
                    false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProcessStep(
    ThemeData theme,
    String title,
    String description,
    int step,
    bool isCompleted,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceVariant,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                description,
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
  
  Widget _buildProcessConnector(ThemeData theme, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(left: 15),
      width: 2,
      height: 24,
      color: isCompleted
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceVariant,
    );
  }
  
  Widget _buildActionButtons(ThemeData theme) {
    if (_transaction!.status != TransactionStatus.ongoing) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 안전거래 액션 버튼
          if (_transaction!.isSafeTransaction) ...[
            if (isBuyer) ...[
              // 결제 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmPayment,
                  icon: const Icon(Icons.payment),
                  label: const Text('결제 확인'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 수령 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmReceipt,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('수령 확인'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
            if (isSeller) ...[
              // 배송 시작 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startShipping,
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('배송 시작'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          // 거래 취소 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelTransaction,
              icon: const Icon(Icons.cancel),
              label: const Text('거래 취소'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildParticipantRow(
    ThemeData theme,
    String role,
    String name,
    bool isMe,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          role,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          children: [
            Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '나',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }
}