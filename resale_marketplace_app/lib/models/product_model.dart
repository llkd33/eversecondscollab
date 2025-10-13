class ProductModel {
  final String id;
  final String title;
  final int price;
  final String? description;
  final List<String> images;
  final String category; // 의류, 전자기기, 생활용품 등
  final String sellerId;
  final String? shopId; // 상품이 속한 샵 ID
  final bool resaleEnabled;
  final int resaleFee; // 수수료 금액
  final double? resaleFeePercentage; // 수수료 퍼센티지
  final String status; // 판매중, 판매완료
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 추가 정보 (조인해서 가져올 수 있는 정보)
  final String? sellerName;
  final String? sellerProfileImage;
  
  // 💳 거래용 계좌정보 (상품별 설정 가능)
  final String? transactionBankName;
  final String? transactionAccountNumber; 
  final String? transactionAccountHolder;
  final bool useDefaultAccount; // 사용자 기본 계좌 사용 여부

  ProductModel({
    required this.id,
    required this.title,
    required this.price,
    this.description,
    required this.images,
    required this.category,
    required this.sellerId,
    this.shopId,
    this.resaleEnabled = false,
    this.resaleFee = 0,
    this.resaleFeePercentage,
    this.status = ProductStatus.onSale,
    required this.createdAt,
    required this.updatedAt,
    this.sellerName,
    this.sellerProfileImage,
    // 거래용 계좌정보
    this.transactionBankName,
    this.transactionAccountNumber,
    this.transactionAccountHolder,
    this.useDefaultAccount = true,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('상품 ID는 비어있을 수 없습니다');
    if (title.isEmpty) throw ArgumentError('상품명은 비어있을 수 없습니다');
    if (title.length > 100) throw ArgumentError('상품명이 너무 깁니다 (최대 100자)');
    if (price <= 0) throw ArgumentError('상품 가격은 0보다 커야 합니다');
    if (price > 100000000) throw ArgumentError('상품 가격이 너무 높습니다 (최대 1억원)');
    if (sellerId.isEmpty) throw ArgumentError('판매자 ID는 비어있을 수 없습니다');
    if (!ProductCategory.isValid(category)) throw ArgumentError('유효하지 않은 상품 카테고리입니다');
    if (!ProductStatus.isValid(status)) throw ArgumentError('유효하지 않은 상품 상태입니다');
    if (resaleFee < 0) throw ArgumentError('대신판매 수수료는 음수일 수 없습니다');
    if (resaleFeePercentage != null && (resaleFeePercentage! < 0 || resaleFeePercentage! > 100)) {
      throw ArgumentError('대신판매 수수료 비율은 0%에서 100% 사이여야 합니다');
    }
    if (description != null && description!.length > 1000) {
      throw ArgumentError('상품 설명이 너무 깁니다 (최대 1000자)');
    }
  }

  // JSON에서 Product 객체 생성
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // 판매자 정보는 조인된 users 테이블에서 가져옴
    final userInfo = json['users'] as Map<String, dynamic>?;
    
    return ProductModel(
      id: json['id'],
      title: json['title'],
      price: json['price'],
      description: json['description'],
      images: json['images'] != null 
          ? List<String>.from(json['images'])
          : [],
      category: ProductCategory.normalize(json['category'] as String?),
      sellerId: json['seller_id'],
      shopId: json['shop_id'],
      resaleEnabled: json['resale_enabled'] ?? false,
      resaleFee: json['resale_fee'] ?? 0,
      resaleFeePercentage: json['resale_fee_percentage']?.toDouble(),
      status: json['status'] ?? '판매중',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      sellerName: userInfo?['name'] ?? json['seller_name'],
      sellerProfileImage: userInfo?['profile_image'] ?? json['seller_profile_image'],
      // 거래용 계좌정보 (암호화된 계좌번호는 서비스에서 복호화)
      transactionBankName: json['transaction_bank_name'],
      transactionAccountNumber: null, // 복호화는 별도 서비스에서 처리
      transactionAccountHolder: json['transaction_account_holder'],
      useDefaultAccount: json['use_default_account'] ?? true,
    );
  }

  // Product 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'description': description,
      'images': images,
      'category': category,
      'seller_id': sellerId,
      'shop_id': shopId,
      'resale_enabled': resaleEnabled,
      'resale_fee': resaleFee,
      'resale_fee_percentage': resaleFeePercentage,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (sellerName != null) 'seller_name': sellerName,
      if (sellerProfileImage != null) 'seller_profile_image': sellerProfileImage,
      // 거래용 계좌정보
      'transaction_bank_name': transactionBankName,
      'transaction_account_holder': transactionAccountHolder,
      'use_default_account': useDefaultAccount,
    };
  }

  // copyWith 메서드
  ProductModel copyWith({
    String? id,
    String? title,
    int? price,
    String? description,
    List<String>? images,
    String? category,
    String? sellerId,
    String? shopId,
    bool? resaleEnabled,
    int? resaleFee,
    double? resaleFeePercentage,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sellerName,
    String? sellerProfileImage,
    // 거래용 계좌정보
    String? transactionBankName,
    String? transactionAccountNumber,
    String? transactionAccountHolder,
    bool? useDefaultAccount,
  }) {
    return ProductModel(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      description: description ?? this.description,
      images: images ?? this.images,
      category: category ?? this.category,
      sellerId: sellerId ?? this.sellerId,
      shopId: shopId ?? this.shopId,
      resaleEnabled: resaleEnabled ?? this.resaleEnabled,
      resaleFee: resaleFee ?? this.resaleFee,
      resaleFeePercentage: resaleFeePercentage ?? this.resaleFeePercentage,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sellerName: sellerName ?? this.sellerName,
      sellerProfileImage: sellerProfileImage ?? this.sellerProfileImage,
      // 거래용 계좌정보
      transactionBankName: transactionBankName ?? this.transactionBankName,
      transactionAccountNumber: transactionAccountNumber ?? this.transactionAccountNumber,
      transactionAccountHolder: transactionAccountHolder ?? this.transactionAccountHolder,
      useDefaultAccount: useDefaultAccount ?? this.useDefaultAccount,
    );
  }

  // 헬퍼 메서드
  bool get isSold => status == '판매완료';
  bool get isAvailable => status == '판매중';
  
  // 대신팔기 수수료 계산
  int calculateResaleFee(double percentage) {
    return (price * percentage / 100).round();
  }
  
  // 대신판매자가 받을 금액
  int get resellerCommission => resaleFee;
  
  // 원 판매자가 받을 금액
  int get sellerAmount => price - resaleFee;
  
  // 첫번째 이미지 (썸네일용)
  String? get thumbnailImage => images.isNotEmpty ? images.first : null;
  
  // 가격 포맷팅 (천단위 콤마)
  String get formattedPrice => '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  String get formattedResaleFee => '${resaleFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  
  // 💳 계좌 관련 헬퍼 메서드들
  bool get hasCustomAccount => !useDefaultAccount && 
      transactionBankName != null && 
      transactionAccountNumber != null && 
      transactionAccountHolder != null;
      
  // 계좌 정보 표시 (상품별 또는 기본 계좌)
  String get accountDisplayType => useDefaultAccount ? '기본 계좌 사용' : '상품별 계좌 설정';
  
  // 거래용 계좌 정보 전체 표시
  String? get transactionAccountDisplay {
    if (!hasCustomAccount) return null;
    return '$transactionBankName $transactionAccountNumber ($transactionAccountHolder)';
  }
}

