# Flutter Resale Marketplace App: Routing & Navigation Architecture Analysis

**Generated**: 2025-10-27  
**Project**: resale_marketplace_app (Dart/Flutter)  
**Analysis Scope**: Routing configuration, navigation patterns, deep linking implementation  
**Files Analyzed**: 104 Dart files across lib/

---

## Executive Summary

The app uses a **modern go_router based architecture** with:
- **Primary routing package**: go_router (v14.6.2)
- **Deep linking support**: Full iOS/Android configuration with custom URI scheme
- **Parameter passing**: Query parameters, path parameters, and named extra data
- **Authentication guards**: Protected routes with redirect logic
- **Admin routes**: Role-based access control

---

## 1. Routing Architecture Summary

### 1.1 Routing Package Selection

**Package**: `go_router: ^14.6.2`

**Why go_router?**
- Declarative URL-based routing (instead of named routes)
- Built-in deep linking support
- URL/path parameter handling
- Redirect logic for authentication flows
- Nested navigation with ShellRoute

**Alternative packages available but not used:**
- auto_route (more complex, less used)
- native Flutter Navigator (too verbose for complex apps)

### 1.2 Router Initialization

**Location**: `/lib/utils/app_router.dart` (407 lines)  
**Initialization**: `/lib/main.dart` (lines 204, 211)

```dart
// main.dart
AppRouter.router = AppRouter.createRouter(context);
return MaterialApp.router(
  routerConfig: AppRouter.router,
  ...
);
```

**Key initialization details:**
- Router created dynamically during app startup
- Context available for provider access (AuthProvider)
- Single GoRouter instance managed statically

### 1.3 Route Structure Overview

**Total Routes**: 30+ routes organized into 5 categories:

1. **Authentication Routes** (4 routes)
   - Login, signup (phone/kakao), phone auth
   
2. **Main App Routes with Bottom Navigation** (5 routes via ShellRoute)
   - Home, Chat, Shop, Profile
   - Wrapped in MainNavigationScreen for persistent bottom nav
   
3. **Product Routes** (4 routes)
   - Product detail, create, list, edit
   
4. **Transaction Routes** (3 routes)
   - Create, list, detail
   
5. **Additional Features** (14+ routes)
   - Chat rooms, reviews, resale, admin, search, etc.

---

## 2. Current Deep Linking Support

### 2.1 Deep Link Configuration (Android)

**File**: `/android/app/src/main/AndroidManifest.xml`

```xml
<!-- Deep Link for OAuth Callback -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="resale.marketplace.app"
        android:host="auth-callback" />
</intent-filter>

<!-- Kakao OAuth Deep Link -->
<data
    android:scheme="kakao0d0b331b737c31682e666aadc2d97763"
    android:host="oauth" />
```

**URI Format**: `resale.marketplace.app://auth-callback`

### 2.2 Deep Link Configuration (iOS)

**File**: `/ios/Runner/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>resale.marketplace.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>resale.marketplace.app</string>
        </array>
    </dict>
</array>
```

### 2.3 Deep Link Handling (Runtime)

**File**: `/lib/main.dart` (lines 38-188)

**AppLinks Integration**: Uses `app_links: ^6.3.2`

```dart
// Listen for deep links when app is running
appLinks.uriLinkStream.listen((uri) async {
    print('🔗 Deep link received: $uri');
    await _handleOAuthDeepLink(uri);
});

// Handle cold start deep links
final initialUri = await appLinks.getInitialLink();
if (initialUri != null) {
    await _handleOAuthDeepLink(initialUri);
}
```

**Supported Deep Link Patterns**:
- `resale.marketplace.app://auth-callback?code=...` (OAuth authorization)
- `resale.marketplace.app://auth-callback?error=...` (OAuth errors)
- Fragment-based parameters for access tokens

**Current Limitations**:
- Only OAuth callback handling implemented
- No product deep links (e.g., `resale.marketplace.app://product/123`)
- No shop sharing deep links
- No direct app-to-app linking

---

## 3. Route Parameter Patterns

### 3.1 Path Parameters

**Pattern**: `:paramName` in route path

**Examples**:

