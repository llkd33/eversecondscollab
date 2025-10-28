# 🎯 코드 품질 개선 가이드

## 📋 현재 품질 문제

### 1. 입력 검증 부재
- 사용자 입력 값 검증 없음
- SQL Injection, XSS 공격 취약
- 비즈니스 로직 검증 부족

### 2. 에러 처리 불일치
- try-catch 패턴 불일치
- 에러 메시지 사용자 친화적이지 않음
- 에러 로깅 부재

### 3. 중복 코드
- 날짜 포맷팅 코드 중복
- 가격 포맷팅 코드 중복
- 이미지 URL 처리 중복

## 🔒 입력 검증 가이드

### Step 1: Validation 유틸리티 생성

```dart
// lib/core/utils/validators.dart
class Validators {
  // 이메일 검증
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 형식이 아닙니다';
    }

    return null;
  }

  // 비밀번호 검증
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }

    if (value.length < 8) {
      return '비밀번호는 최소 8자 이상이어야 합니다';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return '대문자를 포함해야 합니다';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return '숫자를 포함해야 합니다';
    }

    return null;
  }

  // 상품명 검증
  static String? productTitle(String? value) {
    if (value == null || value.isEmpty) {
      return '상품명을 입력해주세요';
    }

    if (value.length < 2) {
      return '상품명은 최소 2자 이상이어야 합니다';
    }

    if (value.length > 100) {
      return '상품명은 최대 100자까지 입력 가능합니다';
    }

    // XSS 방지: HTML 태그 감지
    if (value.contains(RegExp(r'<[^>]*>'))) {
      return '특수 문자를 포함할 수 없습니다';
    }

    return null;
  }

  // 가격 검증
  static String? price(String? value) {
    if (value == null || value.isEmpty) {
      return '가격을 입력해주세요';
    }

    final price = int.tryParse(value.replaceAll(',', ''));
    if (price == null) {
      return '올바른 숫자를 입력해주세요';
    }

    if (price < 0) {
      return '가격은 0원 이상이어야 합니다';
    }

    if (price > 1000000000) {
      return '가격은 10억원 이하여야 합니다';
    }

    return null;
  }

  // 전화번호 검증
  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return '전화번호를 입력해주세요';
    }

    final phoneRegex = RegExp(r'^01[016789]-?\d{3,4}-?\d{4}$');
    if (!phoneRegex.hasMatch(value)) {
      return '올바른 전화번호 형식이 아닙니다';
    }

    return null;
  }

  // 상품 설명 검증
  static String? productDescription(String? value) {
    if (value == null || value.isEmpty) {
      return '상품 설명을 입력해주세요';
    }

    if (value.length < 10) {
      return '상품 설명은 최소 10자 이상이어야 합니다';
    }

    if (value.length > 5000) {
      return '상품 설명은 최대 5000자까지 입력 가능합니다';
    }

    return null;
  }

  // URL 검증
  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL은 선택적
    }

    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return '올바른 URL 형식이 아닙니다';
      }
      return null;
    } catch (e) {
      return '올바른 URL 형식이 아닙니다';
    }
  }

  // 은행 계좌번호 검증
  static String? accountNumber(String? value) {
    if (value == null || value.isEmpty) {
      return '계좌번호를 입력해주세요';
    }

    // 숫자와 하이픈만 허용
    final accountRegex = RegExp(r'^[\d-]+$');
    if (!accountRegex.hasMatch(value)) {
      return '숫자와 하이픈만 입력 가능합니다';
    }

    final digitsOnly = value.replaceAll('-', '');
    if (digitsOnly.length < 10 || digitsOnly.length > 14) {
      return '계좌번호는 10~14자리여야 합니다';
    }

    return null;
  }
}
```

### Step 2: Form 위젯에서 사용

```dart
// lib/screens/product/product_create_screen.dart
class ProductCreateScreen extends StatefulWidget {
  const ProductCreateScreen({super.key});

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상품 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '상품명',
                hintText: '상품명을 입력하세요',
              ),
              validator: Validators.productTitle,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: '가격',
                hintText: '가격을 입력하세요',
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
              validator: Validators.price,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '상품 설명',
                hintText: '상품 설명을 입력하세요',
              ),
              maxLines: 5,
              validator: Validators.productDescription,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitForm,
              child: const Text('등록하기'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // 검증 성공 시 처리
      final product = Product(
        title: _titleController.text,
        price: int.parse(_priceController.text.replaceAll(',', '')),
        description: _descriptionController.text,
      );

      // 상품 등록 로직
      context.read<ProductProvider>().createProduct(product);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
```

