class SafeTransactionModel {
  final String id;
  final String transactionId;
  final int depositAmount;
  final bool depositConfirmed;
  final DateTime? depositConfirmedAt;
  final bool shippingConfirmed;
  final DateTime? shippingConfirmedAt;
  final bool deliveryConfirmed;
  final DateTime? deliveryConfirmedAt;
  final String settlementStatus; // 대기중, 정산준비, 정산완료
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 추가 정보
  final String? buyerName;
  final String? buyerPhone;
  final String? sellerName;
  final String? sellerPhone;
  final String? productTitle;

  SafeTransactionModel({
    required this.id,
    required this.transactionId,
    required this.depositAmount,
    this.depositConfirmed = false,
    this.depositConfirmedAt,
    this.shippingConfirmed = false,
    this.shippingConfirmedAt,
    this.deliveryConfirmed = false,
    this.deliveryConfirmedAt,
    this.settlementStatus = SettlementStatus.waiting,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    this.buyerName,
    this.buyerPhone,
    this.sellerName,
    this.sellerPhone,
    this.productTitle,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('안전거래 ID는 비어있을 수 없습니다');
    if (transactionId.isEmpty) throw ArgumentError('거래 ID는 비어있을 수 없습니다');
    if (depositAmount <= 0) throw ArgumentError('예치금액은 0보다 커야 합니다');
    if (!SettlementStatus.isValid(settlementStatus)) {
      throw ArgumentError('유효하지 않은 정산 상태입니다');
    }
    if (adminNotes != null && adminNotes!.length > 1000) {
      throw ArgumentError('관리자 메모가 너무 깁니다 (최대 1000자)');
    }
  }

  // JSON에서 SafeTransaction 객체 생성
  factory SafeTransactionModel.fromJson(Map<String, dynamic> json) {
    return SafeTransactionModel(
      id: json['id'],
      transactionId: json['transaction_id'],
      depositAmount: json['deposit_amount'],
      depositConfirmed: json['deposit_confirmed'] ?? false,
      depositConfirmedAt: json['deposit_confirmed_at'] != null
          ? DateTime.parse(json['deposit_confirmed_at'])
          : null,
      shippingConfirmed: json['shipping_confirmed'] ?? false,
      shippingConfirmedAt: json['shipping_confirmed_at'] != null
          ? DateTime.parse(json['shipping_confirmed_at'])
          : null,
      deliveryConfirmed: json['delivery_confirmed'] ?? false,
      deliveryConfirmedAt: json['delivery_confirmed_at'] != null
          ? DateTime.parse(json['delivery_confirmed_at'])
          : null,
      settlementStatus: json['settlement_status'] ?? '대기중',
      adminNotes: json['admin_notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      buyerName: json['buyer_name'],
      buyerPhone: json['buyer_phone'],
      sellerName: json['seller_name'],
      sellerPhone: json['seller_phone'],
      productTitle: json['product_title'],
    );
  }

  // SafeTransaction 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'deposit_amount': depositAmount,
      'deposit_confirmed': depositConfirmed,
      'deposit_confirmed_at': depositConfirmedAt?.toIso8601String(),
      'shipping_confirmed': shippingConfirmed,
      'shipping_confirmed_at': shippingConfirmedAt?.toIso8601String(),
      'delivery_confirmed': deliveryConfirmed,
      'delivery_confirmed_at': deliveryConfirmedAt?.toIso8601String(),
      'settlement_status': settlementStatus,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (buyerName != null) 'buyer_name': buyerName,
      if (buyerPhone != null) 'buyer_phone': buyerPhone,
      if (sellerName != null) 'seller_name': sellerName,
      if (sellerPhone != null) 'seller_phone': sellerPhone,
      if (productTitle != null) 'product_title': productTitle,
    };
  }

  // copyWith 메서드
  SafeTransactionModel copyWith({
    String? id,
    String? transactionId,
    int? depositAmount,
    bool? depositConfirmed,
    DateTime? depositConfirmedAt,
    bool? shippingConfirmed,
    DateTime? shippingConfirmedAt,
    bool? deliveryConfirmed,
    DateTime? deliveryConfirmedAt,
    String? settlementStatus,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? buyerName,
    String? buyerPhone,
    String? sellerName,
    String? sellerPhone,
    String? productTitle,
  }) {
    return SafeTransactionModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      depositAmount: depositAmount ?? this.depositAmount,
      depositConfirmed: depositConfirmed ?? this.depositConfirmed,
      depositConfirmedAt: depositConfirmedAt ?? this.depositConfirmedAt,
      shippingConfirmed: shippingConfirmed ?? this.shippingConfirmed,
      shippingConfirmedAt: shippingConfirmedAt ?? this.shippingConfirmedAt,
      deliveryConfirmed: deliveryConfirmed ?? this.deliveryConfirmed,
      deliveryConfirmedAt: deliveryConfirmedAt ?? this.deliveryConfirmedAt,
      settlementStatus: settlementStatus ?? this.settlementStatus,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      buyerName: buyerName ?? this.buyerName,
      buyerPhone: buyerPhone ?? this.buyerPhone,
      sellerName: sellerName ?? this.sellerName,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      productTitle: productTitle ?? this.productTitle,
    );
  }

  // 헬퍼 메서드
  // 현재 단계 확인
  String get currentStep {
    if (!depositConfirmed) return '입금 대기중';
    if (!shippingConfirmed) return '배송 준비중';
    if (!deliveryConfirmed) return '배송중';
    if (settlementStatus == '대기중') return '정산 대기중';
    if (settlementStatus == '정산준비') return '정산 준비중';
    return '정산 완료';
  }
  
  // 진행률 계산 (0.0 ~ 1.0)
  double get progress {
    int steps = 0;
    if (depositConfirmed) steps++;
    if (shippingConfirmed) steps++;
    if (deliveryConfirmed) steps++;
    if (settlementStatus == '정산준비') steps++;
    if (settlementStatus == '정산완료') steps++;
    return steps / 5.0;
  }
  
  // 진행률 퍼센트
  String get progressPercent => '${(progress * 100).toInt()}%';
  
  // 금액 포맷팅
  String get formattedDepositAmount => 
      '${depositAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  
  // 정산 가능 여부
  bool get canSettle => deliveryConfirmed && settlementStatus == '대기중';
  
  // 거래 완료 여부
  bool get isCompleted => settlementStatus == '정산완료';
}

// 정산 상태 enum
class SettlementStatus {
  static const String waiting = '대기중';
  static const String preparing = '정산준비';
  static const String completed = '정산완료';

  static const List<String> all = [waiting, preparing, completed];
  static bool isValid(String status) => all.contains(status);
}

// 안전거래 은행 계좌 정보
class SafeTransactionAccount {
  static const String bankName = '신한은행';
  static const String accountNumber = '110-123-456789';
  static const String accountHolder = '(주)에버세컨즈';
  
  static String get fullAccountInfo => '$bankName $accountNumber $accountHolder';
}