```dart
// Product detail - passed in URL
GoRoute(
    path: '/product/:id',
    name: 'product-detail',
    builder: (context, state) {
        final productId = state.pathParameters['id'] ?? '';
        return ProductDetailScreen(productId: productId);
    },
),

// Shop public - shared link parameter
GoRoute(
    path: '/shop/:shareUrl',
    name: 'shop-public',
    builder: (context, state) {
        final shareUrl = state.pathParameters['shareUrl'] ?? '';
        return PublicShopScreen(shareUrl: shareUrl);
    },
),

// Transaction detail
GoRoute(
    path: '/transaction/:id',
    name: 'transaction-detail',
    builder: (context, state) {
        final transactionId = state.pathParameters['id'] ?? '';
        ...
    },
),
```

### 3.2 Query Parameters

**Pattern**: `?key=value` in URL

**Examples**:

```dart
// Login with redirect
GoRoute(
    path: '/login',
    builder: (context, state) =>
        LoginScreen(redirectPath: state.uri.queryParameters['redirect']),
),

// Product not found with error message
// Usage: context.go('/?error=access_denied');
```

### 3.3 Extra Data Parameters

**Pattern**: Named data passed through `extra` parameter (not in URL)

**Examples**:

```dart
// Chat room navigation with extra data
context.push(
    '/chat_room',
    extra: {
        'chatRoomId': chat.id,
        'userName': _product?.sellerName ?? '',
        'productTitle': _product?.title ?? '',
    },
);

// Transaction creation
context.push('/transaction/create', extra: {
    'product': ProductModel(...),
    'buyerId': userId,
    'sellerId': sellerId,
    'resellerId': resellerId,
    'chatId': chatId,
});

// Reviews
context.push('/reviews', extra: {
    'userId': userId,
    'userName': userName,
});
```

**Limitations**: Extra data not persisted in URL (not shareable)

---

## 4. Navigation Implementation Patterns

### 4.1 Basic Navigation

```dart
// Go to route (replaces current)
context.go('/home');

// Push route (adds to stack)
context.push('/product/${id}');

// Pop current route
context.pop();
```

### 4.2 Named Routes

```dart
// Using route names instead of paths
context.goNamed('product-detail');

// With parameters
context.goNamed('product-detail', pathParameters: {'id': '123'});
```

### 4.3 Protected Routes (Authentication Guards)

**Pattern**: Redirect logic in GoRouter.redirect()

```dart
redirect: (context, state) {
    final isAuthenticated = authProvider.isAuthenticated;
    final currentPath = state.uri.path;
    
    // Protected paths
    final protectedPaths = [
        '/chat',
        '/product/create',
        '/my-products',
        '/transaction',
        '/resale/manage',
    ];
    
    if (!isAuthenticated && 
        protectedPaths.any((path) => currentPath.startsWith(path))) {
        return '/login?redirect=${Uri.encodeComponent(currentPath)}';
    }
    
    return null; // Allow navigation
}
```

**Implementation with AuthGuard Widget**:

```dart
GoRoute(
    path: '/product/create',
    builder: (context, state) =>
        const AuthGuard(child: ProductCreateScreen()),
),
```

### 4.4 Role-Based Access Control

```dart
// Admin routes protection
if (isAdminPath) {
    if (!isAuthenticated) {
        return '/login?redirect=${Uri.encodeComponent(currentPath)}';
    }
    final userRole = authProvider.currentUser?.role ?? '';
    if (!['관리자'].contains(userRole)) {
        return '/?error=access_denied';
    }
}
```

### 4.5 Session Validation & Auto-Logout

```dart
if (isAuthenticated && !isSessionValid) {
    return '/login?expired=true';
}
```

---

## 5. Bottom Navigation Implementation

### 5.1 ShellRoute Pattern

**Location**: `/lib/utils/app_router.dart` (lines 169-205)

```dart
ShellRoute(
    builder: (context, state, child) =>
        MainNavigationScreen(child: child),
    routes: [
        GoRoute(path: '/', name: 'home', ...),
        GoRoute(path: '/chat', name: 'chat', ...),
        GoRoute(path: '/shop', name: 'shop', ...),
        GoRoute(path: '/profile', name: 'profile', ...),
    ],
),
```

**Features**:
- Persistent bottom navigation across 4 main tabs
- MainNavigationScreen manages tab state
- Only shows nav on home, chat, shop, profile routes

### 5.2 Navigation Tab Synchronization

