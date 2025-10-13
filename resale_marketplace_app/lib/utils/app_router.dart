import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/shop/my_shop_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/product/product_create_screen.dart';
import '../screens/product/my_products_screen.dart';
import '../screens/resale/resale_browse_screen.dart';
import '../screens/resale/resale_manage_screen.dart';
import '../screens/chat/chat_room_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Main app routes with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainNavigationScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/shop',
            name: 'shop',
            builder: (context, state) => const MyShopScreen(),
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
        path: '/product/:id',
        name: 'product-detail',
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('상품 상세')),
            body: Center(
              child: Text('Product ID: ${state.pathParameters['id']}'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/product/create',
        name: 'product-create',
        builder: (context, state) => const ProductCreateScreen(),
      ),
      GoRoute(
        path: '/my-products',
        name: 'my-products',
        builder: (context, state) => const MyProductsScreen(),
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
      
      // Resale routes
      GoRoute(
        path: '/resale/browse',
        name: 'resale-browse',
        builder: (context, state) => const ResaleBrowseScreen(),
      ),
      GoRoute(
        path: '/resale/manage',
        name: 'resale-manage',
        builder: (context, state) => const ResaleManageScreen(),
      ),
    ],
  );
}

class MainNavigationScreen extends StatefulWidget {
  final Widget child;
  
  const MainNavigationScreen({
    super.key,
    required this.child,
  });

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
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
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