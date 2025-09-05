import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/transaction_model.dart';
import '../models/product_model.dart';
import 'chat_service.dart';
import 'product_service.dart';

class TransactionService {
  final SupabaseClient _client = SupabaseConfig.client;
  final ChatService _chatService = ChatService();
  final ProductService _productService = ProductService();

  // 거래 생성
  Future<TransactionModel?> createTransaction({
    required String productId,
    required String buyerId,
    required String sellerId,
    required int price,
    String? resellerId, // 대신판매자 ID
    int resaleFee = 0,
    String? chatId,
    String transactionType = '일반거래',
  }) async {
    try {
      // 1. 거래 데이터 생성
      final response = await _client.from('transactions').insert({
        'product_id': productId,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        'price': price,
        'resale_fee': resaleFee,
        'reseller_id': resellerId,
        'status': TransactionStatus.ongoing,
        'chat_id': chatId,
        'transaction_type': transactionType,
      }).select().single();

      final transaction = TransactionModel.fromJson(response);

      // 2. 상품 상태 업데이트 (판매중 → 거래중)
      await _updateProductStatus(productId, '거래중');

      // 3. 채팅방에 시스템 메시지 전송
      if (chatId != null) {
        String message = '📝 거래가 시작되었습니다.\n';
        
        if (transactionType == TransactionType.safe) {
          message += '🔒 안전거래로 진행됩니다.\n';
          message += '구매자님께서 결제를 완료하시면 판매자님께서 상품을 발송해주세요.\n';
        } else {
          message += '일반거래로 진행됩니다.\n';
          message += '거래 시 주의사항을 확인해주세요.\n';
        }

        if (resellerId != null) {
          message += '\n💡 이 거래는 대신팔기 거래입니다.\n';
          message += '대신판매 수수료: ${_formatPrice(resaleFee)}\n';
          message += '판매자 수령액: ${_formatPrice(price - resaleFee)}';
        }

        await _chatService.sendSystemMessage(
          chatId: chatId,
          content: message,
        );
      }

      return transaction;
    } catch (e) {
      print('Error creating transaction: $e');
      return null;
    }
  }

