import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../services/review_service.dart';
import '../../services/auth_service.dart';

class ReviewCreateScreen extends StatefulWidget {
  final TransactionModel transaction;
  final String reviewedUserId;
  final String reviewedUserName;
  final bool isSellerReview; // 판매자 리뷰인지 구매자 리뷰인지

  const ReviewCreateScreen({
    super.key,
    required this.transaction,
    required this.reviewedUserId,
    required this.reviewedUserName,
    required this.isSellerReview,
  });

  @override
  State<ReviewCreateScreen> createState() => _ReviewCreateScreenState();
}

class _ReviewCreateScreenState extends State<ReviewCreateScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  
  double _rating = 5.0;
  List<File> _imageFiles = [];
  bool _isSubmitting = false;
  UserModel? _currentUser;
  
  // 거래 평가 항목
  bool _isKind = false;
  bool _isOnTime = false;
  bool _isHonest = false;
  bool _isGoodCondition = false;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }
  
  Future<void> _loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
  }
  
  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CommonAppBar(
        title: '거래 후기 작성',
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitReview,
            child: Text(
              '완료',
              style: TextStyle(
                color: _isSubmitting ? Colors.grey : AppTheme.primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 거래 정보
                  _buildTransactionInfo(),
                  
                  const Divider(height: 1),
                  
                  // 별점 선택
                  _buildRatingSection(),
                  
                  const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                  
                  // 평가 항목
                  _buildEvaluationItems(),
                  
                  const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                  
                  // 후기 내용
                  _buildReviewContent(),
                  
                  const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                  
                  // 사진 첨부
                  _buildImageSection(),
                  
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
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: widget.transaction.productImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.transaction.productImage!,
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
                  widget.transaction.productTitle ?? '상품명 없음',
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${widget.isSellerReview ? '판매자' : '구매자'}: ${widget.reviewedUserName}',
                  style: AppStyles.bodySmall,
                ),
                Text(
                  '거래일: ${_formatDate(widget.transaction.createdAt)}',
                  style: AppStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            '거래는 어떠셨나요?',
            style: AppStyles.headingSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = starValue.toDouble();
                  });
                },
                child: Icon(
                  starValue <= _rating
                      ? Icons.star
                      : Icons.star_border,
                  size: 40,
                  color: AppTheme.secondaryColor,
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _getRatingText(),
            style: AppStyles.bodyMedium.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEvaluationItems() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이런 점이 좋았어요',
            style: AppStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildEvaluationChip(
                '친절해요',
                _isKind,
                (value) => setState(() => _isKind = value),
              ),
              _buildEvaluationChip(
                '시간 약속을 잘 지켜요',
                _isOnTime,
                (value) => setState(() => _isOnTime = value),
              ),
              _buildEvaluationChip(
                '정직해요',
                _isHonest,
                (value) => setState(() => _isHonest = value),
              ),
              if (widget.isSellerReview)
                _buildEvaluationChip(
                  '상품 상태가 좋아요',
                  _isGoodCondition,
                  (value) => setState(() => _isGoodCondition = value),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEvaluationChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      backgroundColor: Colors.grey[200],
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryColor : Colors.black87,
        fontSize: 13,
      ),
    );
  }
  
  Widget _buildReviewContent() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '후기를 남겨주세요',
            style: AppStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _contentController,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '거래 후기를 작성해주세요.\n정직한 후기는 다른 사용자에게 큰 도움이 됩니다.',
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              '사진 첨부 (선택)',
              style: AppStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                // 이미지 추가 버튼
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, 
                          size: 24, 
                          color: Colors.grey[600]
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_imageFiles.length}/5',
                          style: TextStyle(
                            fontSize: 12,
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
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(file),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
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
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
  
  String _getRatingText() {
    switch (_rating.toInt()) {
      case 1:
        return '별로예요';
      case 2:
        return '그저 그래요';
      case 3:
        return '보통이에요';
      case 4:
        return '좋아요';
      case 5:
        return '최고예요!';
      default:
        return '';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
  
  Future<void> _pickImages() async {
    if (_imageFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최대 5장까지 선택 가능합니다')),
      );
      return;
    }
    
    final List<XFile> images = await _picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        final remainingSlots = 5 - _imageFiles.length;
        final imagesToAdd = images.take(remainingSlots);
        _imageFiles.addAll(imagesToAdd.map((x) => File(x.path)));
      });
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }
  
  Future<void> _submitReview() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('후기 내용을 작성해주세요')),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // 이미지 업로드
      List<String> imageUrls = [];
      if (_imageFiles.isNotEmpty) {
        imageUrls = await _reviewService.uploadReviewImages(
          _imageFiles,
          _currentUser!.id,
        );
      }
      
      // 태그 생성
      List<String> tags = [];
      if (_isKind) tags.add('친절해요');
      if (_isOnTime) tags.add('시간 약속을 잘 지켜요');
      if (_isHonest) tags.add('정직해요');
      if (_isGoodCondition) tags.add('상품 상태가 좋아요');
      
      // 리뷰 작성
      final review = await _reviewService.createReview(
        transactionId: widget.transaction.id,
        reviewerId: _currentUser!.id,
        reviewedUserId: widget.reviewedUserId,
        rating: _rating.toInt(),
        content: _contentController.text.trim(),
        tags: tags,
        images: imageUrls,
      );
      
      if (review != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('후기가 작성되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(review);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('후기 작성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}