import 'package:flutter/material.dart';
import '../../services/review_service.dart';
import '../../services/user_service.dart';
import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class ReviewListScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const ReviewListScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> 
    with SingleTickerProviderStateMixin {
  final ReviewService _reviewService = ReviewService();
  final UserService _userService = UserService();
  
  late TabController _tabController;
  List<ReviewModel> _receivedReviews = [];
  List<ReviewModel> _writtenReviews = [];
  Map<String, UserModel> _userCache = {};
  bool _isLoading = true;
  
  // 리뷰 통계
  double _averageRating = 0.0;
  Map<int, int> _ratingDistribution = {
    5: 0,
    4: 0,
    3: 0,
    2: 0,
    1: 0,
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReviews();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadReviews() async {
    try {
      setState(() => _isLoading = true);
      
      // 받은 리뷰 로드
      final received = await _reviewService.getReceivedReviews(widget.userId);
      
      // 작성한 리뷰 로드
      final written = await _reviewService.getWrittenReviews(widget.userId);
      
      // 사용자 정보 로드
      final userIds = <String>{};
      for (final review in [...received, ...written]) {
        userIds.add(review.reviewerId);
        userIds.add(review.revieweeId);
      }
      
      for (final userId in userIds) {
        if (!_userCache.containsKey(userId)) {
          final user = await _userService.getUserById(userId);
          if (user != null) {
            _userCache[userId] = user;
          }
        }
      }
      
      // 평점 통계 계산
      if (received.isNotEmpty) {
        double totalRating = 0;
        for (final review in received) {
          totalRating += review.rating;
          final roundedRating = review.rating.round();
          _ratingDistribution[roundedRating] = 
              (_ratingDistribution[roundedRating] ?? 0) + 1;
        }
        _averageRating = totalRating / received.length;
      }
      
      if (mounted) {
        setState(() {
          _receivedReviews = received;
          _writtenReviews = written;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading reviews: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}님의 리뷰'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '받은 리뷰 (${_receivedReviews.length})'),
            Tab(text: '작성한 리뷰 (${_writtenReviews.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReceivedReviews(theme),
                _buildWrittenReviews(theme),
              ],
            ),
    );
  }
  
  Widget _buildReceivedReviews(ThemeData theme) {
    if (_receivedReviews.isEmpty) {
      return _buildEmptyState(
        theme,
        '아직 받은 리뷰가 없습니다',
        '거래를 완료하면 리뷰를 받을 수 있어요',
      );
    }
    
    return CustomScrollView(
      slivers: [
        // 리뷰 통계
        SliverToBoxAdapter(
          child: _buildReviewStatistics(theme),
        ),
        // 리뷰 목록
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final review = _receivedReviews[index];
              final reviewer = _userCache[review.reviewerId];
              return _buildReviewItem(theme, review, reviewer, true);
            },
            childCount: _receivedReviews.length,
          ),
        ),
      ],
    );
  }
  
  Widget _buildWrittenReviews(ThemeData theme) {
    if (_writtenReviews.isEmpty) {
      return _buildEmptyState(
        theme,
        '아직 작성한 리뷰가 없습니다',
        '거래 완료 후 리뷰를 작성해보세요',
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _writtenReviews.length,
      itemBuilder: (context, index) {
        final review = _writtenReviews[index];
        final reviewee = _userCache[review.revieweeId];
        return _buildReviewItem(theme, review, reviewee, false);
      },
    );
  }
  
  Widget _buildReviewStatistics(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 평균 평점
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _averageRating.toStringAsFixed(1),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < _averageRating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                  Text(
                    '${_receivedReviews.length}개의 리뷰',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 평점 분포
          ...List.generate(5, (index) {
            final rating = 5 - index;
            final count = _ratingDistribution[rating] ?? 0;
            final percentage = _receivedReviews.isEmpty
                ? 0.0
                : count / _receivedReviews.length;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '$rating',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildReviewItem(
    ThemeData theme,
    ReviewModel review,
    UserModel? otherUser,
    bool isReceived,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 리뷰어/리뷰이 정보
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  otherUser?.name.substring(0, 1) ?? '?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherUser?.name ?? '알 수 없음',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // 평점
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 태그
          if (review.tags != null && review.tags!.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.tags!.map((tag) {
                return Chip(
                  label: Text(
                    tag,
                    style: theme.textTheme.bodySmall,
                  ),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          // 리뷰 내용
          Text(
            review.content,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(
    ThemeData theme,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return '${difference.inMinutes}분 전';
      }
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}일 전';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}개월 전';
    } else {
      return '${(difference.inDays / 365).floor()}년 전';
    }
  }
}