class AppDownloadConfig {
  final String? id;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? universalLink;
  final String? qrImageUrl;
  final DateTime? updatedAt;

  const AppDownloadConfig({
    this.id,
    this.playStoreUrl,
    this.appStoreUrl,
    this.universalLink,
    this.qrImageUrl,
    this.updatedAt,
  });

  factory AppDownloadConfig.fromJson(Map<String, dynamic> json) {
    return AppDownloadConfig(
      id: json['id'] as String?,
      playStoreUrl: json['play_store_url'] as String?,
      appStoreUrl: json['app_store_url'] as String?,
      universalLink: json['universal_link'] as String?,
      qrImageUrl: json['qr_image_url'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeTimestamps = true}) {
    return {
      if (id != null) 'id': id,
      'play_store_url': playStoreUrl,
      'app_store_url': appStoreUrl,
      'universal_link': universalLink,
      'qr_image_url': qrImageUrl,
      if (includeTimestamps && updatedAt != null)
        'updated_at': updatedAt!.toIso8601String(),
    };
  }

  AppDownloadConfig copyWith({
    String? id,
    String? playStoreUrl,
    String? appStoreUrl,
    String? universalLink,
    String? qrImageUrl,
    DateTime? updatedAt,
  }) {
    return AppDownloadConfig(
      id: id ?? this.id,
      playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      appStoreUrl: appStoreUrl ?? this.appStoreUrl,
      universalLink: universalLink ?? this.universalLink,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static AppDownloadConfig defaults() {
    return const AppDownloadConfig(
      id: 'default',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.everseconds.resale_marketplace_app',
      appStoreUrl: 'https://apps.apple.com/app/everseconds/id1234567890',
      universalLink: 'https://www.everseconds.com/app',
    );
  }
}
