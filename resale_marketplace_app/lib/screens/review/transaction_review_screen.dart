import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/review_service.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/review_model.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';
import 'review_create_screen.dart';

class TransactionReviewScreen extends StatefulWidget {
  final String transactionId;

  const TransactionReviewScreen({
    super.key,
    required this.transactionId,
  });

  @override
  State<TransactionReviewScreen> createState() => _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends State<TransactionReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  
  TransactionModel? _transaction;
  List<Map<String, dynamic>> _reviewableUsers = [];
  List<ReviewModel> _existingReviews = [];
  String? _currentUserId;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      // 현재 사용자 ID 가져오기
      final user = await _authService.getCurrentUser();
      _currentUserId = user?.id;
      
      if (_currentUserId == null) {
        _showError('로그인이 필요합니다');
        return;
      }
      
      // 거래 정보 로드
      final transaction = await _transactionService.getTransactionById(widget.transactionId);
      
      // 리뷰 가능한 사용자 목록 로드
      final reviewableUsers = await _reviewService.getReviewableUsers(
        transactionId: widget.transactionId,
        currentUserId: _currentUserId!,
      );
      
      // 기존 리뷰 목록 로드
      final existingReviews = await _reviewService.getTransactionReviews(widget.transactionId);
      
      if (mounted) {
        setState(() {
          _transaction = transaction;
          _reviewableUsers = reviewableUsers;
          _existingReviews = existingReviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('데이터를 불러오는데 실패했습니다');
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
  
  Future<void> _navigateToCreateReview(Map<String, dynamic> reviewableUser) async {
    if (_transaction == null) return;
    
    final result = await Navigator.push<ReviewModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewCreateScreen(
          transaction: _transaction!,
          reviewedUserId: reviewableUser['user_id'],
          reviewedUserName: reviewableUser['name'],
          isSellerReview: reviewableUser['role'] == '판매자',
        ),
      ),
    );
    
    if (result != null) {
      _showSuccess('리뷰가 작성되었습니다');
      _loadData(); // 데이터 새로고침
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CommonAppBar(
        title: '거래 후기',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 거래 정보
                  if (_transaction != null) _buildTransactionInfo(),
                  
                  const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                  
                  // 리뷰 작성 가능한 사용자
                  if (_reviewableUsers.isNotEmpty) _buildReviewableUsers(),
                  
                  // 기존 리뷰 목록
                  if (_existingReviews.isNotEmpty) ...[
                    const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                    _buildExistingReviews(),
                  ],
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }
  
  Widget _buildTransactionInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '거래 정보',
            style: AppStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: _transaction!.productImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _transaction!.productImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _transaction!.productTitle ?? '상품명 없음',
                      style: AppStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _transaction!.formattedPrice,
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '거래완료: ${_formatDate(_transaction!.completedAt ?? _transaction!.createdAt)}',
                      style: AppStyles.bodySmall.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewableUsers() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '리뷰 작성하기',
            style: AppStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '거래 상대방에게 후기를 남겨보세요',
            style: AppStyles.bodySmall.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._reviewableUsers.map((user) => _buildReviewableUserItem(user)).toList(),
        ],
      ),
    );
  }
  
  Widget _buildReviewableUserItem(Map<String, dynamic> user) {
    final alreadyReviewed = user['already_reviewed'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: alreadyReviewed ? Colors.grey[50] : Colors.white,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            backgroundImage: user['profile_image'] != null
                ? NetworkImage(user['profile_image'])
                : null,
            child: user['profile_image'] == null
                ? Text(
                    user['name'].substring(0, 1),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['role'],
                  style: AppStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (alreadyReviewed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '작성완료',
                style: AppStyles.bodySmall.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _navigateToCreateReview(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
              ),
              child: Text(
                '리뷰 작성',
                style: AppStyles.bodySmall.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildExistingReviews() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '작성된 리뷰 (${_existingReviews.length})',
            style: AppStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._existingReviews.map((review) => _buildReviewItem(review)).toList(),
        ],
      ),
    );
  }
  
  Widget _buildReviewItem(ReviewModel review) {
    final isMyReview = review.reviewerId == _currentUserId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: isMyReview ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                backgroundImage: review.reviewerImage != null
                    ? NetworkImage(review.reviewerImage!)
                    : null,
                child: review.reviewerImage == null
                    ? Text(
                        review.reviewerName?.substring(0, 1) ?? '?',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.reviewerName ?? '알 수 없음',
                          style: AppStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isMyReview) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '내 리뷰',
                              style: AppStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '→ ${review.reviewedUserName ?? '알 수 없음'}',
                      style: AppStyles.bodySmall.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: AppTheme.secondaryColor,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (review.tags != null && review.tags!.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: review.tags!.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: AppStyles.bodySmall.copyWith(
                      color: AppTheme.primaryColor,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            review.comment,
            style: AppStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            review.formattedDate,
            style: AppStyles.bodySmall.copyWith(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}