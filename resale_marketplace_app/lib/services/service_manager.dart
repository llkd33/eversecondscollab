import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';
import 'user_service.dart';
import 'product_service.dart';
import 'shop_service.dart';
import 'chat_service.dart';
import 'transaction_service.dart';
import 'safe_transaction_service.dart';
import 'review_service.dart';
import 'sms_service.dart';

/// 모든 서비스를 관리하는 중앙 서비스 매니저
/// 싱글톤 패턴으로 구현하여 앱 전체에서 하나의 인스턴스만 사용
class ServiceManager {
  static ServiceManager? _instance;
  static ServiceManager get instance => _instance ??= ServiceManager._();
  
  ServiceManager._();

  // 서비스 인스턴스들
  late final AuthService _authService;
  late final UserService _userService;
  late final ProductService _productService;
  late final ShopService _shopService;
  late final ChatService _chatService;
  late final TransactionService _transactionService;
  late final SafeTransactionService _safeTransactionService;
  late final ReviewService _reviewService;
  late final SMSService _smsService;

  // 초기화 여부
  bool _isInitialized = false;

  /// 서비스 매니저 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Supabase 초기화
      await SupabaseConfig.initialize();
      
      // 카카오 SDK 초기화
      AuthService.initializeKakao();

      // 서비스 인스턴스 생성
      _authService = AuthService();
      _userService = UserService();
      _productService = ProductService();
      _shopService = ShopService();
      _chatService = ChatService();
      _transactionService = TransactionService();
      _safeTransactionService = SafeTransactionService();
      _reviewService = ReviewService();
      _smsService = SMSService();

      _isInitialized = true;
      print('ServiceManager initialized successfully');
    } catch (e) {
      print('Error initializing ServiceManager: $e');
      rethrow;
    }
  }

  /// 초기화 확인
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('ServiceManager not initialized. Call initialize() first.');
    }
  }

  // 서비스 접근자들
  AuthService get auth {
    _ensureInitialized();
    return _authService;
  }

  UserService get user {
    _ensureInitialized();
    return _userService;
  }

  ProductService get product {
    _ensureInitialized();
    return _productService;
  }

  ShopService get shop {
    _ensureInitialized();
    return _shopService;
  }

  ChatService get chat {
    _ensureInitialized();
    return _chatService;
  }

  TransactionService get transaction {
    _ensureInitialized();
    return _transactionService;
  }

  SafeTransactionService get safeTransaction {
    _ensureInitialized();
    return _safeTransactionService;
  }

  ReviewService get review {
    _ensureInitialized();
    return _reviewService;
  }

  SMSService get sms {
    _ensureInitialized();
    return _smsService;
  }

  // Supabase 클라이언트 직접 접근
  SupabaseClient get client {
    _ensureInitialized();
    return SupabaseConfig.client;
  }

  // 현재 사용자 정보
  User? get currentUser => SupabaseConfig.currentUser;
  
  // 인증 상태 스트림
  Stream<AuthState> get authStateChanges => SupabaseConfig.authStateChanges;

  // 로그인 여부 확인
  bool get isSignedIn => SupabaseConfig.currentUser != null;

  /// 리소스 정리
  void dispose() {
    _chatService.dispose();
    print('ServiceManager disposed');
  }

  /// 실시간 기능 구독 관리
  
  // 채팅 구독
  StreamSubscription<List<Map<String, dynamic>>> subscribeToChat(
    String chatId,
    void Function(dynamic) onNewMessage,
  ) {
    _ensureInitialized();
    return _chatService.subscribeToChat(chatId, onNewMessage);
  }

  // 채팅 구독 해제
  void unsubscribeFromChat(String chatId) {
    _ensureInitialized();
    _chatService.unsubscribeFromChat(chatId);
  }

  // 모든 실시간 구독 해제
  void unsubscribeAll() {
    _ensureInitialized();
    _chatService.unsubscribeAll();
  }

  /// 통합 검색 기능
  Future<Map<String, dynamic>> search({
    required String query,
    List<String> types = const ['products', 'shops', 'users'],
    int limit = 20,
  }) async {
    _ensureInitialized();
    
    final results = <String, dynamic>{};

    try {
      // 상품 검색
      if (types.contains('products')) {
        results['products'] = await _productService.getProducts(
          searchQuery: query,
          limit: limit,
        );
      }

      // 샵 검색
      if (types.contains('shops')) {
        results['shops'] = await _shopService.searchShops(
          query: query,
          limit: limit,
        );
      }

      // 사용자 검색 (관리자만)
      if (types.contains('users') && currentUser != null) {
        final currentUserData = await _userService.getCurrentUser();
        if (currentUserData?.isAdmin == true) {
          results['users'] = await _userService.getAllUsers(limit: limit);
        }
      }

      return results;
    } catch (e) {
      print('Error in unified search: $e');
      return {};
    }
  }

  /// 대시보드 데이터 조회 (관리자용)
  Future<Map<String, dynamic>> getDashboardData() async {
    _ensureInitialized();
    
    try {
      // 사용자 통계
      final userStats = await client
          .from('users')
          .select('role')
          .then((response) {
            final stats = <String, int>{};
            for (final user in response) {
              final role = user['role'] as String;
              stats[role] = (stats[role] ?? 0) + 1;
            }
            return stats;
          });

      // 상품 통계
      final productStats = await _productService.getProductCountByCategory();

      // 거래 통계
      final transactionStats = await client
          .from('transactions')
          .select('status')
          .then((response) {
            final stats = <String, int>{};
            for (final transaction in response) {
              final status = transaction['status'] as String;
              stats[status] = (stats[status] ?? 0) + 1;
            }
            return stats;
          });

      // 안전거래 통계
      final safeTransactionStats = await _safeTransactionService.getSafeTransactionStats();

      // SMS 통계
      final smsStats = await _smsService.getSMSStats();

      return {
        'user_stats': userStats,
        'product_stats': productStats,
        'transaction_stats': transactionStats,
        'safe_transaction_stats': safeTransactionStats,
        'sms_stats': smsStats,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting dashboard data: $e');
      return {};
    }
  }

  /// 사용자별 통합 통계
  Future<Map<String, dynamic>> getUserDashboard(String userId) async {
    _ensureInitialized();
    
    try {
      // 사용자 기본 통계
      final userStats = await _userService.getUserStats(userId);
      
      // 거래 통계
      final transactionStats = await _transactionService.getTransactionStats(userId);
      
      // 리뷰 통계
      final reviewStats = await _reviewService.getUserRatingStats(userId);
      
      // 샵 통계
      final userShop = await _shopService.getShopByOwnerId(userId);
      Map<String, dynamic> shopStats = {};
      if (userShop != null) {
        shopStats = await _shopService.getShopStats(userShop.id);
      }

      return {
        'user_stats': userStats,
        'transaction_stats': transactionStats,
        'review_stats': reviewStats,
        'shop_stats': shopStats,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting user dashboard: $e');
      return {};
    }
  }

  /// 에러 로깅
  Future<void> logError({
    required String error,
    String? userId,
    String? action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await client.from('error_logs').insert({
        'error_message': error,
        'user_id': userId ?? currentUser?.id,
        'action': action,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging error: $e');
    }
  }

  /// 사용자 활동 로깅
  Future<void> logUserActivity({
    required String action,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await client.from('user_activities').insert({
        'user_id': userId ?? currentUser?.id,
        'action': action,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging user activity: $e');
    }
  }
}