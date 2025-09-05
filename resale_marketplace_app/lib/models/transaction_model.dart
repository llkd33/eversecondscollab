class TransactionModel {
  final String id;
  final String productId;
  final int price;
  final int resaleFee;
  final String buyerId;
  final String sellerId;
  final String? resellerId; // 대신판매자
  final String status; // 거래중, 거래중단, 거래완료
  final String? chatId;
  final String transactionType; // 일반거래, 안전거래
  final DateTime createdAt;
  final DateTime? completedAt;
  
  // 추가 정보 (조인)
  final String? productTitle;
  final String? productImage;
  final String? buyerName;
  final String? sellerName;
  final String? resellerName;

  TransactionModel({
    required this.id,
    required this.productId,
    required this.price,
    this.resaleFee = 0,
    required this.buyerId,
    required this.sellerId,
    this.resellerId,
    this.status = TransactionStatus.ongoing,
    this.chatId,
    this.transactionType = TransactionType.normal,
    required this.createdAt,
    this.completedAt,
    this.productTitle,
    this.productImage,
    this.buyerName,
    this.sellerName,
    this.resellerName,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('Transaction ID cannot be empty');
    if (productId.isEmpty) throw ArgumentError('Product ID cannot be empty');
    if (buyerId.isEmpty) throw ArgumentError('Buyer ID cannot be empty');
    if (sellerId.isEmpty) throw ArgumentError('Seller ID cannot be empty');
    if (buyerId == sellerId) throw ArgumentError('Buyer and seller cannot be the same');
    if (price <= 0) throw ArgumentError('Transaction price must be positive');
    if (resaleFee < 0) throw ArgumentError('Resale fee cannot be negative');
    if (resaleFee > price) throw ArgumentError('Resale fee cannot exceed product price');
    if (!TransactionStatus.isValid(status)) throw ArgumentError('Invalid transaction status');
    if (!TransactionType.isValid(transactionType)) throw ArgumentError('Invalid transaction type');
    if (resellerId != null && resellerId == sellerId) {
      throw ArgumentError('Reseller cannot be the same as seller');
    }
    if (resellerId != null && resellerId == buyerId) {
      throw ArgumentError('Reseller cannot be the same as buyer');
    }
  }

  // JSON에서 Transaction 객체 생성
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      productId: json['product_id'],
      price: json['price'],
      resaleFee: json['resale_fee'] ?? 0,
      buyerId: json['buyer_id'],
      sellerId: json['seller_id'],
      resellerId: json['reseller_id'],
      status: json['status'] ?? '거래중',
      chatId: json['chat_id'],
      transactionType: json['transaction_type'] ?? '일반거래',
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : null,
      productTitle: json['product_title'],
      productImage: json['product_image'],
      buyerName: json['buyer_name'],
      sellerName: json['seller_name'],
      resellerName: json['reseller_name'],
    );
  }

  // Transaction 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'price': price,
      'resale_fee': resaleFee,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'reseller_id': resellerId,
      'status': status,
      'chat_id': chatId,
      'transaction_type': transactionType,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      if (productTitle != null) 'product_title': productTitle,
      if (productImage != null) 'product_image': productImage,
      if (buyerName != null) 'buyer_name': buyerName,
      if (sellerName != null) 'seller_name': sellerName,
      if (resellerName != null) 'reseller_name': resellerName,
    };
  }

  // copyWith 메서드
  TransactionModel copyWith({
    String? id,
    String? productId,
    int? price,
    int? resaleFee,
    String? buyerId,
    String? sellerId,
    String? resellerId,
    String? status,
    String? chatId,
    String? transactionType,
    DateTime? createdAt,
    DateTime? completedAt,
    String? productTitle,
    String? productImage,
    String? buyerName,
    String? sellerName,
    String? resellerName,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      price: price ?? this.price,
      resaleFee: resaleFee ?? this.resaleFee,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      resellerId: resellerId ?? this.resellerId,
      status: status ?? this.status,
      chatId: chatId ?? this.chatId,
      transactionType: transactionType ?? this.transactionType,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
      buyerName: buyerName ?? this.buyerName,
      sellerName: sellerName ?? this.sellerName,
      resellerName: resellerName ?? this.resellerName,
    );
  }

  // 헬퍼 메서드
  bool get isResaleTransaction => resellerId != null;
  bool get isSafeTransaction => transactionType == '안전거래';
  bool get isCompleted => status == '거래완료';
  bool get isOngoing => status == '거래중';
  bool get isCanceled => status == '거래중단';
  
  // 판매자가 받을 금액
  int get sellerAmount => isResaleTransaction ? price - resaleFee : price;
  
  // 대신판매자가 받을 금액
  int get resellerCommission => resaleFee;
  
  // 가격 포맷팅
  String get formattedPrice => '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  String get formattedResaleFee => '${resaleFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
}

// 거래 상태 enum
class TransactionStatus {
  static const String ongoing = '거래중';
  static const String canceled = '거래중단';
  static const String completed = '거래완료';

  static const List<String> all = [ongoing, canceled, completed];
  static bool isValid(String status) => all.contains(status);
}

// 거래 타입 enum
class TransactionType {
  static const String normal = '일반거래';
  static const String safe = '안전거래';

  static const List<String> all = [normal, safe];
  static bool isValid(String type) => all.contains(type);
}