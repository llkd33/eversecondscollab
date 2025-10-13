import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

enum ProductEventType {
  productUpdated,
  productStatusChanged,
  productLiked,
  productUnliked,
  productViewed,
  productDeleted,
}

class ProductEvent {
  final ProductEventType type;
  final ProductModel? product;
  final String productId;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  ProductEvent({
    required this.type,
    this.product,
    required this.productId,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 상품 관련 실시간 업데이트 서비스
class RealtimeProductService {
  static final RealtimeProductService _instance = RealtimeProductService._internal();
  factory RealtimeProductService() => _instance;
  RealtimeProductService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _productChannel;
  
  final StreamController<ProductEvent> _eventController =
      StreamController<ProductEvent>.broadcast();
  
  Stream<ProductEvent> get eventStream => _eventController.stream;
  
  bool _isInitialized = false;
  final Set<String> _subscribedCategories = {};
  final Set<String> _subscribedProducts = {};

  /// 실시간 상품 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      developer.log('Initializing realtime product service');
      
      await _setupProductChannel();
      
      _isInitialized = true;
      developer.log('Realtime product service initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize realtime product service: $e');
      rethrow;
    }
  }

  /// 상품 변경 채널 설정
  Future<void> _setupProductChannel() async {
    _productChannel = _supabase.channel('products')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'products',
        callback: _handleProductChange,
      )
      ..subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          developer.log('Subscribed to product changes');
        } else if (error != null) {
          developer.log('Product subscription error: $error');
        }
      });
  }

  /// 상품 변경 이벤트 처리
  void _handleProductChange(PostgresChangePayload payload) {
    try {
      final eventType = payload.eventType;
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;
      
      developer.log('Product change event: $eventType');
      
      switch (eventType) {
        case PostgresChangeEvent.insert:
          if (newRecord != null) {
            _handleProductInsert(newRecord);
          }
          break;
        case PostgresChangeEvent.update:
          if (newRecord != null) {
            _handleProductUpdate(newRecord, oldRecord);
          }
          break;
        case PostgresChangeEvent.delete:
          if (oldRecord != null) {
            _handleProductDelete(oldRecord);
          }
          break;
        case PostgresChangeEvent.all:
          // 전체 이벤트는 개별적으로 처리됨
          break;
      }
    } catch (e) {
      developer.log('Error handling product change: $e');
    }
  }

  /// 새 상품 등록 처리
  void _handleProductInsert(Map<String, dynamic> record) {
    try {
      final product = ProductModel.fromJson(record);
      
      // 구독 중인 카테고리인지 확인
      if (_subscribedCategories.isEmpty || 
          _subscribedCategories.contains(product.category)) {
        _eventController.add(ProductEvent(
          type: ProductEventType.productUpdated,
          product: product,
          productId: product.id,
          metadata: {'action': 'insert'},
        ));
      }
    } catch (e) {
      developer.log('Error processing product insert: $e');
    }
  }

  /// 상품 업데이트 처리
  void _handleProductUpdate(Map<String, dynamic> newRecord, Map<String, dynamic>? oldRecord) {
    try {
      final product = ProductModel.fromJson(newRecord);
      final productId = product.id;
      
      // 상태 변경 감지
      if (oldRecord != null && oldRecord['status'] != newRecord['status']) {
        _eventController.add(ProductEvent(
          type: ProductEventType.productStatusChanged,
          product: product,
          productId: productId,
          metadata: {
            'old_status': oldRecord['status'],
            'new_status': newRecord['status'],
          },
        ));
      }
      
      // 조회수 증가 감지
      if (oldRecord != null && 
          (oldRecord['view_count'] ?? 0) < (newRecord['view_count'] ?? 0)) {
        _eventController.add(ProductEvent(
          type: ProductEventType.productViewed,
          product: product,
          productId: productId,
          metadata: {
            'view_count': newRecord['view_count'],
          },
        ));
      }
      
      // 일반 업데이트
      if (_subscribedProducts.contains(productId) || 
          _subscribedCategories.isEmpty ||
          _subscribedCategories.contains(product.category)) {
        _eventController.add(ProductEvent(
          type: ProductEventType.productUpdated,
          product: product,
          productId: productId,
          metadata: {'action': 'update'},
        ));
      }
    } catch (e) {
      developer.log('Error processing product update: $e');
    }
  }

  /// 상품 삭제 처리
  void _handleProductDelete(Map<String, dynamic> record) {
    try {
      final productId = record['id'] as String;
      
      _eventController.add(ProductEvent(
        type: ProductEventType.productDeleted,
        productId: productId,
        metadata: {'action': 'delete'},
      ));
    } catch (e) {
      developer.log('Error processing product delete: $e');
    }
  }

  /// 특정 카테고리 구독
  void subscribeToCategory(String category) {
    _subscribedCategories.add(category);
    developer.log('Subscribed to category: $category');
  }

  /// 카테고리 구독 해제
  void unsubscribeFromCategory(String category) {
    _subscribedCategories.remove(category);
    developer.log('Unsubscribed from category: $category');
  }

  /// 특정 상품 구독
  void subscribeToProduct(String productId) {
    _subscribedProducts.add(productId);
    developer.log('Subscribed to product: $productId');
  }

  /// 상품 구독 해제
  void unsubscribeFromProduct(String productId) {
    _subscribedProducts.remove(productId);
    developer.log('Unsubscribed from product: $productId');
  }

  /// 모든 카테고리 구독
  void subscribeToAllCategories() {
    _subscribedCategories.clear();
    developer.log('Subscribed to all categories');
  }

  /// 상품 조회수 증가 (실시간 반영)
  Future<void> incrementViewCount(String productId) async {
    try {
      await _supabase.rpc('increment_product_view_count', params: {
        'product_id': productId,
      });
      
      developer.log('Incremented view count for product: $productId');
    } catch (e) {
      developer.log('Failed to increment view count: $e');
    }
  }

  /// 상품 좋아요 토글 (실시간 반영)
  Future<void> toggleLike(String productId, String userId) async {
    try {
      // 좋아요 상태 확인
      final existingLike = await _supabase
          .from('product_likes')
          .select('id')
          .eq('product_id', productId)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (existingLike != null) {
        // 좋아요 취소
        await _supabase
            .from('product_likes')
            .delete()
            .eq('product_id', productId)
            .eq('user_id', userId);
        
        _eventController.add(ProductEvent(
          type: ProductEventType.productUnliked,
          productId: productId,
          metadata: {'user_id': userId},
        ));
      } else {
        // 좋아요 추가
        await _supabase
            .from('product_likes')
            .insert({
          'product_id': productId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        _eventController.add(ProductEvent(
          type: ProductEventType.productLiked,
          productId: productId,
          metadata: {'user_id': userId},
        ));
      }
      
      developer.log('Toggled like for product: $productId');
    } catch (e) {
      developer.log('Failed to toggle like: $e');
      rethrow;
    }
  }

  /// 상품 상태 변경 알림 (실시간 브로드캐스트)
  Future<void> notifyStatusChange(String productId, String newStatus) async {
    try {
      // 상품 정보 조회
      final productData = await _supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single();
      
      final product = ProductModel.fromJson(productData);
      
      // 상태 변경 이벤트 브로드캐스트
      _eventController.add(ProductEvent(
        type: ProductEventType.productStatusChanged,
        product: product,
        productId: productId,
        metadata: {
          'old_status': productData['status'],
          'new_status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
      ));
      
      // Realtime 채널을 통한 브로드캐스트 (즉시 알림)
      await _productChannel?.sendBroadcastMessage(
        event: 'status_updated',
        payload: {
          'product_id': productId,
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      
      developer.log('Product status change broadcasted: $productId -> $newStatus');
    } catch (e) {
      developer.log('Failed to notify status change: $e');
      // 실패해도 에러를 던지지 않음 (부수 기능이므로)
    }
  }

  /// 연결 상태 확인
  bool get isConnected => _productChannel != null;

  /// 재연결
  Future<void> reconnect() async {
    try {
      developer.log('Reconnecting realtime product service');
      
      await _productChannel?.unsubscribe();
      await _setupProductChannel();
      
      developer.log('Realtime product service reconnected');
    } catch (e) {
      developer.log('Failed to reconnect realtime product service: $e');
    }
  }

  /// 서비스 종료
  void dispose() {
    _productChannel?.unsubscribe();
    _eventController.close();
    _isInitialized = false;
    
    developer.log('Realtime product service disposed');
  }
}