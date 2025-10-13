import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/realtime_provider.dart';
import '../theme/app_theme.dart';

/// 실시간 알림 배지 위젯
class RealtimeNotificationBadge extends StatelessWidget {
  final Widget child;
  final bool showBadge;
  final Color? badgeColor;
  final Color? textColor;
  final double? size;

  const RealtimeNotificationBadge({
    super.key,
    required this.child,
    this.showBadge = true,
    this.badgeColor,
    this.textColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return child;

    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, _) {
        final totalCount = realtimeProvider.unreadNotificationCount + 
                          realtimeProvider.realTimeBadgeCount;
        
        if (totalCount == 0) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: BoxConstraints(
                  minWidth: size ?? 20,
                  minHeight: size ?? 20,
                ),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  borderRadius: BorderRadius.circular((size ?? 20) / 2),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    totalCount > 99 ? '99+' : totalCount.toString(),
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: (size ?? 20) > 20 ? 12 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 연결 상태 표시 위젯
class ConnectionStatusIndicator extends StatelessWidget {
  final Widget? child;
  final bool showWhenConnected;

  const ConnectionStatusIndicator({
    super.key,
    this.child,
    this.showWhenConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, _) {
        final isConnected = realtimeProvider.isConnected;
        
        // 연결되었을 때 표시하지 않는 옵션
        if (isConnected && !showWhenConnected) {
          return child ?? const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isConnected ? AppTheme.successColor : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isConnected ? '연결됨' : '연결 중...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (child != null) ...[
                const SizedBox(width: 8),
                child!,
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 실시간 상품 업데이트 알림
class ProductUpdateNotification extends StatelessWidget {
  final String productId;
  final Widget child;

  const ProductUpdateNotification({
    super.key,
    required this.productId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, _) {
        final product = realtimeProvider.getCachedProduct(productId);
        final isSubscribed = realtimeProvider.isSubscribedToProduct(productId);

        return Stack(
          children: [
            child,
            if (product != null && isSubscribed)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '업데이트됨',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 타이핑 인디케이터 위젯
class TypingIndicator extends StatefulWidget {
  final Set<String> typingUsers;
  final double size;

  const TypingIndicator({
    super.key,
    required this.typingUsers,
    this.size = 8,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    if (widget.typingUsers.isNotEmpty) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.typingUsers.isNotEmpty && oldWidget.typingUsers.isEmpty) {
      _animationController.repeat(reverse: true);
    } else if (widget.typingUsers.isEmpty && oldWidget.typingUsers.isNotEmpty) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++) ...[
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
                if (i < 2) SizedBox(width: widget.size / 2),
              ],
            ],
          ),
        );
      },
    );
  }
}