```dart
int _getIndexFromLocation(String location) {
    switch (location) {
        case '/': return 0;      // Home
        case '/chat': return 1;  // Chat
        case '/shop': return 2;  // Shop
        case '/profile': return 3; // Profile
        default: return 0;
    }
}
```

---

## 6. Sharing & Deep Link Examples

### 6.1 Product Sharing

**Current Implementation**:

```dart
// In product_detail_screen.dart
void _shareProduct() {
    final productLink = 'https://everseconds.com/product/${_product!.id}';
    
    Share.share(
        '${_product!.title}\n가격: ${_product!.formattedPrice}\n\n상품 보기: $productLink',
        subject: _product!.title,
    );
}
```

**Limitation**: Uses web URL, not app deep link

**Recommended**: Should be `resale.marketplace.app://product/${productId}`

### 6.2 Shop Sharing

**Current Implementation**:

```dart
// In public_shop_screen.dart
GoRoute(
    path: '/shop/:shareUrl',
    builder: (context, state) {
        final shareUrl = state.pathParameters['shareUrl'] ?? '';
        return PublicShopScreen(shareUrl: shareUrl);
    },
),

// URL format: /shop/com.example.shop.abc123
// Extracts shop ID from URL internally
```

**Limitation**: Share URL is custom, not standard deep link format

---

## 7. Route Reference Summary

### 7.1 Complete Route Map

| Path | Name | Auth Required | Parameters | Purpose |
|------|------|---------------|-----------|---------|
| `/` | home | No | - | Home feed |
| `/login` | login | No | `redirect` (query) | User login |
| `/signup` | signup | No | - | Phone signup |
| `/signup/phone` | signup-phone | No | - | Phone signup |
| `/signup/kakao` | signup-kakao | No | - | Kakao signup |
| `/phone-auth` | phone-auth | No | - | Phone verification |
| `/auth/kakao/callback` | kakao-callback | No | `provider`, `code`, `error` | OAuth callback |
| `/chat` | chat | Yes | - | Chat list |
| `/chat_room` | chat-room | Yes | `extra` data | Chat room with user |
| `/shop` | shop | Yes | - | User's shop |
| `/shop/:shareUrl` | shop-public | No | `shareUrl` (path) | Public shop view |
| `/profile` | profile | No | - | User profile |
| `/product/create` | product-create | Yes | - | Create product |
| `/product/:id` | product-detail | No | `id` (path) | Product details |
| `/product/detail/:id` | product-detail-alt | No | `id` (path) | Product details (alt) |
| `/my-products` | my-products | Yes | - | User's products |
| `/search` | search | No | - | Search products |
| `/transaction/create` | transaction-create | Yes | `extra` data | Create transaction |
| `/transaction/list` | transaction-list | Yes | - | Transaction history |
| `/transaction/:id` | transaction-detail | Yes | `id` (path) | Transaction details |
| `/transaction/:transactionId/reviews` | transaction-reviews | Yes | `transactionId` (path) | Review transaction |
| `/reviews` | reviews | No | `extra` data | View user reviews |
| `/review/create` | review-create | Yes | `extra` data | Create review |
| `/resale/browse` | resale-browse | No | - | Browse resale items |
| `/resale/manage` | resale-manage | Yes | - | Manage resale items |
| `/admin` | admin | Admin only | - | Admin dashboard |
| `/admin/web` | admin-web | Admin only | - | Web admin dashboard |
| `/admin/users` | admin-users | Admin only | - | User management |
| `/admin/transactions` | admin-transactions | Admin only | - | Transaction monitoring |
| `/admin/reports` | admin-reports | Admin only | - | Report management |
| `/revenue-management` | revenue-management | Yes | - | Revenue stats |
| `/coming-soon` | coming-soon | No | `extra` data | Coming soon placeholder |

---

## 8. Code Organization

### 8.1 File Structure

```
lib/
├── utils/
│   └── app_router.dart         (407 lines) - All routing logic
├── main.dart                   (219 lines) - App initialization & deep link setup
├── screens/
│   ├── home/                   - Home screen & optimized version
│   ├── auth/                   - Login, signup, OAuth callback
│   ├── product/                - Product CRUD operations
│   ├── shop/                   - Shop management & public view
│   ├── chat/                   - Chat list & rooms
│   ├── transaction/            - Transaction flow
│   ├── profile/                - User profile & revenue
│   ├── resale/                 - Resale feature
│   ├── review/                 - Review management
│   ├── search/                 - Search functionality
│   ├── admin/                  - Admin dashboard
│   └── common/                 - Common screens (coming soon, etc)
├── providers/
│   └── auth_provider.dart      - Authentication state
├── services/
│   ├── product_service.dart
│   ├── shop_service.dart
│   ├── chat_service.dart
│   └── ... (other services)
└── widgets/
    ├── auth_guard.dart         - Route protection widget
    └── navigation/
        └── app_bottom_nav.dart - Bottom navigation widget
```