  // 거래 ID로 조회
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    try {
      final response = await _client
          .from('transactions')
          .select('''
            *,
            products!product_id (
              id,
              title,
              images,
              price
            ),
            buyer:users!buyer_id (
              id,
              name,
              profile_image
            ),
            seller:users!seller_id (
              id,
              name,
              profile_image
            ),
            reseller:users!reseller_id (
              id,
              name,
              profile_image
            )
          ''')
          .eq('id', transactionId)
          .single();

      final transaction = TransactionModel.fromJson(response);
      
      // 조인된 정보 매핑
      final product = response['products'];
      final buyer = response['buyer'];
      final seller = response['seller'];
      final reseller = response['reseller'];

      return transaction.copyWith(
        productTitle: product?['title'],
        productImage: product?['images']?.isNotEmpty == true 
            ? product!['images'][0] : null,
        buyerName: buyer?['name'],
        sellerName: seller?['name'],
        resellerName: reseller?['name'],
      );
    } catch (e) {
      print('Error getting transaction by id: $e');
      return null;
    }
  }

  // 내 거래 목록 조회
  Future<List<TransactionModel>> getMyTransactions({
    String? userId,
    String? status,
    String? role, // buyer, seller, reseller
  }) async {
    try {
      if (userId == null) {
        userId = _client.auth.currentUser?.id;
        if (userId == null) return [];
      }

      var query = _client
          .from('transactions')
          .select('''
            *,
            products!product_id (
              id,
              title,
              images,
              price
            ),
            buyer:users!buyer_id (
              id,
              name,
              profile_image
            ),
            seller:users!seller_id (
              id,
              name,
              profile_image
            ),
            reseller:users!reseller_id (
              id,
              name,
              profile_image
            )
          ''');

      // 역할별 필터링
      if (role == 'buyer') {
        query = query.eq('buyer_id', userId);
      } else if (role == 'seller') {
        query = query.eq('seller_id', userId);
      } else if (role == 'reseller') {
        query = query.eq('reseller_id', userId);
      } else {
        // 모든 관련 거래 (구매자, 판매자, 대신판매자)
        query = query.or('buyer_id.eq.$userId,seller_id.eq.$userId,reseller_id.eq.$userId');
      }

      // 상태별 필터링
      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((item) {
        final transaction = TransactionModel.fromJson(item);
        
        // 조인된 정보 매핑
        final product = item['products'];
        final buyer = item['buyer'];
        final seller = item['seller'];
        final reseller = item['reseller'];

        return transaction.copyWith(
          productTitle: product?['title'],
          productImage: product?['images']?.isNotEmpty == true 
              ? product!['images'][0] : null,
          buyerName: buyer?['name'],
          sellerName: seller?['name'],
          resellerName: reseller?['name'],
        );
      }).toList();
    } catch (e) {
      print('Error getting my transactions: $e');
      return [];
    }
  }

  // 거래 상태 업데이트
  Future<bool> updateTransactionStatus({
    required String transactionId,
    required String newStatus,
    String? reason, // 취소 사유 등
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 거래 완료 시
      if (newStatus == TransactionStatus.completed) {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      await _client
          .from('transactions')
          .update(updates)
          .eq('id', transactionId);

      // 거래 정보 조회
      final transaction = await getTransactionById(transactionId);
      if (transaction == null) return false;

      // 상품 상태 업데이트
      if (newStatus == TransactionStatus.completed) {
        await _updateProductStatus(transaction.productId, '판매완료');
      } else if (newStatus == TransactionStatus.canceled) {
        await _updateProductStatus(transaction.productId, '판매중');
      }

      // 채팅방에 시스템 메시지 전송
      if (transaction.chatId != null) {
        String message = '';
        
        if (newStatus == TransactionStatus.completed) {
          message = '✅ 거래가 완료되었습니다.\n';
          message += '구매해주셔서 감사합니다.\n';
          message += '리뷰를 작성해주시면 다른 구매자님께 도움이 됩니다.';
        } else if (newStatus == TransactionStatus.canceled) {
          message = '❌ 거래가 취소되었습니다.\n';
          if (reason != null) {
            message += '취소 사유: $reason';
          }
        }

        if (message.isNotEmpty) {
          await _chatService.sendSystemMessage(
            chatId: transaction.chatId!,
            content: message,
          );
        }
      }

      return true;
    } catch (e) {
      print('Error updating transaction status: $e');
      return false;
    }
  }

  // 안전거래 프로세스

  // 1. 결제 확인 (구매자 → 플랫폼)
  Future<bool> confirmPayment({
    required String transactionId,
    required String paymentMethod,
    String? paymentId,
  }) async {
    try {
      // 결제 정보 저장 (실제로는 PG사 연동 필요)
      await _client.from('payments').insert({
        'transaction_id': transactionId,
        'payment_method': paymentMethod,
        'payment_id': paymentId,
        'status': 'completed',
        'paid_at': DateTime.now().toIso8601String(),
      });

      // 거래 상태 업데이트
      await _client
          .from('transactions')
          .update({'payment_status': '결제완료'})
          .eq('id', transactionId);

      // 채팅방에 알림
      final transaction = await getTransactionById(transactionId);
      if (transaction?.chatId != null) {
        await _chatService.sendSystemMessage(
          chatId: transaction!.chatId!,
          content: '💳 결제가 완료되었습니다.\n판매자님께서 상품을 발송해주세요.',
        );
      }

      return true;
    } catch (e) {
      print('Error confirming payment: $e');
      return false;
    }
  }

  // 2. 배송 시작 (판매자 → 구매자)
  Future<bool> startShipping({
    required String transactionId,
    required String trackingNumber,
    String? courier, // 택배사
  }) async {
    try {
      await _client.from('transactions').update({
        'shipping_status': '배송중',
        'tracking_number': trackingNumber,
        'courier': courier,
        'shipped_at': DateTime.now().toIso8601String(),
      }).eq('id', transactionId);

      // 채팅방에 알림
      final transaction = await getTransactionById(transactionId);
      if (transaction?.chatId != null) {
        await _chatService.sendSystemMessage(
          chatId: transaction!.chatId!,
          content: '📦 상품이 발송되었습니다.\n'
              '운송장 번호: $trackingNumber\n'
              '${courier != null ? '택배사: $courier' : ''}',
        );
      }

      return true;
    } catch (e) {
      print('Error starting shipping: $e');
      return false;
    }
  }

  // 3. 수령 확인 (구매자)
  Future<bool> confirmReceipt({
    required String transactionId,
  }) async {
    try {
      // 거래 완료 처리
      await updateTransactionStatus(
        transactionId: transactionId,
        newStatus: TransactionStatus.completed,
      );

      // 정산 처리 (판매자에게 송금)
      final transaction = await getTransactionById(transactionId);
      if (transaction != null) {
        await _processSettlement(transaction);
      }

      return true;
    } catch (e) {
      print('Error confirming receipt: $e');
      return false;
    }
  }

  // 정산 처리
  Future<void> _processSettlement(TransactionModel transaction) async {
    try {
      // 판매자 정산
      final sellerAmount = transaction.sellerAmount;
      await _client.from('settlements').insert({
        'transaction_id': transaction.id,
        'user_id': transaction.sellerId,
        'amount': sellerAmount,
        'type': '판매대금',
        'status': '정산완료',
      });

      // 대신판매자 수수료 정산
      if (transaction.isResaleTransaction && transaction.resellerId != null) {
        await _client.from('settlements').insert({
          'transaction_id': transaction.id,
          'user_id': transaction.resellerId,
          'amount': transaction.resellerCommission,
          'type': '대신판매수수료',
          'status': '정산완료',
        });
      }

      // 채팅방에 정산 완료 알림
      if (transaction.chatId != null) {
        String message = '💰 정산이 완료되었습니다.\n';
        message += '판매자 수령액: ${_formatPrice(sellerAmount)}';
        
        if (transaction.isResaleTransaction) {
          message += '\n대신판매 수수료: ${_formatPrice(transaction.resellerCommission)}';
        }

        await _chatService.sendSystemMessage(
          chatId: transaction.chatId!,
          content: message,
        );
      }
    } catch (e) {
      print('Error processing settlement: $e');
    }
  }

  // 상품 상태 업데이트
  Future<void> _updateProductStatus(String productId, String status) async {
    try {
      await _client
          .from('products')
          .update({'status': status})
          .eq('id', productId);
    } catch (e) {
      print('Error updating product status: $e');
    }
  }

  // 거래 통계 조회
  Future<Map<String, dynamic>> getTransactionStats(String userId) async {
    try {
      // 구매 통계
      final buyCount = await _client
          .from('transactions')
          .select('id')
          .eq('buyer_id', userId)
          .eq('status', TransactionStatus.completed)
          .count();

      // 판매 통계
      final sellCount = await _client
          .from('transactions')
          .select('id')
          .eq('seller_id', userId)
          .eq('status', TransactionStatus.completed)
          .count();

      // 대신판매 통계
      final resellCount = await _client
          .from('transactions')
          .select('id')
          .eq('reseller_id', userId)
          .eq('status', TransactionStatus.completed)
          .count();

      return {
        'buy_count': buyCount.count ?? 0,
        'sell_count': sellCount.count ?? 0,
        'resell_count': resellCount.count ?? 0,
        'total_count': (buyCount.count ?? 0) + 
                      (sellCount.count ?? 0) + 
                      (resellCount.count ?? 0),
      };
    } catch (e) {
      print('Error getting transaction stats: $e');
      return {
        'buy_count': 0,
        'sell_count': 0,
        'resell_count': 0,
        'total_count': 0,
      };
    }
  }

  // 가격 포맷팅 헬퍼
  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }
}