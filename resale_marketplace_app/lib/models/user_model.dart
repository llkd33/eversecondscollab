import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class UserModel {
  final String id;
  final String? email; // 전화번호 기반 로그인을 위해 nullable로 변경
  final String name;
  final String phone;
  final bool isVerified;
  final String? profileImage;
  final String role; // 일반, 대신판매자, 관리자
  final String? shopId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    this.email, // nullable로 변경
    required this.name,
    required this.phone,
    this.isVerified = false,
    this.profileImage,
    this.role = '일반',
    this.shopId,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _validate();
  }

  // 데이터 검증 로직
  void _validate() {
    if (id.isEmpty) throw ArgumentError('User ID cannot be empty');
    if (name.isEmpty) throw ArgumentError('Name cannot be empty');
    // 이메일이 있으면 검증, 없으면 전화번호 기반 로그인으로 간주
    if (email != null && email!.isNotEmpty && !_isValidEmail(email!)) {
      throw ArgumentError('Invalid email format');
    }
    if (!_isValidPhone(phone)) throw ArgumentError('Invalid phone format');
    if (!UserRole.isValid(role)) throw ArgumentError('Invalid user role');
  }

  // 이메일 형식 검증
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // 전화번호 형식 검증 (한국 전화번호)
  bool _isValidPhone(String phone) {
    // 소셜 로그인(카카오 등) 사용자는 전화번호가 비어있을 수 있으므로 허용
    if (phone.isEmpty) return true;
    return RegExp(r'^01[0-9]-?[0-9]{4}-?[0-9]{4}$').hasMatch(phone);
  }

  // JSON에서 User 객체 생성
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final resolvedName = _stringValue(json['name'])?.trim();
    final resolvedPhone = _stringValue(json['phone']);

    return UserModel(
      id: _stringValue(json['id']) ?? '',
      email: _stringValue(json['email']),
      name: (resolvedName == null || resolvedName.isEmpty)
          ? '사용자'
          : resolvedName,
      phone: resolvedPhone ?? '',
      isVerified: _boolValue(json['is_verified']) ?? false,
      profileImage: _stringValue(json['profile_image']),
      role: _stringValue(json['role']) ?? '일반',
      shopId: _stringValue(json['shop_id']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  static String? _stringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  // User 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email, // nullable 값 그대로 전달
      'name': name,
      'phone': phone,
      'is_verified': isVerified,
      'profile_image': profileImage,
      'role': role,
      'shop_id': shopId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Supabase Auth User에서 UserModel 생성 헬퍼
  static UserModel fromSupabaseUser(supabase.User user, Map<String, dynamic> metadata) {
    final rawName = metadata['name'];
    final resolvedName = rawName is String ? rawName.trim() : _stringValue(rawName) ?? '';
    final fallbackName = '사용자${user.id.replaceAll('-', '').substring(0, 8)}';
    final name = resolvedName.isEmpty ? fallbackName : resolvedName;
    final resolvedPhone = _stringValue(metadata['phone']) ?? '';
    final createdAt = _parseDate(metadata['created_at']);
    final updatedAt = _parseDate(metadata['updated_at']);

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      name: name,
      phone: resolvedPhone,
      isVerified: _boolValue(metadata['is_verified']) ?? false,
      profileImage: _stringValue(metadata['profile_image']),
      role: _stringValue(metadata['role']) ?? '일반',
      shopId: _stringValue(metadata['shop_id']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // copyWith 메서드
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    bool? isVerified,
    String? profileImage,
    String? role,
    String? shopId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isVerified: isVerified ?? this.isVerified,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 권한 체크 헬퍼 메서드
  bool get isAdmin => role == UserRole.admin;
  bool get isReseller => role == UserRole.reseller || role == UserRole.admin;
  bool get isGeneralUser => role == UserRole.general;

  // 전화번호 포맷팅 (010-1234-5678)
  String get formattedPhone {
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 7)}-${phone.substring(7)}';
    }
    return phone;
  }

  // 프로필 이미지 URL 또는 기본 이미지
  String get displayProfileImage {
    return profileImage ?? 'https://via.placeholder.com/150';
  }
}

// 사용자 역할 상수
class UserRole {
  static const String general = '일반';
  static const String reseller = '대신판매자';
  static const String admin = '관리자';

  static const List<String> all = [general, reseller, admin];

  static bool isValid(String role) => all.contains(role);
}
