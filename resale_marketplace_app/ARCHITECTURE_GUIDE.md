# 🏗️ 아키텍처 개선 가이드

## 📋 현재 아키텍처 문제점

### 1. 서비스 간 강한 결합
```dart
// ❌ 문제: ChatService가 ProductService를 직접 생성
class ChatService {
  final _productService = ProductService(); // 강한 결합!

  Future<Chat> getChat(String chatId) async {
    final product = await _productService.getProduct(productId);
    // ...
  }
}
```

**문제점**:
- 테스트하기 어려움 (mock 객체 주입 불가)
- 의존성 변경 시 모든 코드 수정 필요
- 순환 참조 위험
- 코드 재사용성 낮음

### 2. Provider 직접 참조
```dart
// ❌ 문제: UI에서 서비스 직접 생성
class MyShopScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shopService = ShopService(); // 매번 새 인스턴스!
    // ...
  }
}
```

## 🎯 목표 아키텍처

### Clean Architecture + Provider Pattern
```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  (Screens, Widgets, Providers)          │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│         Domain Layer                    │
│  (Entities, Use Cases, Interfaces)      │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│         Data Layer                      │
│  (Services, Repositories, Models)       │
└─────────────────────────────────────────┘
```

## 🔧 구현 가이드

### Step 1: 의존성 주입 패턴 적용

#### 1-1. 서비스 인터페이스 정의
```dart
// lib/domain/interfaces/i_product_service.dart
abstract class IProductService {
  Future<Product?> getProduct(String productId);
  Future<List<Product>> getProducts({int limit, int offset});
  Future<void> createProduct(Product product);
  Future<void> updateProduct(String id, Product product);
  Future<void> deleteProduct(String id);
}

// lib/domain/interfaces/i_chat_service.dart
abstract class IChatService {
  Future<List<Chat>> getUserChats(String userId);
  Future<Chat?> getChat(String chatId);
  Future<void> sendMessage(String chatId, Message message);
  Future<int> getUnreadCount(String chatId, String userId);
}

// lib/domain/interfaces/i_shop_service.dart
abstract class IShopService {
  Future<Shop?> getShop(String shopId);
  Future<List<Product>> getShopProducts(String shopId);
  Future<void> updateShop(String shopId, Shop shop);
}
```

#### 1-2. 서비스 구현체 수정
```dart
// lib/services/chat_service.dart
import '../domain/interfaces/i_chat_service.dart';
import '../domain/interfaces/i_product_service.dart';

class ChatService implements IChatService {
  final SupabaseClient _client;
  final IProductService _productService; // 인터페이스로 주입!

  // 생성자 주입
  ChatService({
    required SupabaseClient client,
    required IProductService productService,
  })  : _client = client,
        _productService = productService;

  @override
  Future<List<Chat>> getUserChats(String userId) async {
    // 최적화된 쿼리 사용 (PERFORMANCE_GUIDE.md 참조)
    final response = await _client
        .from('chats')
        .select('''
          *,
          product:products(id, title, price, images, status),
          participant1:users!participant1_id(id, name, profile_image_url),
          participant2:users!participant2_id(id, name, profile_image_url)
        ''')
        .or('participant1_id.eq.$userId,participant2_id.eq.$userId')
        .order('updated_at', ascending: false);

    return response.map((data) => Chat.fromJson(data)).toList();
  }

  // 다른 메서드들...
}
```

```dart
// lib/services/product_service.dart
import '../domain/interfaces/i_product_service.dart';

class ProductService implements IProductService {
  final SupabaseClient _client;

  ProductService({required SupabaseClient client}) : _client = client;

  @override
  Future<Product?> getProduct(String productId) async {
    final response = await _client
        .from('products')
        .select('''
          *,
          seller:users!seller_id(id, name, profile_image_url, rating)
        ''')
        .eq('id', productId)
        .single();

    return Product.fromJson(response);
  }

  @override
  Future<List<Product>> getProducts({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from('products')
        .select('''
          *,
          seller:users!seller_id(id, name, profile_image_url, rating)
        ''')
        .eq('deleted_at', null)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map((data) => Product.fromJson(data)).toList();
  }

  // 다른 메서드들...
}
```

### Step 2: Service Locator 패턴 (get_it 사용)

#### 2-1. pubspec.yaml에 의존성 추가
```yaml
dependencies:
  get_it: ^7.6.0
```

#### 2-2. Service Locator 설정
```dart
// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/interfaces/i_product_service.dart';
import '../../domain/interfaces/i_chat_service.dart';
import '../../domain/interfaces/i_shop_service.dart';
import '../../services/product_service.dart';
import '../../services/chat_service.dart';
import '../../services/shop_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Supabase 클라이언트 등록 (싱글톤)
  getIt.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );

  // 서비스 등록 (싱글톤)
  getIt.registerLazySingleton<IProductService>(
    () => ProductService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<IChatService>(
    () => ChatService(
      client: getIt<SupabaseClient>(),
      productService: getIt<IProductService>(),
    ),
  );

  getIt.registerLazySingleton<IShopService>(
    () => ShopService(
      client: getIt<SupabaseClient>(),
      productService: getIt<IProductService>(),
    ),
  );
}
```

#### 2-3. main.dart에서 초기화
```dart
// lib/main.dart
import 'core/di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // 의존성 주입 설정
  await setupServiceLocator();

  runApp(const MyApp());
}
```

