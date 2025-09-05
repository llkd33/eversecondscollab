import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/safe_transaction_model.dart';
import '../models/transaction_model.dart';
import 'chat_service.dart';
import 'sms_service.dart';

class SafeTransactionService {
  final SupabaseClient _client = SupabaseConfig.client;
  final ChatService _chatService = ChatService();
  final SMSService _smsService = SMSService();

  // 안전거래 생성
  Future<SafeTransactionModel?> createSafeTransaction({
    required String transactionId,
    required int depositAmount,
  }) async {
    try {
      final response = await _client.from('safe_transactions').insert({
        'transaction_id': transactionId,
        'deposit_amount': depositAmount,
        'deposit_confirmed': false,
        'shipping_confirmed': false,
        'delivery_confirmed': false,
        'settlement_status': SettlementStatus.waiting,
      }).select().single();

      return SafeTransactionModel.fromJson(response);
    } catch (e) {
      print('Error creating safe transaction: $e');
      return null;
    }
  }

  // 안전거래 ID로 조회
  Future<SafeTransactionModel?> getSafeTransactionById(String safeTransactionId) async {
    try {
      final response = await _client
          .from('safe_transactions')
          .select('''
            *,
            transactions!transaction_id (
              *,
              products!product_id (title),
              buyer:users!buyer_id (name, phone),
              seller:users!seller_id (name, phone)
            )
          ''')
          .eq('id', safeTransactionId)
          .single();

      final safeTransaction = SafeTransactionModel.fromJson(response);
      
      // 조인된 정보 매핑
      final transaction = response['transactions'];
      if (transaction != null) {
        final product = transaction['products'];
        final buyer = transaction['buyer'];
        final seller = transaction['seller'];

        return safeTransaction.copyWith(
          productTitle: product?['title'],
          buyerName: buyer?['name'],
          buyerPhone: buyer?['phone'],
          sellerName: seller?['name'],
          sellerPhone: seller?['phone'],
        );
      }
      
      return safeTransaction;
    } catch (e) {
      print('Error getting safe transaction by id: $e');
      return null;
    }
  }

  // 거래 ID로 안전거래 조회
  Future<SafeTransactionModel?> getSafeTransactionByTransactionId(String transactionId) async {
    try {
      final response = await _client
          .from('safe_transactions')
          .select('''
            *,
            transactions!transaction_id (
              *,
              products!product_id (title),
              buyer:users!buyer_id (name, phone),
              seller:users!seller_id (name, phone)
            )
          ''')
          .eq('transaction_id', transactionId)
          .single();

      final safeTransaction = SafeTransactionModel.fromJson(response);
      
      // 조인된 정보 매핑
      final transaction = response['transactions'];
      if (transaction != null) {
        final product = transaction['products'];
        final buyer = transaction['buyer'];
        final seller = transaction['seller'];

        return safeTransaction.copyWith(
          productTitle: product?['title'],
          buyerName: buyer?['name'],
          buyerPhone: buyer?['phone'],
          sellerName: seller?['name'],
          sellerPhone: seller?['phone'],
        );
      }
      
      return safeTransaction;
    } catch (e) {
      print('Error getting safe transaction by transaction id: $e');
      return null;
    }
  }

  // 입금확인 요청 (구매자)
  Future<bool> requestDepositConfirmation({
    required String safeTransactionId,
    required String buyerPhone,
    required String productTitle,
    required int depositAmount,
  }) async {
    try {
      // 관리자에게 SMS 발송
      final adminMessage = '입금확인 요청\n'
          '상품: $productTitle\n'
          '금액: ${_formatPrice(depositAmount)}\n'
          '구매자: $buyerPhone\n'
          '확인 후 어드민에서 처리해주세요.';

      await _smsService.sendSMSToAdmin(
        message: adminMessage,
        type: '입금확인요청',
      );

      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'admin_notes': '입금확인 요청됨 - ${DateTime.now().toIso8601String()}',
          })
          .eq('id', safeTransactionId);