### Step 3: 서버 측 검증 (Supabase RPC)

```sql
-- Supabase SQL Editor에서 실행
CREATE OR REPLACE FUNCTION create_product(
  p_title TEXT,
  p_price INTEGER,
  p_description TEXT,
  p_seller_id UUID
)
RETURNS UUID AS $$
DECLARE
  product_id UUID;
BEGIN
  -- 입력 검증
  IF LENGTH(p_title) < 2 OR LENGTH(p_title) > 100 THEN
    RAISE EXCEPTION '상품명은 2~100자여야 합니다';
  END IF;

  IF p_price < 0 OR p_price > 1000000000 THEN
    RAISE EXCEPTION '가격은 0~1,000,000,000원 사이여야 합니다';
  END IF;

  IF LENGTH(p_description) < 10 OR LENGTH(p_description) > 5000 THEN
    RAISE EXCEPTION '상품 설명은 10~5000자여야 합니다';
  END IF;

  -- 상품 생성
  INSERT INTO products (title, price, description, seller_id)
  VALUES (p_title, p_price, p_description, p_seller_id)
  RETURNING id INTO product_id;

  RETURN product_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 🚨 에러 처리 가이드

### Step 1: Result 패턴 구현

```dart
// lib/core/utils/result.dart
abstract class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get data => isSuccess ? (this as Success<T>).data : null;
  String? get error => isFailure ? (this as Failure<T>).error : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(String error) failure,
  }) {
    if (isSuccess) {
      return success((this as Success<T>).data);
    } else {
      return failure((this as Failure<T>).error);
    }
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String error;
  const Failure(this.error);
}
```

### Step 2: 서비스에서 Result 사용

```dart
// lib/services/product_service.dart
class ProductService implements IProductService {
  final SupabaseClient _client;
  final Logger _logger;

  ProductService({
    required SupabaseClient client,
    Logger? logger,
  })  : _client = client,
        _logger = logger ?? Logger();

  @override
  Future<Result<Product>> getProduct(String productId) async {
    try {
      _logger.d('상품 조회 시작: $productId');

      final response = await _client
          .from('products')
          .select('''
            *,
            seller:users!seller_id(id, name, profile_image_url, rating)
          ''')
          .eq('id', productId)
          .single();

      final product = Product.fromJson(response);

      _logger.i('상품 조회 성공: ${product.title}');
      return Success(product);
    } on PostgrestException catch (e) {
      _logger.e('PostgreSQL 에러', e);

      if (e.code == 'PGRST116') {
        return const Failure('상품을 찾을 수 없습니다');
      }

      return Failure('데이터베이스 오류: ${e.message}');
    } catch (e, stackTrace) {
      _logger.e('상품 조회 실패', e, stackTrace);
      return const Failure('상품을 불러오는 중 오류가 발생했습니다');
    }
  }

  @override
  Future<Result<void>> createProduct(Product product) async {
    try {
      _logger.d('상품 생성 시작: ${product.title}');

      await _client.rpc('create_product', params: {
        'p_title': product.title,
        'p_price': product.price,
        'p_description': product.description,
        'p_seller_id': product.sellerId,
      });

      _logger.i('상품 생성 성공: ${product.title}');
      return const Success(null);
    } on PostgrestException catch (e) {
      _logger.e('PostgreSQL 에러', e);
      return Failure(e.message);
    } catch (e, stackTrace) {
      _logger.e('상품 생성 실패', e, stackTrace);
      return const Failure('상품 등록 중 오류가 발생했습니다');
    }
  }
}
```

### Step 3: Provider에서 에러 처리

```dart
// lib/providers/product_provider.dart
class ProductProvider with ChangeNotifier {
  final IProductService _productService;
  final Logger _logger;

