# 🚀 기능 개선 가이드

## 📸 이미지 압축 구현

### 현재 문제
- 원본 이미지 그대로 업로드 (5-10MB)
- 네트워크 데이터 낭비
- 로딩 속도 저하
- Supabase Storage 용량 부족

### Step 1: 이미지 압축 서비스 생성

```dart
// lib/services/image_compression_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class ImageCompressionService {
  final Logger _logger;

  ImageCompressionService({Logger? logger}) : _logger = logger ?? Logger();

  /// 이미지 압축
  ///
  /// [file] 원본 이미지 파일
  /// [quality] 압축 품질 (0-100, 기본값: 85)
  /// [maxWidth] 최대 너비 (기본값: 1920)
  /// [maxHeight] 최대 높이 (기본값: 1920)
  Future<File?> compressImage(
    File file, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    try {
      _logger.d('이미지 압축 시작: ${file.path}');

      // 원본 파일 크기
      final originalSize = await file.length();
      _logger.d('원본 크기: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // 임시 디렉토리
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      // 압축 실행
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        _logger.e('압축 실패');
        return null;
      }

      // 압축된 파일 크기
      final compressedSize = await compressedFile.length();
      final reduction = ((originalSize - compressedSize) / originalSize * 100);

      _logger.i(
        '압축 완료: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB '
        '(${reduction.toStringAsFixed(1)}% 감소)'
      );

      return File(compressedFile.path);
    } catch (e, stackTrace) {
      _logger.e('이미지 압축 실패', e, stackTrace);
      return null;
    }
  }

  /// 여러 이미지 압축
  Future<List<File>> compressMultipleImages(
    List<File> files, {
    int quality = 85,
  }) async {
    final compressedFiles = <File>[];

    for (final file in files) {
      final compressed = await compressImage(file, quality: quality);
      if (compressed != null) {
        compressedFiles.add(compressed);
      }
    }

    return compressedFiles;
  }

  /// 썸네일 생성
  Future<Uint8List?> generateThumbnail(
    File file, {
    int width = 400,
    int quality = 80,
  }) async {
    try {
      _logger.d('썸네일 생성: ${file.path}');

      final thumbnail = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: width,
        minHeight: width,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      _logger.i('썸네일 생성 완료: ${(thumbnail!.length / 1024).toStringAsFixed(2)}KB');
      return thumbnail;
    } catch (e, stackTrace) {
      _logger.e('썸네일 생성 실패', e, stackTrace);
      return null;
    }
  }
}
```

### Step 2: 상품 등록 시 이미지 압축 적용

```dart
// lib/providers/product_provider.dart
class ProductProvider with ChangeNotifier {
  final IProductService _productService;
  final ImageCompressionService _imageCompression;
  final Logger _logger;

  ProductProvider({
    required IProductService productService,
    ImageCompressionService? imageCompression,
    Logger? logger,
  })  : _productService = productService,
        _imageCompression = imageCompression ?? ImageCompressionService(),
        _logger = logger ?? Logger();

  Future<void> createProductWithImages(
    Product product,
    List<File> imageFiles,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _logger.d('이미지 압축 시작: ${imageFiles.length}개');

      // 1. 이미지 압축
      final compressedImages = await _imageCompression.compressMultipleImages(
        imageFiles,
        quality: 85,
      );

      if (compressedImages.isEmpty) {
        throw Exception('이미지 압축에 실패했습니다');
      }

      _logger.d('이미지 압축 완료: ${compressedImages.length}개');

      // 2. Supabase Storage에 업로드
      final uploadedUrls = <String>[];
      for (var i = 0; i < compressedImages.length; i++) {
        final file = compressedImages[i];
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final path = 'products/${product.sellerId}/$fileName';

        await Supabase.instance.client.storage
            .from('product-images')
            .upload(path, file);

        uploadedUrls.add(path);
        _logger.d('이미지 업로드 완료: $path');
      }

      // 3. 상품 정보에 이미지 URL 추가
      final productWithImages = product.copyWith(images: uploadedUrls);

      // 4. 상품 등록
      final result = await _productService.createProduct(productWithImages);

      result.when(
        success: (_) {
          _logger.i('상품 등록 성공');
          loadProducts();
        },
        failure: (error) {
          _logger.e('상품 등록 실패: $error');
          _error = error;
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e, stackTrace) {
      _logger.e('상품 등록 중 오류', e, stackTrace);
      _error = '상품 등록 중 오류가 발생했습니다';
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### Step 3: 이미지 선택 및 미리보기

```dart
// lib/screens/product/product_create_screen.dart
import 'package:image_picker/image_picker.dart';

class ProductCreateScreen extends StatefulWidget {
  const ProductCreateScreen({super.key});

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  final _imagePicker = ImagePicker();
  final List<File> _selectedImages = [];

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      setState(() {
        _selectedImages.clear();
        _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상품 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 선택 버튼
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image),
              label: const Text('이미지 선택 (최대 10장)'),
            ),
            const SizedBox(height: 16),

            // 이미지 미리보기
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // ... Form 필드들
          ],
        ),
      ),
    );
  }
}
```

## 📄 페이지네이션 구현

### Step 1: 페이지네이션 서비스

```dart
// lib/core/utils/pagination.dart
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const PaginationState({
    required this.items,
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error ?? this.error,
    );
  }
}
```

### Step 2: Provider에 페이지네이션 적용

```dart
// lib/providers/product_provider.dart
class ProductProvider with ChangeNotifier {
  final IProductService _productService;
  static const int _pageSize = 20;

