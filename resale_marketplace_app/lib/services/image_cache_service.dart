import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

/// 이미지 캐싱 서비스
/// 메모리 캐시, 디스크 캐시, 썸네일 생성 등을 관리
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // 캐시 매니저 인스턴스
  late final DefaultCacheManager _cacheManager;
  late final DefaultCacheManager _thumbnailCacheManager;

  // Dio 인스턴스 (병렬 다운로드용)
  final Dio _dio = Dio();

  // 메모리 캐시
  final Map<String, Uint8List> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50 * 1024 * 1024; // 50MB
  int _currentMemoryCacheSize = 0;

  // 프리로드 큐
  final Set<String> _preloadQueue = {};
  Timer? _preloadTimer;

  /// 초기화
  Future<void> initialize() async {
    // 캐시 매니저 설정
    _cacheManager = DefaultCacheManager();

    // 썸네일 전용 캐시 매니저
    _thumbnailCacheManager = CacheManager(
      Config(
        'thumbnailCache',
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 500,
      ),
    );

    // Dio 설정
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    );

    // 메모리 캐시 정리 스케줄러
    Timer.periodic(const Duration(minutes: 5), (_) => _cleanupMemoryCache());
  }

  /// 이미지 캐시 위젯 생성
  Widget getCachedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    bool enableMemoryCache = true,
    bool generateThumbnail = false,
  }) {
    // 메모리 캐시 확인
    if (enableMemoryCache && _memoryCache.containsKey(imageUrl)) {
      return Image.memory(
        _memoryCache[imageUrl]!,
        width: width,
        height: height,
        fit: fit,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: generateThumbnail ? _thumbnailCacheManager : _cacheManager,
      placeholder: placeholder != null
          ? (context, url) => placeholder
          : (context, url) => _buildDefaultPlaceholder(width, height),
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget
          : (context, url, error) => _buildDefaultErrorWidget(width, height),
      imageBuilder: enableMemoryCache
          ? (context, imageProvider) {
              // 메모리 캐시에 저장
              _cacheToMemory(imageUrl, imageProvider);
              return Image(
                image: imageProvider,
                width: width,
                height: height,
                fit: fit,
              );
            }
          : null,
    );
  }

  /// 썸네일 생성 및 캐싱
  Future<String?> generateThumbnail({
    required String originalUrl,
    int maxWidth = 200,
    int maxHeight = 200,
    int quality = 85,
  }) async {
    final thumbnailKey = '${originalUrl}_${maxWidth}x$maxHeight';

    try {
      // 썸네일 캐시 확인
      final cachedFile = await _thumbnailCacheManager.getFileFromCache(
        thumbnailKey,
      );
      if (cachedFile != null) {
        return cachedFile.file.path;
      }

      // 원본 이미지 다운로드
      final originalFile = await _cacheManager.downloadFile(originalUrl);

      // 썸네일 생성
      final originalBytes = await originalFile.file.readAsBytes();
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) return null;

      // 리사이징
      final thumbnail = img.copyResize(
        originalImage,
        width: originalImage.width > originalImage.height ? maxWidth : null,
        height: originalImage.height > originalImage.width ? maxHeight : null,
      );

      // JPEG로 압축
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: quality);

      // 캐시에 저장
      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      await _thumbnailCacheManager.putFile(
        thumbnailKey,
        thumbnailFile.readAsBytesSync(),
      );

      return thumbnailFile.path;
    } catch (e) {
      debugPrint('썸네일 생성 실패: $e');
      return null;
    }
  }

  /// 이미지 프리로드 (화면 진입 전 미리 캐싱)
  Future<void> preloadImages(List<String> imageUrls) async {
    // 프리로드 큐에 추가
    _preloadQueue.addAll(imageUrls);

    // 타이머가 없으면 시작
    _preloadTimer ??= Timer(
      const Duration(milliseconds: 100),
      _processPreloadQueue,
    );
  }

  /// 프리로드 큐 처리
  Future<void> _processPreloadQueue() async {
    if (_preloadQueue.isEmpty) {
      _preloadTimer = null;
      return;
    }

    // 병렬로 최대 3개씩 처리
    final batch = _preloadQueue.take(3).toList();
    _preloadQueue.removeAll(batch);

    await Future.wait(
      batch.map((url) => _preloadSingleImage(url)),
      eagerError: false,
    );

    // 다음 배치 처리
    if (_preloadQueue.isNotEmpty) {
      _preloadTimer = Timer(
        const Duration(milliseconds: 50),
        _processPreloadQueue,
      );
    } else {
      _preloadTimer = null;
    }
  }

  /// 단일 이미지 프리로드
  Future<void> _preloadSingleImage(String url) async {
    try {
      // 이미 캐시되어 있는지 확인
      final cachedFile = await _cacheManager.getFileFromCache(url);
      if (cachedFile != null) return;

      // 다운로드 및 캐싱
      await _cacheManager.downloadFile(url);
    } catch (e) {
      debugPrint('이미지 프리로드 실패: $url, $e');
    }
  }

  /// 메모리 캐시에 저장
  Future<void> _cacheToMemory(String url, ImageProvider imageProvider) async {
    try {
      // 이미지 바이트 가져오기
      final bytes = await _getImageBytes(imageProvider);
      if (bytes == null) return;

      // 메모리 캐시 크기 확인
      if (_currentMemoryCacheSize + bytes.length > _maxMemoryCacheSize) {
        _cleanupMemoryCache();
      }

      // 캐시에 추가
      _memoryCache[url] = bytes;
      _currentMemoryCacheSize += bytes.length;
    } catch (e) {
      debugPrint('메모리 캐싱 실패: $e');
    }
  }

  /// ImageProvider에서 바이트 추출
  Future<Uint8List?> _getImageBytes(ImageProvider imageProvider) async {
    try {
      if (imageProvider is NetworkImage) {
        final response = await _dio.get(
          imageProvider.url,
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 메모리 캐시 정리
  void _cleanupMemoryCache() {
    if (_memoryCache.isEmpty) return;

    // LRU 방식으로 오래된 항목 제거
    final entriesToRemove = _memoryCache.length ~/ 3;
    final keysToRemove = _memoryCache.keys.take(entriesToRemove).toList();

    for (final key in keysToRemove) {
      final bytes = _memoryCache.remove(key);
      if (bytes != null) {
        _currentMemoryCacheSize -= bytes.length;
      }
    }
  }

  /// 캐시 클리어
  Future<void> clearCache({
    bool memory = true,
    bool disk = true,
    bool thumbnails = true,
  }) async {
    if (memory) {
      _memoryCache.clear();
      _currentMemoryCacheSize = 0;
    }

    if (disk) {
      await _cacheManager.emptyCache();
    }

    if (thumbnails) {
      await _thumbnailCacheManager.emptyCache();
    }
  }

  /// 캐시 통계 가져오기
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCache': {
        'count': _memoryCache.length,
        'size': _currentMemoryCacheSize,
        'sizeInMB': (_currentMemoryCacheSize / 1024 / 1024).toStringAsFixed(2),
      },
      'preloadQueue': _preloadQueue.length,
    };
  }

  /// 특정 이미지 캐시 제거
  Future<void> removeFromCache(String url) async {
    // 메모리 캐시에서 제거
    final bytes = _memoryCache.remove(url);
    if (bytes != null) {
      _currentMemoryCacheSize -= bytes.length;
    }

    // 디스크 캐시에서 제거
    await _cacheManager.removeFile(url);
  }

  /// 기본 플레이스홀더 위젯
  Widget _buildDefaultPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  /// 기본 에러 위젯
  Widget _buildDefaultErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
          const SizedBox(height: 4),
          Text(
            '이미지 로드 실패',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 이미지 최적화 (압축)
  Future<Uint8List?> optimizeImage({
    required Uint8List bytes,
    int maxWidth = 1080,
    int quality = 85,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // 크기 조정이 필요한 경우
      if (image.width > maxWidth) {
        final resized = img.copyResize(image, width: maxWidth);
        return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }

      // 품질만 조정
      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    } catch (e) {
      debugPrint('이미지 최적화 실패: $e');
      return null;
    }
  }

  /// 디바이스별 최적 이미지 크기 계산
  static Size getOptimalImageSize(
    BuildContext context, {
    double? maxWidth,
    double? maxHeight,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    final optimalWidth = (maxWidth ?? screenWidth) * devicePixelRatio;
    final optimalHeight = (maxHeight ?? screenHeight) * devicePixelRatio;

    return Size(optimalWidth, optimalHeight);
  }
}