### 8.2 Key Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| `/lib/utils/app_router.dart` | 407 | Router configuration, route definitions, main nav screen |
| `/lib/main.dart` | 219 | App initialization, deep link handling, Firebase setup |
| `/lib/widgets/auth_guard.dart` | ~50 | Authentication verification widget |
| `/lib/screens/product/product_detail_screen.dart` | 1120 | Product detail view & sharing |
| `/lib/screens/shop/public_shop_screen.dart` | 252 | Public shop display |

---

## 9. Recommendations for Product Detail Sharing

### 9.1 Implement Product Deep Links

**Current**: Uses web URL `https://everseconds.com/product/{id}`  
**Recommended**: Support app deep links

**Implementation**:

```dart
// Add to AndroidManifest.xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="resale.marketplace.app"
        android:host="product"
        android:pathPattern="/.*" />
</intent-filter>

// Add to Info.plist
<dict>
    <key>CFBundleURLName</key>
    <string>resale.marketplace.app.product</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>resale.marketplace.app</string>
    </array>
</dict>

// Update router to handle product deep links
GoRoute(
    path: '/product/:id',
    name: 'product-detail',
    builder: (context, state) {
        final productId = state.pathParameters['id'] ?? '';
        return ProductDetailScreen(productId: productId);
    },
),

// Update sharing code
void _shareProduct() {
    final appLink = 'resale.marketplace.app://product/${_product!.id}';
    final webLink = 'https://everseconds.com/product/${_product!.id}';
    
    Share.share(
        '${_product!.title}\n가격: ${_product!.formattedPrice}\n\n앱으로 보기: $appLink\n\n웹으로 보기: $webLink',
        subject: _product!.title,
    );
}
```

### 9.2 Implement Shop Deep Links

**Current**: Custom path parameter based approach  
**Recommended**: Standard deep link format

```dart
// Add to manifests
<data
    android:scheme="resale.marketplace.app"
    android:host="shop"
    android:pathPattern="/.*" />

// Update share functionality
final shopLink = 'resale.marketplace.app://shop/${shop.id}';

// Router already supports this pattern
GoRoute(
    path: '/shop/:shareUrl',
    builder: (context, state) {
        final shopId = state.pathParameters['shareUrl'] ?? '';
        // Handle both: resale.marketplace.app://shop/123
        // and: /shop/shareUrl123
        return PublicShopScreen(shareUrl: shopId);
    },
),
```

### 9.3 Add Chat Deep Links

```dart
// Add to manifests
<data
    android:scheme="resale.marketplace.app"
    android:host="chat"
    android:pathPattern="/.*" />

// Add route
GoRoute(
    path: '/chat/:chatId',
    name: 'chat-deep-link',
    builder: (context, state) {
        final chatId = state.pathParameters['chatId'] ?? '';
        return ChatRoomScreen(
            chatRoomId: chatId,
            userName: '',
            productTitle: '',
        );
    },
),
```

### 9.4 Web URL to App Deep Link Bridge

```dart
// Option 1: Universal Links (recommended for iOS)
// Add apple-app-site-association file to web server
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.everseconds.resale",
        "paths": ["/product/*", "/shop/*", "/chat/*"]
      }
    ]
  }
}

// Option 2: Android App Links
// Already configured in manifest with autoVerify

// Option 3: Support both app and web
void _shareProduct() {
    final deepLink = 'resale.marketplace.app://product/${_product!.id}';
    final webLink = 'https://everseconds.com/product/${_product!.id}';
    
    Share.share(
        '${_product!.title}\n${_product!.formattedPrice}\n\n$deepLink\n$webLink',
    );
}
```

---

## 10. Performance Considerations

### 10.1 Current Performance

**Strengths**:
- Single router instance (efficient)
- Lazy loading of screens (only built when accessed)
- No unnecessary rebuilds from bottom nav (ShellRoute pattern)
- Efficient redirect logic (evaluated on nav)

