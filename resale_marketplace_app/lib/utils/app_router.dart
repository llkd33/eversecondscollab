import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/home_screen_optimized.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/shop/my_shop_screen.dart';
import '../screens/shop/public_shop_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/revenue_management_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/phone_auth_screen.dart';
// Choice screen removed; signup goes straight to phone signup
import '../screens/auth/sign_up_phone_screen.dart';
import '../screens/auth/sign_up_kakao_screen.dart';
import '../screens/auth/oauth_callback_screen.dart';
import '../widgets/auth_guard.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/product/product_create_screen.dart';
import '../screens/product/my_products_screen.dart';
import '../screens/resale/resale_browse_screen.dart';
import '../screens/resale/resale_manage_screen.dart';
import '../screens/chat/chat_room_screen.dart';
import '../screens/transaction/transaction_creation_screen.dart';
import '../screens/transaction/transaction_list_screen.dart';
import '../screens/transaction/transaction_detail_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/review/review_create_screen.dart';
import '../screens/review/review_list_screen.dart';
import '../screens/review/transaction_review_screen.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../screens/common/coming_soon_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/web_admin_dashboard.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/transaction_monitoring_screen.dart';
import '../screens/admin/report_management_screen.dart';

class AppRouter {
  // Global navigator key
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Route names
  static const String initialRoute = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String signupComplete = '/signup/complete';
  static const String profile = '/profile';
  static const String productDetail = '/product/:id';
  static const String productCreate = '/product/create';
  static const String chatList = '/chat';
  static const String chatRoom = '/chat/:id';
  static const String shop = '/shop/:id';
  static const String search = '/search';
  static const String transactionCreate = '/transaction/create';
  static const String transactionList = '/transaction/list';
  static const String transactionDetail = '/transaction/:id';

