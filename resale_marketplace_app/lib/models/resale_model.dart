class ResaleRequestModel {
  final String id;
  final String productId;
  final String originalSellerId; // 원 판매자
  final String resellerId; // 대신판매 신청자
  final String status; // pending, approved, rejected, completed
  final int proposedFee; // 제안 수수료
  final int agreedFee; // 합의된 수수료
  final String? requestMessage; // 신청 메시지
  final String? responseMessage; // 응답 메시지
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;
  
  // 조인된 정보
  final String? productTitle;
  final String? productImage;
  final int? productPrice;
  final String? originalSellerName;
  final String? resellerName;
  final String? resellerShopName;

  ResaleRequestModel({
    required this.id,
    required this.productId,
    required this.originalSellerId,
    required this.resellerId,
    this.status = 'pending',
    required this.proposedFee,
    this.agreedFee = 0,
    this.requestMessage,
    this.responseMessage,
    required this.createdAt,
    this.approvedAt,
    this.completedAt,
    this.productTitle,
    this.productImage,
    this.productPrice,
    this.originalSellerName,
    this.resellerName,
    this.resellerShopName,
  });

  factory ResaleRequestModel.fromJson(Map<String, dynamic> json) {
    return ResaleRequestModel(
      id: json['id'],
      productId: json['product_id'],
      originalSellerId: json['original_seller_id'],
      resellerId: json['reseller_id'],
      status: json['status'] ?? 'pending',
      proposedFee: json['proposed_fee'] ?? 0,
      agreedFee: json['agreed_fee'] ?? 0,
      requestMessage: json['request_message'],
      responseMessage: json['response_message'],
      createdAt: DateTime.parse(json['created_at']),
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'])
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : null,
      productTitle: json['product_title'],
      productImage: json['product_image'],
      productPrice: json['product_price'],
      originalSellerName: json['original_seller_name'],
      resellerName: json['reseller_name'],
      resellerShopName: json['reseller_shop_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'original_seller_id': originalSellerId,
      'reseller_id': resellerId,
      'status': status,
      'proposed_fee': proposedFee,
      'agreed_fee': agreedFee,
      'request_message': requestMessage,
      'response_message': responseMessage,
      'created_at': createdAt.toIso8601String(),
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (productTitle != null) 'product_title': productTitle,
      if (productImage != null) 'product_image': productImage,
      if (productPrice != null) 'product_price': productPrice,
      if (originalSellerName != null) 'original_seller_name': originalSellerName,
      if (resellerName != null) 'reseller_name': resellerName,
      if (resellerShopName != null) 'reseller_shop_name': resellerShopName,
    };
  }

  // 헬퍼 메서드
  bool get isPending => status == ResaleStatus.pending;
  bool get isApproved => status == ResaleStatus.approved;
  bool get isRejected => status == ResaleStatus.rejected;
  bool get isCompleted => status == ResaleStatus.completed;
  
  // 수수료 비율 계산
  double get feePercentage {
    if (productPrice == null || productPrice == 0) return 0;
    return (agreedFee > 0 ? agreedFee : proposedFee) / productPrice! * 100;
  }
  
  // 가격 포맷팅
  String get formattedProposedFee => _formatPrice(proposedFee);
  String get formattedAgreedFee => _formatPrice(agreedFee);
  String get formattedProductPrice => productPrice != null ? _formatPrice(productPrice!) : '';
  
  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }

  ResaleRequestModel copyWith({
    String? id,
    String? productId,
    String? originalSellerId,
    String? resellerId,
    String? status,
    int? proposedFee,
    int? agreedFee,
    String? requestMessage,
    String? responseMessage,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? completedAt,
    String? productTitle,
    String? productImage,
    int? productPrice,
    String? originalSellerName,
    String? resellerName,
    String? resellerShopName,
  }) {
    return ResaleRequestModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      originalSellerId: originalSellerId ?? this.originalSellerId,
      resellerId: resellerId ?? this.resellerId,
      status: status ?? this.status,
      proposedFee: proposedFee ?? this.proposedFee,
      agreedFee: agreedFee ?? this.agreedFee,
      requestMessage: requestMessage ?? this.requestMessage,
      responseMessage: responseMessage ?? this.responseMessage,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      completedAt: completedAt ?? this.completedAt,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
      originalSellerName: originalSellerName ?? this.originalSellerName,
      resellerName: resellerName ?? this.resellerName,
      resellerShopName: resellerShopName ?? this.resellerShopName,
    );
  }
}