  ProductProvider({
    required IProductService productService,
    Logger? logger,
  })  : _productService = productService,
        _logger = logger ?? Logger();

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> createProduct(Product product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _productService.createProduct(product);

    result.when(
      success: (_) {
        _logger.i('상품 등록 성공');
        // 목록 새로고침
        loadProducts();
      },
      failure: (error) {
        _logger.e('상품 등록 실패: $error');
        _error = error;
        _isLoading = false;
        notifyListeners();
      },
    );
  }
}
```

### Step 4: UI에서 에러 표시

```dart
// lib/screens/product/product_list_screen.dart
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상품 목록')),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          // 로딩 중
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 에러 발생
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      provider.loadProducts();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          // 데이터 표시
          return ListView.builder(
            itemCount: provider.products.length,
            itemBuilder: (context, index) {
              final product = provider.products[index];
              return ProductCard(product: product);
            },
          );
        },
      ),
    );
  }
}
```

## 🧹 중복 코드 제거

### Step 1: 포맷팅 유틸리티 생성

```dart
// lib/core/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  // 가격 포맷팅
  static String price(int price) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(price)}원';
  }

  // 날짜 포맷팅
  static String date(DateTime date, {String format = 'yyyy.MM.dd'}) {
    return DateFormat(format).format(date);
  }

  // 상대 시간 (2시간 전, 3일 전 등)
  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}년 전';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}개월 전';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  // 전화번호 포맷팅
  static String phoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 11) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 10) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }
    return phone;
  }
}
```

### Step 2: 이미지 유틸리티 생성

```dart
// lib/core/utils/image_utils.dart
class ImageUtils {
  // Supabase Storage URL 생성
  static String getStorageUrl(String path) {
    final supabaseUrl = SupabaseConfig.supabaseUrl;
    return '$supabaseUrl/storage/v1/object/public/$path';
  }

  // 썸네일 URL 생성
  static String getThumbnailUrl(String path, {int width = 400}) {
    final url = getStorageUrl(path);
    return '$url?width=$width&quality=80';
  }

  // 기본 이미지 URL
  static String get defaultProductImage =>
      'https://via.placeholder.com/400x400?text=No+Image';

  static String get defaultProfileImage =>
      'https://via.placeholder.com/100x100?text=User';
}
```

### Step 3: 사용 예시

```dart
// Before: 중복 코드
class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    // ❌ 중복: 가격 포맷팅
    final formattedPrice = NumberFormat('#,###').format(product.price);

    // ❌ 중복: 날짜 포맷팅
    final createdAt = DateFormat('yyyy.MM.dd').format(product.createdAt);

    // ❌ 중복: 이미지 URL 처리
    final imageUrl = product.images.isNotEmpty
        ? '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${product.images[0]}'
        : 'https://via.placeholder.com/400';

    return Card(/* ... */);
  }
}

// After: 유틸리티 사용
class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    // ✅ 유틸리티 사용
    final formattedPrice = Formatters.price(product.price);
    final createdAt = Formatters.relativeTime(product.createdAt);
    final imageUrl = product.images.isNotEmpty
        ? ImageUtils.getThumbnailUrl(product.images[0])
        : ImageUtils.defaultProductImage;

    return Card(/* ... */);
  }
}
```

## 📋 체크리스트

### 입력 검증
- [ ] Validators 클래스 생성
- [ ] 모든 Form에 검증 로직 적용
- [ ] Supabase RPC 함수에 서버 측 검증 추가
- [ ] XSS, SQL Injection 방어 확인

### 에러 처리
- [ ] Result 패턴 구현
- [ ] 모든 서비스에 Result 패턴 적용
- [ ] Provider에서 에러 처리 통일
- [ ] UI에서 사용자 친화적 에러 메시지 표시
- [ ] 로깅 시스템 적용

### 코드 품질
- [ ] Formatters 유틸리티 생성 및 적용
- [ ] ImageUtils 유틸리티 생성 및 적용
- [ ] 중복 코드 제거
- [ ] 매직 넘버를 상수로 정의

## 🎯 예상 효과

- **보안성**: XSS, SQL Injection 공격 방어
- **사용성**: 명확한 에러 메시지로 사용자 경험 개선
- **유지보수성**: 중복 코드 제거로 수정 용이
- **일관성**: 통일된 에러 처리 및 포맷팅
