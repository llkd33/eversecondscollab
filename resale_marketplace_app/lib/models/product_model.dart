class ProductModel {
  final String id;
  final String title;
  final int price;
  final String? description;
  final List<String> images;
  final String category; // 의류, 전자기기, 생활용품 등
  final String sellerId;
  final bool resaleEnabled;
  final int resaleFee; // 수수료 금액
  final double? resaleFeePercentage; // 수수료 퍼센티지
  final String status; // 판매중, 판매완료
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 추가 정보 (조인해서 가져올 수 있는 정보)
  final String? sellerName;
  final String? sellerProfileImage;

  ProductModel({
    required this.id,
    required this.title,
    required this.price,
    this.description,
    required this.images,
    required this.category,
    required this.sellerId,
    this.resaleEnabled = false,
    this.resaleFee = 0,
    this.resaleFeePercentage,
    this.status = ProductStatus.onSale,
    required this.createdAt,
    required this.updatedAt,
    this.sellerName,
    this.sellerProfileImage,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('Product ID cannot be empty');
    if (title.isEmpty) throw ArgumentError('Product title cannot be empty');
    if (title.length > 100) throw ArgumentError('Product title too long (max 100 characters)');
    if (price <= 0) throw ArgumentError('Product price must be positive');
    if (price > 100000000) throw ArgumentError('Product price too high (max 100,000,000)');
    if (sellerId.isEmpty) throw ArgumentError('Seller ID cannot be empty');
    if (!ProductCategory.all.contains(category)) throw ArgumentError('Invalid product category');
    if (!ProductStatus.isValid(status)) throw ArgumentError('Invalid product status');
    if (resaleFee < 0) throw ArgumentError('Resale fee cannot be negative');
    if (resaleFeePercentage != null && (resaleFeePercentage! < 0 || resaleFeePercentage! > 100)) {
      throw ArgumentError('Resale fee percentage must be between 0 and 100');
    }
    if (description != null && description!.length > 1000) {
      throw ArgumentError('Product description too long (max 1000 characters)');
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
      category: json['category'],
      sellerId: json['seller_id'],
      resaleEnabled: json['resale_enabled'] ?? false,
      resaleFee: json['resale_fee'] ?? 0,
      resaleFeePercentage: json['resale_fee_percentage']?.toDouble(),
      status: json['status'] ?? '판매중',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      sellerName: userInfo?['name'] ?? json['seller_name'],
      sellerProfileImage: userInfo?['profile_image'] ?? json['seller_profile_image'],
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
      'resale_enabled': resaleEnabled,
      'resale_fee': resaleFee,
      'resale_fee_percentage': resaleFeePercentage,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (sellerName != null) 'seller_name': sellerName,
      if (sellerProfileImage != null) 'seller_profile_image': sellerProfileImage,
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
    bool? resaleEnabled,
    int? resaleFee,
    double? resaleFeePercentage,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sellerName,
    String? sellerProfileImage,
  }) {
    return ProductModel(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      description: description ?? this.description,
      images: images ?? this.images,
      category: category ?? this.category,
      sellerId: sellerId ?? this.sellerId,
      resaleEnabled: resaleEnabled ?? this.resaleEnabled,
      resaleFee: resaleFee ?? this.resaleFee,
      resaleFeePercentage: resaleFeePercentage ?? this.resaleFeePercentage,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sellerName: sellerName ?? this.sellerName,
      sellerProfileImage: sellerProfileImage ?? this.sellerProfileImage,
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
}

// 상품 상태 enum
class ProductStatus {
  static const String onSale = '판매중';
  static const String sold = '판매완료';

  static const List<String> all = [onSale, sold];
  static bool isValid(String status) => all.contains(status);
}