  PaginationState<Product> _state = const PaginationState(items: []);

  PaginationState<Product> get state => _state;
  List<Product> get products => _state.items;
  bool get isLoading => _state.isLoading;
  bool get hasMore => _state.hasMore;

  ProductProvider({required IProductService productService})
      : _productService = productService;

  /// 첫 페이지 로드
  Future<void> loadFirstPage() async {
    _state = _state.copyWith(
      isLoading: true,
      error: null,
      items: [],
      currentPage: 0,
    );
    notifyListeners();

    await _loadPage(0);
  }

  /// 다음 페이지 로드
  Future<void> loadNextPage() async {
    if (_state.isLoading || !_state.hasMore) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    await _loadPage(_state.currentPage + 1);
  }

  Future<void> _loadPage(int page) async {
    try {
      final result = await _productService.getProducts(
        limit: _pageSize,
        offset: page * _pageSize,
      );

      result.when(
        success: (newProducts) {
          final allProducts = page == 0
              ? newProducts
              : [..._state.items, ...newProducts];

          _state = _state.copyWith(
            items: allProducts,
            isLoading: false,
            hasMore: newProducts.length == _pageSize,
            currentPage: page,
          );
          notifyListeners();
        },
        failure: (error) {
          _state = _state.copyWith(
            isLoading: false,
            error: error,
          );
          notifyListeners();
        },
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }
}
```

### Step 3: 무한 스크롤 UI

```dart
// lib/screens/product/product_list_screen.dart
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 첫 페이지 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadFirstPage();
    });

    // 스크롤 리스너 추가
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // 80% 스크롤 시 다음 페이지 로드
      context.read<ProductProvider>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상품 목록')),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final products = provider.products;

          if (products.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (products.isEmpty && provider.state.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.state.error!),
                  ElevatedButton(
                    onPressed: () => provider.loadFirstPage(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadFirstPage(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: products.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == products.length) {
                  // 로딩 인디케이터
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return ProductCard(product: products[index]);
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
```

## 💾 캐싱 전략 구현

### Step 1: 간단한 메모리 캐시

```dart
// lib/core/cache/memory_cache.dart
class MemoryCache<T> {
  final Map<String, _CacheEntry<T>> _cache = {};
  final Duration ttl;

  MemoryCache({this.ttl = const Duration(minutes: 5)});

  void set(String key, T value) {
    _cache[key] = _CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl),
    );
  }

  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.value;
  }

  void clear() {
    _cache.clear();
  }

  void remove(String key) {
    _cache.remove(key);
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiry;

  _CacheEntry({required this.value, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}
```

### Step 2: 서비스에 캐싱 적용

```dart
// lib/services/product_service.dart
class ProductService implements IProductService {
  final SupabaseClient _client;
  final MemoryCache<Product> _productCache;
  final MemoryCache<List<Product>> _listCache;

  ProductService({
    required SupabaseClient client,
    MemoryCache<Product>? productCache,
    MemoryCache<List<Product>>? listCache,
  })  : _client = client,
        _productCache = productCache ?? MemoryCache<Product>(),
        _listCache = listCache ?? MemoryCache<List<Product>>();

  @override
  Future<Result<Product>> getProduct(String productId) async {
    // 캐시 확인
    final cached = _productCache.get(productId);
    if (cached != null) {
      return Success(cached);
    }

    // 캐시 미스 - DB 조회
    try {
      final response = await _client
          .from('products')
          .select(/* ... */)
          .eq('id', productId)
          .single();

      final product = Product.fromJson(response);

      // 캐시 저장
      _productCache.set(productId, product);

      return Success(product);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  @override
  Future<Result<List<Product>>> getProducts({
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = 'products_${limit}_$offset';

    // 캐시 확인
    final cached = _listCache.get(cacheKey);
    if (cached != null) {
      return Success(cached);
    }

    // 캐시 미스 - DB 조회
    try {
      final response = await _client
          .from('products')
          .select(/* ... */)
          .range(offset, offset + limit - 1);

      final products = response.map((data) => Product.fromJson(data)).toList();

      // 캐시 저장
      _listCache.set(cacheKey, products);

      return Success(products);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  // 캐시 무효화
  void invalidateCache() {
    _productCache.clear();
    _listCache.clear();
  }
}
```

## 📋 체크리스트

### 이미지 최적화
- [ ] ImageCompressionService 생성
- [ ] 상품 등록 시 이미지 압축 적용
- [ ] 이미지 선택 UI 구현
- [ ] 썸네일 생성 기능 추가
- [ ] Supabase Storage 정책 설정

### 페이지네이션
- [ ] PaginationState 구현
- [ ] Provider에 페이지네이션 로직 추가
- [ ] 무한 스크롤 UI 구현
- [ ] Pull-to-refresh 기능 추가
- [ ] 로딩 상태 표시

### 캐싱
- [ ] MemoryCache 구현
- [ ] 서비스에 캐싱 로직 적용
- [ ] 캐시 무효화 전략 수립
- [ ] TTL 설정 최적화

## 🎯 예상 효과

### 이미지 최적화
- 데이터 사용량: **70-85% 감소**
- 로딩 속도: **3-5배 개선**
- Storage 비용: **70% 절감**

### 페이지네이션
- 초기 로딩 속도: **5-10배 빠름**
- 메모리 사용량: **60% 감소**
- 사용자 경험: 즉각적인 반응

### 캐싱
- API 호출 수: **50-70% 감소**
- 응답 속도: **즉시 반환**
- 서버 부하: **50% 감소**
