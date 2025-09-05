import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 공통 로딩 인디케이터
class CommonLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const CommonLoadingIndicator({
    super.key,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

/// 전체 화면 로딩
class FullScreenLoading extends StatelessWidget {
  final String? message;

  const FullScreenLoading({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CommonLoadingIndicator(size: 40),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 리스트 아이템 로딩 카드
class LoadingListItem extends StatelessWidget {
  const LoadingListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _ShimmerBox(
            width: 60,
            height: 60,
            borderRadius: BorderRadius.circular(8),
          ),
          title: const _ShimmerBox(
            height: 16,
            width: double.infinity,
          ),
          subtitle: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              _ShimmerBox(height: 12, width: 100),
              SizedBox(height: 4),
              _ShimmerBox(height: 12, width: 150),
            ],
          ),
        ),
      ),
    );
  }
}

/// 그리드 아이템 로딩 카드
class LoadingGridItem extends StatelessWidget {
  const LoadingGridItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
        ),
        child: const Center(
          child: CommonLoadingIndicator(),
        ),
      ),
    );
  }
}

/// Shimmer 효과 박스 (로딩 플레이스홀더)
class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const _ShimmerBox({
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[300]!.withOpacity(_animation.value),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}