  static GoRouter createRouter(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isSessionValid = authProvider.isSessionValid();
        final currentPath = state.uri.path;

        // 인증이 필요한 경로 목록
        final protectedPaths = [
          '/chat',
          '/product/create',
          '/my-products',
          '/transaction',
          '/resale/manage',
        ];

        final isPublicShopRoute =
            currentPath.startsWith('/shop/') &&
            state.pathParameters.containsKey('shareUrl');
        final isShopRoot = currentPath == '/shop';

        // 관리자 전용 경로 목록
        final adminPaths = ['/admin'];

        // 세션이 만료된 경우
        if (isAuthenticated && !isSessionValid) {
          // 자동 로그아웃 처리는 AuthProvider에서 수행
          return '/login?expired=true';
        }

        // 보호된 경로에 대한 인증 확인
        final isProtectedPath = protectedPaths.any(
          (path) => currentPath.startsWith(path),
        );
        if (!isPublicShopRoute &&
            (isShopRoot || isProtectedPath) &&
            !isAuthenticated) {
          return '/login?redirect=${Uri.encodeComponent(currentPath)}';
        }

        // 관리자 경로에 대한 권한 확인
        final isAdminPath = adminPaths.any(
          (path) => currentPath.startsWith(path),
        );
        if (isAdminPath) {
          if (!isAuthenticated) {
            return '/login?redirect=${Uri.encodeComponent(currentPath)}';
          }
          final userRole = authProvider.currentUser?.role ?? '';
          if (!['관리자'].contains(userRole)) {
            return '/?error=access_denied';
          }
        }

        // 리다이렉트 파라미터 처리
        final redirect = state.uri.queryParameters['redirect'];
        if (redirect != null && isAuthenticated && isSessionValid) {
          return Uri.decodeComponent(redirect);
        }

        return null;
      },
      routes: [
        // Auth routes
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) =>
              LoginScreen(redirectPath: state.uri.queryParameters['redirect']),
        ),
        GoRoute(
          path: '/auth/kakao/callback',
          name: 'kakao-callback',
          builder: (context, state) => OAuthCallbackScreen(
            provider: state.uri.queryParameters['provider'],
            code: state.uri.queryParameters['code'],
            error: state.uri.queryParameters['error'],
            redirectPath: state.uri.queryParameters['redirect'],
          ),
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) => const SignUpPhoneScreen(),
        ),
        GoRoute(
          path: '/signup/phone',
          name: 'signup-phone',
          builder: (context, state) => const SignUpPhoneScreen(),
        ),
        GoRoute(
          path: '/signup/kakao',
          name: 'signup-kakao',
          builder: (context, state) => const SignUpKakaoScreen(),
        ),
        GoRoute(
          path: '/phone-auth',
          name: 'phone-auth',
          builder: (context, state) => const PhoneAuthScreen(),
        ),

        // Main app routes with bottom navigation
        ShellRoute(
          builder: (context, state, child) =>
              MainNavigationScreen(child: child),
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) =>
                  const HomeScreenOptimized(), // Using optimized version
            ),
            GoRoute(
              path: '/chat',
              name: 'chat',
              builder: (context, state) =>
                  const AuthGuard(child: ChatListScreen()),
            ),
            GoRoute(
              path: '/shop',
              name: 'shop',
              builder: (context, state) =>
                  const AuthGuard(child: MyShopScreen()),
            ),
            GoRoute(
              path: '/shop/:shareUrl',
              name: 'shop-public',
              builder: (context, state) {
                final shareUrl = state.pathParameters['shareUrl'] ?? '';
                return PublicShopScreen(shareUrl: shareUrl);
              },
            ),
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // Product routes
        GoRoute(
          path: '/product/create',
          name: 'product-create',
          builder: (context, state) =>
              const AuthGuard(child: ProductCreateScreen()),
        ),
        GoRoute(
          path: '/product/detail/:id',
          name: 'product-detail-alt',
          builder: (context, state) {
            final productId = state.pathParameters['id'] ?? '';
            return ProductDetailScreen(productId: productId);
          },
        ),
        GoRoute(
          path: '/product/:id',
          name: 'product-detail',
          builder: (context, state) {
            final productId = state.pathParameters['id'] ?? '';
            return ProductDetailScreen(productId: productId);
          },
        ),
        GoRoute(
          path: '/my-products',
          name: 'my-products',
          builder: (context, state) => const MyProductsScreen(),
        ),

        // Search route
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),

        // Chat routes
        GoRoute(
          path: '/chat_room',
          name: 'chat-room',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ChatRoomScreen(
              chatRoomId: extra?['chatRoomId'] ?? '',
              userName: extra?['userName'] ?? '',
              productTitle: extra?['productTitle'] ?? '',
            );
          },
        ),

        // Transaction routes
        GoRoute(
          path: '/transaction/create',
          name: 'transaction-create',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null || extra['product'] == null) {
              return const Scaffold(body: Center(child: Text('상품 정보가 필요합니다')));
            }
            return AuthGuard(
              child: TransactionCreationScreen(
                product: extra['product'] as ProductModel,
                buyerId: extra['buyerId'] as String,
                sellerId: extra['sellerId'] as String,
                resellerId: extra['resellerId'] as String?,
                chatId: extra['chatId'] as String?,
              ),
            );
          },
        ),
        GoRoute(
          path: '/transaction/list',
          name: 'transaction-list',
          builder: (context, state) =>
              const AuthGuard(child: TransactionListScreen()),
        ),
        GoRoute(
          path: '/transaction/:id',
          name: 'transaction-detail',
          builder: (context, state) {
            final transactionId = state.pathParameters['id'] ?? '';
            return AuthGuard(
              child: TransactionDetailScreen(transactionId: transactionId),
            );
          },
        ),

        // Resale routes
        GoRoute(
          path: '/resale/browse',
          name: 'resale-browse',
          builder: (context, state) => const ResaleBrowseScreen(),
        ),
        GoRoute(
          path: '/resale/manage',
          name: 'resale-manage',
          builder: (context, state) =>
              const AuthGuard(child: ResaleManageScreen()),
        ),

        // Review routes
        GoRoute(
          path: '/reviews',
          name: 'reviews',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null) {
              return const Scaffold(body: Center(child: Text('사용자 정보가 필요합니다')));
            }
            return ReviewListScreen(
              userId: extra['userId'] as String,
              userName: extra['userName'] as String,
            );
          },
        ),
        GoRoute(
          path: '/transaction/:transactionId/reviews',
          name: 'transaction-reviews',
          builder: (context, state) {
            final transactionId = state.pathParameters['transactionId'] ?? '';
            return AuthGuard(
              child: TransactionReviewScreen(transactionId: transactionId),
            );
          },
        ),
        GoRoute(
          path: '/review/create',
          name: 'review-create',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null || extra['transaction'] == null) {
              return const Scaffold(body: Center(child: Text('거래 정보가 필요합니다')));
            }
            return ReviewCreateScreen(
              transaction: extra['transaction'] as TransactionModel,
              reviewedUserId: extra['reviewedUserId'] as String,
              reviewedUserName: extra['reviewedUserName'] as String,
              isSellerReview: extra['isSellerReview'] as bool,
            );
          },
        ),

        // Admin routes
        GoRoute(
          path: '/admin',
          name: 'admin',
          builder: (context, state) =>
              const AdminGuard(child: AdminDashboardScreen()),
        ),
        GoRoute(
          path: '/admin/web',
          name: 'admin-web',
          builder: (context, state) =>
              const AdminGuard(child: WebAdminDashboard()),
        ),
        GoRoute(
          path: '/admin/users',
          name: 'admin-users',
          builder: (context, state) =>
              const AdminGuard(child: UserManagementScreen()),
        ),
        GoRoute(
          path: '/admin/transactions',
          name: 'admin-transactions',
          builder: (context, state) =>
              const AdminGuard(child: TransactionMonitoringScreen()),
        ),
        GoRoute(
          path: '/admin/reports',
          name: 'admin-reports',
          builder: (context, state) =>
              const AdminGuard(child: ReportManagementScreen()),
        ),

        // Revenue management route
        GoRoute(
          path: '/revenue-management',
          name: 'revenue-management',
          builder: (context, state) =>
              const AuthGuard(child: RevenueManagementScreen()),
        ),

        // Utility routes
        GoRoute(
          path: '/coming-soon',
          name: 'coming-soon',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ComingSoonScreen(
              title: (extra?['title'] as String?) ?? '준비 중입니다',
              message: extra?['message'] as String?,
            );
          },
        ),
      ],
    );
  }

  // Static router instance for backward compatibility
  static late final GoRouter router;
}

class MainNavigationScreen extends StatefulWidget {
  final Widget child;

  const MainNavigationScreen({super.key, required this.child});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  int _getIndexFromLocation(String location) {
    switch (location) {
      case '/':
        return 0;
      case '/chat':
        return 1;
      case '/shop':
        return 2;
      case '/profile':
        return 3;
      default:
        return 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    final newIndex = _getIndexFromLocation(location);
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showBottomNav =
        location == '/' ||
        location == '/chat' ||
        location == '/shop' ||
        location == '/profile';
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: !showBottomNav
          ? null
          : Container(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (index == _currentIndex) return;

                  setState(() {
                    _currentIndex = index;
                  });

                  switch (index) {
                    case 0:
                      context.go('/');
                      break;
                    case 1:
                      context.go('/chat');
                      break;
                    case 2:
                      context.go('/shop');
                      break;
                    case 3:
                      context.go('/profile');
                      break;
                  }
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: '홈',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat_bubble_outline),
                    activeIcon: Icon(Icons.chat_bubble),
                    label: '채팅',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.store_outlined),
                    activeIcon: Icon(Icons.store),
                    label: '내 샵',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: '마이페이지',
                  ),
                ],
              ),
            ),
    );
  }
}