### Step 3: Provider와 통합

#### 3-1. Provider 수정
```dart
// lib/providers/product_provider.dart
import 'package:flutter/foundation.dart';
import '../domain/interfaces/i_product_service.dart';
import '../core/di/service_locator.dart';

class ProductProvider with ChangeNotifier {
  final IProductService _productService;

  // 생성자 주입
  ProductProvider({IProductService? productService})
      : _productService = productService ?? getIt<IProductService>();

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _productService.getProducts();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

#### 3-2. MultiProvider 설정
```dart
// lib/main.dart
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService: getIt<IAuthService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(
            productService: getIt<IProductService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            chatService: getIt<IChatService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ShopProvider(
            shopService: getIt<IShopService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'EverSeconds',
        // ...
      ),
    );
  }
}
```

### Step 4: UI에서 사용

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
    // Provider를 통해 데이터 로드
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
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('오류: ${provider.error}'));
          }

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

## 🧪 테스트 작성

### Mock 객체 생성
```dart
// test/mocks/mock_product_service.dart
import 'package:mockito/mockito.dart';
import 'package:resale_marketplace_app/domain/interfaces/i_product_service.dart';

class MockProductService extends Mock implements IProductService {}

// test/providers/product_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../mocks/mock_product_service.dart';

void main() {
  late MockProductService mockProductService;
  late ProductProvider productProvider;

  setUp(() {
    mockProductService = MockProductService();
    productProvider = ProductProvider(productService: mockProductService);
  });

  test('loadProducts should update products list', () async {
    // Arrange
    final mockProducts = [
      Product(id: '1', title: 'Test Product'),
    ];
    when(mockProductService.getProducts())
        .thenAnswer((_) async => mockProducts);

    // Act
    await productProvider.loadProducts();

    // Assert
    expect(productProvider.products, mockProducts);
    expect(productProvider.isLoading, false);
    expect(productProvider.error, null);
  });

  test('loadProducts should set error on failure', () async {
    // Arrange
    when(mockProductService.getProducts())
        .thenThrow(Exception('Network error'));

    // Act
    await productProvider.loadProducts();

    // Assert
    expect(productProvider.products, isEmpty);
    expect(productProvider.isLoading, false);
    expect(productProvider.error, isNotNull);
  });
}
```

## 📁 디렉토리 구조

```
lib/
├── core/
│   ├── di/
│   │   └── service_locator.dart
│   ├── utils/
│   └── constants/
├── domain/
│   ├── entities/
│   │   ├── product.dart
│   │   ├── chat.dart
│   │   └── shop.dart
│   ├── interfaces/
│   │   ├── i_product_service.dart
│   │   ├── i_chat_service.dart
│   │   └── i_shop_service.dart
│   └── use_cases/
│       ├── get_products_use_case.dart
│       └── send_message_use_case.dart
├── data/
│   ├── services/
│   │   ├── product_service.dart
│   │   ├── chat_service.dart
│   │   └── shop_service.dart
│   ├── repositories/
│   └── models/
├── presentation/
│   ├── providers/
│   │   ├── product_provider.dart
│   │   ├── chat_provider.dart
│   │   └── auth_provider.dart
│   ├── screens/
│   │   ├── product/
│   │   ├── chat/
│   │   └── shop/
│   └── widgets/
└── main.dart
```

## 🎯 마이그레이션 순서

### Phase 1: 인터페이스 정의 (1일)
- [ ] IProductService 인터페이스 생성
- [ ] IChatService 인터페이스 생성
- [ ] IShopService 인터페이스 생성
- [ ] IAuthService 인터페이스 생성

### Phase 2: 서비스 리팩토링 (2일)
- [ ] ProductService 인터페이스 구현
- [ ] ChatService 의존성 주입 적용
- [ ] ShopService 의존성 주입 적용
- [ ] 서비스 간 결합도 제거

### Phase 3: DI 설정 (1일)
- [ ] get_it 패키지 추가
- [ ] service_locator.dart 생성
- [ ] main.dart에서 초기화

### Phase 4: Provider 통합 (2일)
- [ ] Provider 생성자 주입 적용
- [ ] MultiProvider 설정
- [ ] UI에서 Provider 사용 패턴 통일

### Phase 5: 테스트 작성 (3일)
- [ ] Mock 객체 생성
- [ ] Provider 단위 테스트
- [ ] Service 단위 테스트
- [ ] 통합 테스트

## 📊 예상 효과

### 코드 품질
- **테스트 가능성**: Mock 객체 사용으로 단위 테스트 작성 가능
- **유지보수성**: 의존성 변경 시 한 곳만 수정
- **재사용성**: 인터페이스 기반으로 다양한 구현체 교체 가능

### 개발 생산성
- **디버깅**: 의존성 흐름이 명확하여 디버깅 용이
- **확장성**: 새로운 기능 추가 시 기존 코드 수정 최소화
- **협업**: 명확한 아키텍처로 팀 협업 효율 향상

## 🔍 참고 자료

- [Clean Architecture in Flutter](https://resocoder.com/category/tutorials/flutter/clean-architecture/)
- [Flutter Provider Pattern](https://docs.flutter.dev/development/data-and-backend/state-mgmt/simple)
- [Dependency Injection with get_it](https://pub.dev/packages/get_it)
