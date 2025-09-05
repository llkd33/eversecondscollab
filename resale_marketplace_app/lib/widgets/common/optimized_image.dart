import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';

/// 최적화된 네트워크 이미지 위젯
/// 캐싱, 메모리 최적화, 로딩/에러 처리 포함
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // 메모리 캐시 크기 자동 계산
    final int? cacheWidth = memCacheWidth ?? (width != null ? (width! * 2).toInt() : null);
    final int? cacheHeight = memCacheHeight ?? (height != null ? (height! * 2).toInt() : null);

    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      placeholder: (context, url) => placeholder ?? const _DefaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? const _DefaultErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// 썸네일용 최적화 이미지
class OptimizedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double size;
  final BorderRadius? borderRadius;

  const OptimizedThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 80,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );
  }
}

/// 기본 플레이스홀더 위젯
class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      ),
    );
  }
}

/// 기본 에러 위젯
class _DefaultErrorWidget extends StatelessWidget {
  const _DefaultErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}

/// 상품 카드용 최적화 이미지
class ProductImageOptimized extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;

  const ProductImageOptimized({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      memCacheWidth: 400,
      memCacheHeight: 400,
      borderRadius: BorderRadius.circular(8),
    );
  }
}