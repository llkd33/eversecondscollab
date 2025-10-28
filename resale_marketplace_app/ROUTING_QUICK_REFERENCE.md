# Quick Reference: Flutter Routing & Navigation

## Routing Package

```yaml
go_router: ^14.6.2
```

## Route Organization

```
Authentication Routes (4)
├── /login
├── /signup (phone/kakao)
├── /phone-auth
└── /auth/kakao/callback

Main Navigation (ShellRoute - 4)
├── / (home)
├── /chat
├── /shop
└── /profile

Features (22+)
├── /product/* (detail, create, list)
├── /transaction/* (create, list, detail)
├── /chat_room
├── /reviews
├── /resale/*
└── /admin/* (admin-only)
```

## Parameter Passing Methods

### 1. Path Parameters (in URL)
```dart
context.push('/product/123');
context.push('/shop/shop-abc123');

// Extract in builder:
final productId = state.pathParameters['id'] ?? '';
```

### 2. Query Parameters (in URL)
```dart
context.go('/login?redirect=%2Fchat');

// Extract:
final redirect = state.uri.queryParameters['redirect'];
```

### 3. Extra Data (NOT in URL - not shareable)
```dart
context.push('/chat_room', extra: {
    'chatRoomId': id,
    'userName': name,
});

// Extract:
final extra = state.extra as Map<String, dynamic>?;
final chatId = extra?['chatRoomId'] ?? '';
```

## Navigation Commands

```dart
// Replace current route
context.go('/home');

// Push on stack
context.push('/product/123');

// Push with data
context.push('/chat_room', extra: {...});

// Pop current
context.pop();

// Pop until home
context.goNamed('home');
```

## Authentication & Protected Routes

### Router-Level Protection
```dart
redirect: (context, state) {
    if (!authProvider.isAuthenticated && 
        protectedPaths.contains(state.uri.path)) {
        return '/login?redirect=${Uri.encodeComponent(state.uri.path)}';
    }
    return null;
}
```

### Widget-Level Protection
```dart
GoRoute(
    path: '/product/create',
    builder: (context, state) =>
        const AuthGuard(child: ProductCreateScreen()),
),
```

## Deep Linking Status

### Currently Supported ✅
- OAuth callbacks: `resale.marketplace.app://auth-callback?code=...`

### Not Yet Implemented ❌
- Product links: `resale.marketplace.app://product/123`
- Shop links: `resale.marketplace.app://shop/shop-id`
- Chat links: `resale.marketplace.app://chat/chat-id`

## Key Files

| File | Purpose |
|------|---------|
| `/lib/utils/app_router.dart` | Router definition & routes |
| `/lib/main.dart` | App init & deep link setup |
| `/android/app/src/main/AndroidManifest.xml` | Android deep link config |
| `/ios/Runner/Info.plist` | iOS deep link config |

## Implementation Patterns

### Route with ID Parameter
```dart
GoRoute(
    path: '/product/:id',
    name: 'product-detail',
    builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ProductDetailScreen(productId: id);
    },
),
```

### Route with Extra Data
```dart
GoRoute(
    path: '/transaction/create',
    builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return TransactionCreationScreen(
            product: extra?['product'] as ProductModel,
            buyerId: extra?['buyerId'] as String,
        );
    },
),
```

### Route with Auth Guard
```dart
GoRoute(
    path: '/chat',
    builder: (context, state) =>
        const AuthGuard(child: ChatListScreen()),
),
```

### Role-Based Route
```dart
if (isAdminPath) {
    if (!authProvider.isAdmin) {
        return '/?error=access_denied';
    }
}
```

## Common Navigation Patterns

### Navigate to Product Detail
```dart
// From product list
context.push('/product/${product.id}');
```

### Navigate to Chat with Context
```dart
context.push('/chat_room', extra: {
    'chatRoomId': chat.id,
    'userName': seller.name,
    'productTitle': product.title,
});
```

### Login with Redirect
```dart
// Auto-redirects to protected path after login
context.push('/login?redirect=%2Fchat');
```

### Share Product (Current - Web URL)
```dart
Share.share('Product: $title\nhttps://everseconds.com/product/$id');
```

### Share Product (Recommended - Deep Link)
```dart
Share.share('Product: $title\nresale.marketplace.app://product/$id');
```

## Testing Checklist

- [ ] All routes load with valid params
- [ ] Invalid params handled gracefully
- [ ] Auth guards work correctly
- [ ] Deep links open correct screens
- [ ] Back button works everywhere
- [ ] Bottom nav persists state
- [ ] Redirects work after login
- [ ] Admin routes blocked for non-admins

## Performance Tips

1. Routes are lazy-loaded (only built when accessed)
2. Use path parameters for shareable links
3. Use extra data for complex objects
4. Keep redirect logic simple
5. Avoid rebuilds with proper state management

## Security Tips

1. Validate deep link parameters
2. Check auth state before sensitive ops
3. Use session timeouts
4. Sanitize path parameters
5. Verify OAuth state parameter

