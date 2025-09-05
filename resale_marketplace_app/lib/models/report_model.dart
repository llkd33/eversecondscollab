class ReportModel {
  final String id;
  final String reporterId;
  final String targetId;
  final String targetType; // user, product, transaction, chat
  final String reason;
  final String description;
  String status; // pending, reviewing, resolved, rejected
  final String priority; // low, medium, high, critical
  final List<String>? evidence; // 증거 파일 URL 목록
  final DateTime createdAt;
  DateTime updatedAt;
  String? reviewedBy;
  String? reviewNote;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.targetId,
    required this.targetType,
    required this.reason,
    required this.description,
    required this.status,
    required this.priority,
    this.evidence,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedBy,
    this.reviewNote,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'],
      reporterId: json['reporter_id'],
      targetId: json['target_id'],
      targetType: json['target_type'],
      reason: json['reason'],
      description: json['description'],
      status: json['status'],
      priority: json['priority'],
      evidence: json['evidence'] != null
          ? List<String>.from(json['evidence'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      reviewedBy: json['reviewed_by'],
      reviewNote: json['review_note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'target_id': targetId,
      'target_type': targetType,
      'reason': reason,
      'description': description,
      'status': status,
      'priority': priority,
      'evidence': evidence,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'reviewed_by': reviewedBy,
      'review_note': reviewNote,
    };
  }

  ReportModel copyWith({
    String? id,
    String? reporterId,
    String? targetId,
    String? targetType,
    String? reason,
    String? description,
    String? status,
    String? priority,
    List<String>? evidence,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reviewedBy,
    String? reviewNote,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      evidence: evidence ?? this.evidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}