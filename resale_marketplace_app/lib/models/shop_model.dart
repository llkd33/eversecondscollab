class ShopModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? shareUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? productIds; // 직접 등록한 상품 ID 리스트
  final List<String>? resaleProductIds; // 대신팔기 상품 ID 리스트

  ShopModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.shareUrl,
    required this.createdAt,
    required this.updatedAt,
    this.productIds,
    this.resaleProductIds,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('Shop ID cannot be empty');
    if (ownerId.isEmpty) throw ArgumentError('Owner ID cannot be empty');
    if (name.isEmpty) throw ArgumentError('Shop name cannot be empty');
    if (name.length > 50) throw ArgumentError('Shop name too long (max 50 characters)');
    if (description != null && description!.length > 500) {
      throw ArgumentError('Shop description too long (max 500 characters)');
    }
    if (shareUrl != null && shareUrl!.isEmpty) {
      throw ArgumentError('Share URL cannot be empty if provided');
    }
  }

  // JSON에서 Shop 객체 생성
  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      description: json['description'],
      shareUrl: json['share_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      productIds: json['product_ids'] != null 
          ? List<String>.from(json['product_ids'])
          : null,
      resaleProductIds: json['resale_product_ids'] != null
          ? List<String>.from(json['resale_product_ids'])
          : null,
    );
  }

  // Shop 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'share_url': shareUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (productIds != null) 'product_ids': productIds,
      if (resaleProductIds != null) 'resale_product_ids': resaleProductIds,
    };
  }

  // copyWith 메서드
  ShopModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? shareUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? productIds,
    List<String>? resaleProductIds,
  }) {
    return ShopModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      shareUrl: shareUrl ?? this.shareUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productIds: productIds ?? this.productIds,
      resaleProductIds: resaleProductIds ?? this.resaleProductIds,
    );
  }

  // 샵 URL 생성
  String get fullShareUrl => shareUrl != null ? 'https://everseconds.com/shop/$shareUrl' : '';
  
  // 상품 개수 계산
  int get totalProductCount => (productIds?.length ?? 0) + (resaleProductIds?.length ?? 0);
  int get ownProductCount => productIds?.length ?? 0;
  int get resaleCount => resaleProductIds?.length ?? 0;

  // 샵 URL 생성 헬퍼
  static String generateShareUrl(String shopId) {
    return shopId.substring(0, 8); // 샵 ID의 첫 8자리 사용
  }

  // 샵 이름 검증
  static bool isValidShopName(String name) {
    return name.isNotEmpty && name.length <= 50 && !name.contains(RegExp(r'[<>"/\\|?*]'));
  }
}