class ReviewModel {
  final String id;
  final String reviewerId;
  final String reviewedUserId;
  final String transactionId;
  final int rating; // 1-5 별점
  final String comment;
  final DateTime createdAt;
  
  // 추가 정보
  final String? reviewerName;
  final String? reviewerImage;
  final String? reviewedUserName;
  final String? reviewedUserImage;
  final String? productTitle;

  ReviewModel({
    required this.id,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.transactionId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.reviewerName,
    this.reviewerImage,
    this.reviewedUserName,
    this.reviewedUserImage,
    this.productTitle,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('Review ID cannot be empty');
    if (reviewerId.isEmpty) throw ArgumentError('Reviewer ID cannot be empty');
    if (reviewedUserId.isEmpty) throw ArgumentError('Reviewed user ID cannot be empty');
    if (transactionId.isEmpty) throw ArgumentError('Transaction ID cannot be empty');
    if (reviewerId == reviewedUserId) throw ArgumentError('Cannot review yourself');
    if (rating < 1 || rating > 5) throw ArgumentError('Rating must be between 1 and 5');
    if (comment.isEmpty) throw ArgumentError('Review comment cannot be empty');
    if (comment.length > 500) throw ArgumentError('Review comment too long (max 500 characters)');
  }

  // JSON에서 Review 객체 생성
  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'],
      reviewerId: json['reviewer_id'],
      reviewedUserId: json['reviewed_user_id'],
      transactionId: json['transaction_id'],
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
      reviewerName: json['reviewer_name'],
      reviewerImage: json['reviewer_image'],
      reviewedUserName: json['reviewed_user_name'],
      reviewedUserImage: json['reviewed_user_image'],
      productTitle: json['product_title'],
    );
  }

  // Review 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewer_id': reviewerId,
      'reviewed_user_id': reviewedUserId,
      'transaction_id': transactionId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      if (reviewerName != null) 'reviewer_name': reviewerName,
      if (reviewerImage != null) 'reviewer_image': reviewerImage,
      if (reviewedUserName != null) 'reviewed_user_name': reviewedUserName,
      if (reviewedUserImage != null) 'reviewed_user_image': reviewedUserImage,
      if (productTitle != null) 'product_title': productTitle,
    };
  }

  // copyWith 메서드
  ReviewModel copyWith({
    String? id,
    String? reviewerId,
    String? reviewedUserId,
    String? transactionId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    String? reviewerName,
    String? reviewerImage,
    String? reviewedUserName,
    String? reviewedUserImage,
    String? productTitle,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewedUserId: reviewedUserId ?? this.reviewedUserId,
      transactionId: transactionId ?? this.transactionId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerImage: reviewerImage ?? this.reviewerImage,
      reviewedUserName: reviewedUserName ?? this.reviewedUserName,
      reviewedUserImage: reviewedUserImage ?? this.reviewedUserImage,
      productTitle: productTitle ?? this.productTitle,
    );
  }

  // 헬퍼 메서드
  // 별점을 이모지로 표시
  String get ratingStars {
    return '⭐' * rating + '☆' * (5 - rating);
  }
  
  // 별점을 아이콘 리스트로 반환 (UI에서 사용)
  List<bool> get ratingList {
    return List.generate(5, (index) => index < rating);
  }
  
  // 날짜 포맷팅
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    
    if (diff.inDays == 0) return '오늘';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}개월 전';
    
    return '${createdAt.year}년 ${createdAt.month}월';
  }
  
  // 긍정적인 리뷰인지 확인
  bool get isPositive => rating >= 4;
  
  // 부정적인 리뷰인지 확인
  bool get isNegative => rating <= 2;
}