// 대신팔기 상태
class ResaleStatus {
  static const String pending = 'pending'; // 대기중
  static const String approved = 'approved'; // 승인됨
  static const String rejected = 'rejected'; // 거절됨
  static const String completed = 'completed'; // 완료됨
}

// 샵 상품 모델
class ShopProductModel {
  final String id;
  final String shopId;
  final String productId;
  final String? resaleRequestId; // 대신팔기 요청 ID
  final bool isResaleProduct; // 대신팔기 상품 여부
  final int displayOrder;
  final DateTime addedAt;
  
  // 조인된 정보
  final String? productTitle;
  final String? productImage;
  final int? productPrice;
  final String? productStatus;
  final String? originalSellerId;
  final String? originalSellerName;

  ShopProductModel({
    required this.id,
    required this.shopId,
    required this.productId,
    this.resaleRequestId,
    this.isResaleProduct = false,
    this.displayOrder = 0,
    required this.addedAt,
    this.productTitle,
    this.productImage,
    this.productPrice,
    this.productStatus,
    this.originalSellerId,
    this.originalSellerName,
  });

  factory ShopProductModel.fromJson(Map<String, dynamic> json) {
    return ShopProductModel(
      id: json['id'],
      shopId: json['shop_id'],
      productId: json['product_id'],
      resaleRequestId: json['resale_request_id'],
      isResaleProduct: json['is_resale_product'] ?? false,
      displayOrder: json['display_order'] ?? 0,
      addedAt: DateTime.parse(json['added_at']),
      productTitle: json['product_title'],
      productImage: json['product_image'],
      productPrice: json['product_price'],
      productStatus: json['product_status'],
      originalSellerId: json['original_seller_id'],
      originalSellerName: json['original_seller_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'product_id': productId,
      'resale_request_id': resaleRequestId,
      'is_resale_product': isResaleProduct,
      'display_order': displayOrder,
      'added_at': addedAt.toIso8601String(),
      if (productTitle != null) 'product_title': productTitle,
      if (productImage != null) 'product_image': productImage,
      if (productPrice != null) 'product_price': productPrice,
      if (productStatus != null) 'product_status': productStatus,
      if (originalSellerId != null) 'original_seller_id': originalSellerId,
      if (originalSellerName != null) 'original_seller_name': originalSellerName,
    };
  }
}

// 정산 모델
class SettlementModel {
  final String id;
  final String transactionId;
  final String userId;
  final int amount;
  final String type; // 판매대금, 대신판매수수료
  final String status; // pending, completed, failed
  final DateTime createdAt;
  final DateTime? completedAt;
  
  // 조인된 정보
  final String? userName;
  final String? transactionNumber;

  SettlementModel({
    required this.id,
    required this.transactionId,
    required this.userId,
    required this.amount,
    required this.type,
    this.status = 'pending',
    required this.createdAt,
    this.completedAt,
    this.userName,
    this.transactionNumber,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    return SettlementModel(
      id: json['id'],
      transactionId: json['transaction_id'],
      userId: json['user_id'],
      amount: json['amount'],
      type: json['type'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : null,
      userName: json['user_name'],
      transactionNumber: json['transaction_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (userName != null) 'user_name': userName,
      if (transactionNumber != null) 'transaction_number': transactionNumber,
    };
  }

  // 헬퍼 메서드
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  
  String get formattedAmount => '${amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  )}원';
}