import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';

/// 오프라인 상태 배너
class OfflineBanner extends StatelessWidget {
  final Widget child;
  final bool showBanner;

  const OfflineBanner({
    super.key,
    required this.child,
    this.showBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBanner) return child;

    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (!connectivity.isInitialized) {
          return child; // 초기화 전에는 배너 표시하지 않음
        }

        return Column(
          children: [
            // 오프라인 배너
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: connectivity.isConnected ? 0 : 50,
              child: connectivity.isConnected
                  ? const SizedBox.shrink()
                  : Container(
                      width: double.infinity,
                      color: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '인터넷 연결이 끊어졌습니다',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => connectivity.checkConnection(),
                            child: const Text(
                              '다시 시도',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            
            // 연결 복구 배너
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _shouldShowRestoreBanner(connectivity) ? 40 : 0,
              child: _shouldShowRestoreBanner(connectivity)
                  ? Container(
                      width: double.infinity,
                      color: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${connectivity.connectionIcon} ${connectivity.connectionType}에 연결됨',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            
            // 실제 컨텐츠
            Expanded(child: child),
          ],
        );
      },
    );
  }

  bool _shouldShowRestoreBanner(ConnectivityProvider connectivity) {
    // 연결이 복구된 직후 잠시 표시하는 로직은 별도 구현 필요
    // 여기서는 단순히 false 반환
    return false;
  }
}

/// 연결 상태 인디케이터 위젯
class ConnectionStatusIndicator extends StatelessWidget {
  final bool showLabel;
  final double size;

  const ConnectionStatusIndicator({
    super.key,
    this.showLabel = true,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (!connectivity.isInitialized) {
          return const SizedBox.shrink();
        }

        final color = connectivity.isConnected
            ? (connectivity.isSlowConnection ? Colors.orange : Colors.green)
            : Colors.red;

        final icon = connectivity.isConnected
            ? (connectivity.isWiFiConnected 
                ? Icons.wifi 
                : Icons.signal_cellular_alt)
            : Icons.wifi_off;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: size,
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                connectivity.connectionType,
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.75,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 오프라인 상태 다이얼로그
class OfflineDialog extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const OfflineDialog({
    super.key,
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.red),
          SizedBox(width: 8),
          Text('인터넷 연결 없음'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이 기능을 사용하려면 인터넷 연결이 필요합니다.'),
          SizedBox(height: 12),
          Text(
            '• WiFi 또는 모바일 데이터 연결을 확인하세요\n'
            '• 네트워크 설정을 확인하세요\n'
            '• 잠시 후 다시 시도하세요',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: const Text('취소'),
          ),
        ElevatedButton(
          onPressed: onRetry ?? () => Navigator.of(context).pop(),
          child: const Text('다시 시도'),
        ),
      ],
    );
  }
}

/// 네트워크 의존 작업을 위한 래퍼 위젯
class NetworkDependentWidget extends StatelessWidget {
  final Widget child;
  final Widget? offlineWidget;
  final String? offlineMessage;

  const NetworkDependentWidget({
    super.key,
    required this.child,
    this.offlineWidget,
    this.offlineMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (!connectivity.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!connectivity.isConnected) {
          return offlineWidget ?? 
            _buildDefaultOfflineWidget(context, offlineMessage);
        }

        return child;
      },
    );
  }

  Widget _buildDefaultOfflineWidget(BuildContext context, String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? '인터넷 연결이 필요합니다',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '네트워크 연결을 확인하고 다시 시도하세요',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ConnectivityService().checkConnection();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}