      return true;
    } catch (e) {
      print('Error requesting deposit confirmation: $e');
      return false;
    }
  }

  // 입금 확인 (관리자)
  Future<bool> confirmDeposit({
    required String safeTransactionId,
    String? adminNotes,
  }) async {
    try {
      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'deposit_confirmed': true,
            'deposit_confirmed_at': DateTime.now().toIso8601String(),
            'admin_notes': adminNotes ?? '입금 확인 완료',
          })
          .eq('id', safeTransactionId);

      // 안전거래 정보 조회
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) return false;

      // 판매자와 대신판매자에게 SMS 발송
      if (safeTransaction.sellerPhone != null) {
        final sellerMessage = '입금이 확인되었습니다.\n'
            '상품: ${safeTransaction.productTitle ?? '상품'}\n'
            '금액: ${safeTransaction.formattedDepositAmount}\n'
            '상품을 발송해주세요.';

        await _smsService.sendSMS(
          phoneNumber: safeTransaction.sellerPhone!,
          message: sellerMessage,
          type: '입금확인',
        );
      }

      // 채팅방에 시스템 메시지 전송
      await _chatService.sendDepositConfirmedMessage(
        safeTransaction.transactionId,
      );

      return true;
    } catch (e) {
      print('Error confirming deposit: $e');
      return false;
    }
  }

  // 배송 시작 확인 (판매자)
  Future<bool> confirmShipping({
    required String safeTransactionId,
    String? trackingNumber,
    String? courier,
  }) async {
    try {
      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'shipping_confirmed': true,
            'shipping_confirmed_at': DateTime.now().toIso8601String(),
            'admin_notes': '배송 시작 - 운송장: ${trackingNumber ?? 'N/A'}',
          })
          .eq('id', safeTransactionId);

      // 안전거래 정보 조회
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) return false;

      // 구매자에게 배송 정보 SMS 발송
      if (safeTransaction.buyerPhone != null) {
        String buyerMessage = '상품이 발송되었습니다.\n'
            '상품: ${safeTransaction.productTitle ?? '상품'}\n';
        
        if (trackingNumber != null) {
          buyerMessage += '운송장번호: $trackingNumber\n';
        }
        if (courier != null) {
          buyerMessage += '택배사: $courier\n';
        }
        
        buyerMessage += '상품 수령 후 완료 버튼을 눌러주세요.';

        await _smsService.sendSMS(
          phoneNumber: safeTransaction.buyerPhone!,
          message: buyerMessage,
          type: '배송시작',
        );
      }

      // 채팅방에 시스템 메시지 전송
      await _chatService.sendShippingStartedMessage(
        safeTransaction.transactionId,
      );

      return true;
    } catch (e) {
      print('Error confirming shipping: $e');
      return false;
    }
  }

  // 배송 완료 확인 (구매자)
  Future<bool> confirmDelivery({
    required String safeTransactionId,
  }) async {
    try {
      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'delivery_confirmed': true,
            'delivery_confirmed_at': DateTime.now().toIso8601String(),
            'settlement_status': SettlementStatus.preparing,
          })
          .eq('id', safeTransactionId);

      // 안전거래 정보 조회
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) return false;

      // 회사에 거래 정상 처리 SMS 발송
      final companyMessage = '거래 정상 완료\n'
          '상품: ${safeTransaction.productTitle ?? '상품'}\n'
          '금액: ${safeTransaction.formattedDepositAmount}\n'
          '구매자: ${safeTransaction.buyerName ?? 'N/A'}\n'
          '정산 처리를 진행해주세요.';

      await _smsService.sendSMSToAdmin(
        message: companyMessage,
        type: '거래완료',
      );

      // 채팅방에 시스템 메시지 전송
      await _chatService.sendTransactionCompletedMessage(
        safeTransaction.transactionId,
      );

      return true;
    } catch (e) {
      print('Error confirming delivery: $e');
      return false;
    }
  }

  // 정산 처리 (관리자)
  Future<bool> processSettlement({
    required String safeTransactionId,
    String? adminNotes,
  }) async {
    try {
      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'settlement_status': SettlementStatus.completed,
            'admin_notes': adminNotes ?? '정산 처리 완료',
          })
          .eq('id', safeTransactionId);

      // 거래 상태를 완료로 업데이트
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction != null) {
        await _client
            .from('transactions')
            .update({
              'status': TransactionStatus.completed,
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', safeTransaction.transactionId);
      }

      return true;
    } catch (e) {
      print('Error processing settlement: $e');
      return false;
    }
  }

  // 관리자용 안전거래 목록 조회
  Future<List<SafeTransactionModel>> getAllSafeTransactions({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from('safe_transactions')
          .select('''
            *,
            transactions!transaction_id (
              *,
              products!product_id (title),
              buyer:users!buyer_id (name, phone),
              seller:users!seller_id (name, phone)
            )
          ''');

      if (status != null) {
        query = query.eq('settlement_status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((item) {
        final safeTransaction = SafeTransactionModel.fromJson(item);
        
        // 조인된 정보 매핑
        final transaction = item['transactions'];
        if (transaction != null) {
          final product = transaction['products'];
          final buyer = transaction['buyer'];
          final seller = transaction['seller'];

          return safeTransaction.copyWith(
            productTitle: product?['title'],
            buyerName: buyer?['name'],
            buyerPhone: buyer?['phone'],
            sellerName: seller?['name'],
            sellerPhone: seller?['phone'],
          );
        }
        
        return safeTransaction;
      }).toList();
    } catch (e) {
      print('Error getting all safe transactions: $e');
      return [];
    }
  }

  // 안전거래 통계 조회
  Future<Map<String, dynamic>> getSafeTransactionStats() async {
    try {
      // 전체 안전거래 수
      final totalCount = await _client
          .from('safe_transactions')
          .select('id')
          .count();

      // 입금 대기중
      final waitingDepositCount = await _client
          .from('safe_transactions')
          .select('id')
          .eq('deposit_confirmed', false)
          .count();

      // 배송 대기중
      final waitingShippingCount = await _client
          .from('safe_transactions')
          .select('id')
          .eq('deposit_confirmed', true)
          .eq('shipping_confirmed', false)
          .count();

      // 배송중
      final shippingCount = await _client
          .from('safe_transactions')
          .select('id')
          .eq('shipping_confirmed', true)
          .eq('delivery_confirmed', false)
          .count();

      // 정산 대기중
      final waitingSettlementCount = await _client
          .from('safe_transactions')
          .select('id')
          .eq('settlement_status', SettlementStatus.waiting)
          .count();

      // 정산 완료
      final completedCount = await _client
          .from('safe_transactions')
          .select('id')
          .eq('settlement_status', SettlementStatus.completed)
          .count();

      return {
        'total_count': totalCount.count ?? 0,
        'waiting_deposit_count': waitingDepositCount.count ?? 0,
        'waiting_shipping_count': waitingShippingCount.count ?? 0,
        'shipping_count': shippingCount.count ?? 0,
        'waiting_settlement_count': waitingSettlementCount.count ?? 0,
        'completed_count': completedCount.count ?? 0,
      };
    } catch (e) {
      print('Error getting safe transaction stats: $e');
      return {};
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