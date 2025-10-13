import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/app_download_config.dart';
import '../services/app_settings_service.dart';

class TabletAppDownloadWidget extends StatelessWidget {
  final AppDownloadConfig config;
  final VoidCallback? onWebPurchase;

  const TabletAppDownloadWidget({
    super.key,
    required this.config,
    this.onWebPurchase,
  });

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return width >= 600 || shortestSide >= 600;
  }

  static bool isWebBrowser() => kIsWeb;

  @override
  Widget build(BuildContext context) {
    final defaults = AppDownloadConfig.defaults();
    final effectiveLink = config.universalLink?.isNotEmpty == true
        ? config.universalLink!
        : defaults.universalLink!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone_android,
                size: 30,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '모바일 앱에서 구매하세요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '더 나은 거래 경험을 위해\n모바일 앱을 이용해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildQrArea(effectiveLink),
            const SizedBox(height: 16),
            Text(
              'QR 코드를 스캔하여 앱을 다운로드하세요',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildStoreButtons(context),
            if (onWebPurchase != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onWebPurchase?.call();
                },
                child: Text(
                  '웹에서 계속하기',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrArea(String effectiveLink) {
    if (config.qrImageUrl != null && config.qrImageUrl!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            config.qrImageUrl!,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildGeneratedQr(effectiveLink);
            },
          ),
        ),
      );
    }

    return _buildGeneratedQr(effectiveLink);
  }

  Widget _buildGeneratedQr(String link) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: QrImageView(
        data: link,
        version: QrVersions.auto,
        size: 200,
        backgroundColor: Colors.white,
        errorStateBuilder: (context, error) {
          return const SizedBox(
            width: 180,
            height: 180,
            child: Center(child: Text('QR 코드 생성 오류')),
          );
        },
      ),
    );
  }

  Widget _buildStoreButtons(BuildContext context) {
    final entries = <_StoreEntry>[];

    if (config.playStoreUrl != null && config.playStoreUrl!.isNotEmpty) {
      entries.add(
        _StoreEntry(
          icon: Icons.android,
          label: 'Google Play',
          color: Colors.green,
          url: config.playStoreUrl!,
        ),
      );
    }

    if (config.appStoreUrl != null && config.appStoreUrl!.isNotEmpty) {
      entries.add(
        _StoreEntry(
          icon: Icons.apple,
          label: 'App Store',
          color: Colors.black,
          url: config.appStoreUrl!,
        ),
      );
    }

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: entries
          .map(
            (entry) => OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: entry.url));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${entry.label} 링크가 클립보드에 복사되었습니다')),
                );
              },
              icon: Icon(entry.icon, size: 18, color: entry.color),
              label: Text(
                entry.label,
                style: TextStyle(color: entry.color, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: entry.color.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          )
          .toList(),
    );
  }
}

class TabletPurchaseHelper {
  static final AppSettingsService _settingsService = AppSettingsService();

  static Future<void> handlePurchase(
    BuildContext context,
    FutureOr<void> Function() originalPurchaseAction,
  ) async {
    if (kIsWeb && TabletAppDownloadWidget.isTablet(context)) {
      final config = await _settingsService.fetchAppDownloadConfig();
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => TabletAppDownloadWidget(config: config),
      );
      return;
    }

    await Future.sync(originalPurchaseAction);
  }
}

class _StoreEntry {
  final IconData icon;
  final String label;
  final Color color;
  final String url;

  _StoreEntry({
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
  });
}