// 카테고리 enum
class ProductCategory {
  static const String clothing = '의류';
  static const String electronics = '전자기기';
  static const String household = '생활용품';
  static const String sports = '스포츠/레저';
  static const String books = '도서/문구';
  static const String beauty = '뷰티/미용';
  static const String food = '식품';
  static const String pet = '반려동물';
  static const String etc = '기타';
  
  static const List<String> all = [
    clothing,
    electronics,
    household,
    sports,
    books,
    beauty,
    food,
    pet,
    etc,
  ];

  static const Map<String, String> _aliasMap = {
    '전체': etc,
    'all': etc,
  };

  static String normalize(String? rawCategory) {
    if (rawCategory == null) return etc;

    final trimmed = rawCategory.trim();
    if (trimmed.isEmpty) return etc;
    if (all.contains(trimmed)) return trimmed;

    final lower = trimmed.toLowerCase();
    final alias = _aliasMap[trimmed] ?? _aliasMap[lower];
    if (alias != null) return alias;

    return etc;
  }

  static bool isValid(String category) => all.contains(category);
}

// 상품 상태 enum
class ProductStatus {
  static const String onSale = '판매중';
  static const String sold = '판매완료';

  static const List<String> all = [onSale, sold];
  static bool isValid(String status) => all.contains(status);
}