**Potential Optimizations**:
- Consider caching product details during navigation
- Implement route transition animations
- Add loading indicators during route changes

### 10.2 Deep Link Performance

**Current**: 
- AppLinks listens to deep links in main()
- OAuth handling done synchronously in main thread
- No timeout protection

**Recommendations**:
- Add timeout to OAuth link handling
- Move heavy processing to background tasks
- Use async/await properly with error handling

---

## 11. Security Considerations

### 11.1 Current Security Measures

✅ **Implemented**:
- Authentication guards on protected routes
- Session validation with auto-logout
- Role-based access control for admin routes
- Intent filter with autoVerify for Android (domain verification)
- Custom URI scheme (resale.marketplace.app) - harder to spoof than http://

❌ **Missing**:
- State parameter validation in OAuth flow
- PKCE (Proof Key for Code Exchange) for OAuth
- Deep link parameter validation/sanitization
- Rate limiting on navigation attempts
- HSTS (HTTP Strict Transport Security) headers for web links

### 11.2 Security Recommendations

```dart
// Add parameter validation
GoRoute(
    path: '/product/:id',
    builder: (context, state) {
        final productId = state.pathParameters['id'] ?? '';
        
        // Validate productId format
        if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(productId)) {
            return const Scaffold(
                body: Center(child: Text('Invalid product ID')),
            );
        }
        
        return ProductDetailScreen(productId: productId);
    },
),

// Add state validation for OAuth
Future<void> _handleOAuthDeepLink(Uri uri) async {
    // Verify state parameter matches what was sent
    final state = uri.queryParameters['state'];
    final savedState = await _secureStorage.read(key: 'oauth_state');
    
    if (state != savedState) {
        print('❌ OAuth state mismatch - possible CSRF attack');
        return;
    }
    
    // Continue with OAuth flow
}
```

---

## 12. Testing Recommendations

### 12.1 Unit Tests for Routing

```dart
// Test redirect logic
test('unauthenticated user redirected to login', () {
    // Create router with unauthenticated provider
    // Navigate to protected route
    // Assert redirected to login
});

test('authenticated user can access protected routes', () {
    // Create router with authenticated provider
    // Navigate to protected route
    // Assert route accessible
});

test('admin-only route blocks non-admin users', () {
    // Create router with non-admin user
    // Navigate to admin route
    // Assert redirected to home
});
```

### 12.2 Integration Tests for Deep Links

```dart
// Test deep link navigation
testWidgets('deep link navigates to product detail', (tester) async {
    // Simulate deep link: resale.marketplace.app://product/123
    // Verify ProductDetailScreen is displayed
});

testWidgets('invalid deep link shows error', (tester) async {
    // Simulate invalid deep link
    // Verify error handling
});
```

### 12.3 Manual Testing Checklist

- [ ] Test all routes with valid parameters
- [ ] Test all routes with invalid parameters
- [ ] Test authentication redirects
- [ ] Test deep link from cold start
- [ ] Test deep link while app running
- [ ] Test back navigation from all screens
- [ ] Test bottom nav persistence
- [ ] Test redirect after login
- [ ] Test admin route access control
- [ ] Test session timeout handling

---

## 13. Conclusion

### Current State
The app has a **well-structured routing implementation** using go_router with:
- Clear route organization
- Basic deep linking for OAuth
- Protected routes with auth guards
- Bottom navigation with ShellRoute

### Gaps Identified
1. **Limited deep linking**: Only OAuth, not for main features
2. **No shareable app links**: Uses web URLs instead of deep links
3. **Extra data not persisted**: Complex data passed via extra not shareable
4. **Minimal parameter validation**: No sanitization of deep link params

### Priority Improvements
1. **High**: Add deep links for products, shops, chats (enable sharing)
2. **High**: Implement parameter validation for security
3. **Medium**: Add state validation to OAuth flow (CSRF protection)
4. **Medium**: Add timeout handling for deep link processing
5. **Low**: Add route transition animations
6. **Low**: Implement route caching for frequently accessed screens

### Files to Reference
- `/lib/utils/app_router.dart` - Main router configuration
- `/lib/main.dart` - Deep link initialization
- `/lib/screens/product/product_detail_screen.dart` - Example deep link target
- `/lib/screens/shop/public_shop_screen.dart` - Example shareable route

