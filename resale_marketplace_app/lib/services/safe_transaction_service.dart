import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/safe_transaction_model.dart';
import '../models/transaction_model.dart';
import 'chat_service.dart';
import 'sms_service.dart';
import '../utils/uuid.dart';

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
      if (!UuidUtils.isValid(transactionId)) {
        throw Exception('잘못된 거래 ID입니다.');
      }
      // 이미 안전거래가 존재하는지 확인
      final existing = await getSafeTransactionByTransactionId(transactionId);
      if (existing != null) {
        throw Exception('이미 안전거래가 생성되어 있습니다.');
      }

      // 거래 정보 확인
      final transactionResponse = await _client
          .from('transactions')
          .select('status, price')
          .eq('id', transactionId)
          .single();

      final transactionStatus = transactionResponse['status'] as String;
      final transactionPrice = transactionResponse['price'] as int;

      if (transactionStatus != '거래중') {
        throw Exception('거래중인 상태에서만 안전거래를 생성할 수 있습니다.');
      }

      if (depositAmount != transactionPrice) {
        throw Exception('입금 금액이 거래 금액과 일치하지 않습니다.');
      }

      // 거래 타입을 안전거래로 업데이트
      await _client
          .from('transactions')
          .update({'transaction_type': '안전거래'})
          .eq('id', transactionId);

      // 안전거래 생성
      final response = await _client
          .from('safe_transactions')
          .insert({
            'transaction_id': transactionId,
            'deposit_amount': depositAmount,
            'deposit_confirmed': false,
            'shipping_confirmed': false,
            'delivery_confirmed': false,
            'settlement_status': SettlementStatus.waiting,
            'admin_notes': '안전거래 생성됨 - ${DateTime.now().toIso8601String()}',
          })
          .select()
          .single();

      return SafeTransactionModel.fromJson(response);
    } catch (e) {
      print('Error creating safe transaction: $e');
      rethrow;
    }
  }

  // 안전거래 ID로 조회
  Future<SafeTransactionModel?> getSafeTransactionById(
    String safeTransactionId,
  ) async {
    try {
      if (!UuidUtils.isValid(safeTransactionId)) {
        print(
          'getSafeTransactionById skipped: invalid UUID "$safeTransactionId"',
        );
        return null;
      }
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
  Future<SafeTransactionModel?> getSafeTransactionByTransactionId(
    String transactionId,
  ) async {
    try {
      if (!UuidUtils.isValid(transactionId)) {
        print(
          'getSafeTransactionByTransactionId skipped: invalid UUID "$transactionId"',
        );
        return null;
      }
      final response = await _client
          .from('safe_transactions')
          .select('''
            *,
            transactions!transaction_id (
              *,
              products!product_id (title),
              buyer:users!buyer_id (name, phone),
              seller:users!seller_id (name, phone),
              reseller:users!reseller_id (name, phone)
            )
          ''')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (response == null) return null;

      final safeTransaction = SafeTransactionModel.fromJson(response);

      // 조인된 정보 매핑
      final transaction = response['transactions'];
      if (transaction != null) {
        final product = transaction['products'];
        final buyer = transaction['buyer'];
        final seller = transaction['seller'];
        final reseller = transaction['reseller'];

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
      if (!UuidUtils.isValid(safeTransactionId)) {
        throw Exception('잘못된 안전거래 ID입니다.');
      }
      // 안전거래 정보 조회
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) {
        throw Exception('안전거래 정보를 찾을 수 없습니다.');
      }

      // 이미 입금확인 요청이 된 경우 체크
      if (safeTransaction.adminNotes?.contains('입금확인 요청됨') == true) {
        throw Exception('이미 입금확인 요청이 처리되었습니다.');
      }

      // 관리자에게 SMS 발송
      final adminMessage =
          '💰 입금확인 요청\n'
          '상품: $productTitle\n'
          '금액: ${_formatPrice(depositAmount)}\n'
          '구매자: ${safeTransaction.buyerName ?? 'N/A'} ($buyerPhone)\n'
          '어드민에서 확인 후 처리해주세요.';

      final smsSuccess = await _smsService.sendSMSToAdmin(
        message: adminMessage,
        type: '입금확인요청',
      );

      if (!smsSuccess) {
        throw Exception('SMS 발송에 실패했습니다.');
      }

      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'admin_notes': '입금확인 요청됨 - ${DateTime.now().toIso8601String()}',
          })
          .eq('id', safeTransactionId);

      // 채팅방에 시스템 메시지 전송 (거래의 chat_id 사용)
      final txRow = await _client
          .from('transactions')
          .select('chat_id')
          .eq('id', safeTransaction.transactionId)
          .single();
      final chatId = txRow['chat_id'] as String?;
      if (chatId != null) {
        await _chatService.sendSystemMessage(
          chatId: chatId,
          content: '💰 입금확인 요청이 전송되었습니다.\n관리자가 확인 후 처리해드립니다.',
        );
      }

      return true;
    } catch (e) {
      print('Error requesting deposit confirmation: $e');
      rethrow;
    }
  }

  // 입금 확인 (관리자)
  Future<bool> confirmDeposit({
    required String safeTransactionId,
    String? adminNotes,
  }) async {
    try {
      if (!UuidUtils.isValid(safeTransactionId)) {
        throw Exception('잘못된 안전거래 ID입니다.');
      }
      // 안전거래 정보 조회
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) {
        throw Exception('안전거래 정보를 찾을 수 없습니다.');
      }

      // 이미 입금확인된 경우 체크
      if (safeTransaction.depositConfirmed) {
        throw Exception('이미 입금이 확인되었습니다.');
      }

      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'deposit_confirmed': true,
            'deposit_confirmed_at': DateTime.now().toIso8601String(),
            'admin_notes':
                adminNotes ?? '입금 확인 완료 - ${DateTime.now().toIso8601String()}',
          })
          .eq('id', safeTransactionId);

      // 거래 정보 조회 (채팅방 ID 가져오기)
      final transactionResponse = await _client
          .from('transactions')
          .select('chat_id, reseller_id')
          .eq('id', safeTransaction.transactionId)
          .single();

      final chatId = transactionResponse['chat_id'] as String?;
      final resellerId = transactionResponse['reseller_id'] as String?;

      // 판매자에게 SMS 발송
      if (safeTransaction.sellerPhone != null) {
        final sellerMessage =
            '✅ 입금이 확인되었습니다.\n'
            '상품: ${safeTransaction.productTitle ?? '상품'}\n'
            '금액: ${safeTransaction.formattedDepositAmount}\n'
            '상품을 발송해주세요.';

        await _smsService.sendSMS(
          phoneNumber: safeTransaction.sellerPhone!,
          message: sellerMessage,
          type: '입금확인',
        );
      }

      // 대신판매자가 있는 경우 SMS 발송
      if (resellerId != null) {
        // 대신판매자 정보 조회
        final resellerResponse = await _client
            .from('users')
            .select('name, phone')
            .eq('id', resellerId)
            .single();

        final resellerPhone = resellerResponse['phone'] as String?;
        if (resellerPhone != null) {
          final resellerMessage =
              '✅ 입금이 확인되었습니다.\n'
              '상품: ${safeTransaction.productTitle ?? '상품'}\n'
              '대신판매 수수료 정산이 예정되어 있습니다.';

          await _smsService.sendSMS(
            phoneNumber: resellerPhone,
            message: resellerMessage,
            type: '입금확인',
          );
        }
      }

      // 채팅방에 시스템 메시지 전송
      if (chatId != null) {
        await _chatService.sendSystemMessage(
          chatId: chatId,
          content: '✅ 입금이 확인되었습니다.\n판매자가 상품을 발송할 예정입니다.',
        );
      }

      return true;
    } catch (e) {
      print('Error confirming deposit: $e');
      rethrow;
    }
  }

  // 배송 시작 확인 (판매자)
  Future<bool> confirmShipping({
    required String safeTransactionId,
    String? trackingNumber,
    String? courier,
  }) async {
    try {
      if (!UuidUtils.isValid(safeTransactionId)) {
        throw Exception('잘못된 안전거래 ID입니다.');
      }
      // 안전거래 정보 조회
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) {
        throw Exception('안전거래 정보를 찾을 수 없습니다.');
      }

      // 입금확인이 되지 않은 경우 체크
      if (!safeTransaction.depositConfirmed) {
        throw Exception('입금확인이 완료되지 않았습니다.');
      }

      // 이미 배송확인된 경우 체크
      if (safeTransaction.shippingConfirmed) {
        throw Exception('이미 배송이 확인되었습니다.');
      }

      // 배송 정보 구성
      String shippingInfo = '배송 시작';
      if (trackingNumber != null) {
        shippingInfo += ' - 운송장: $trackingNumber';
      }
      if (courier != null) {
        shippingInfo += ' ($courier)';
      }
      shippingInfo += ' - ${DateTime.now().toIso8601String()}';

      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'shipping_confirmed': true,
            'shipping_confirmed_at': DateTime.now().toIso8601String(),
            'admin_notes': shippingInfo,
          })
          .eq('id', safeTransactionId);

      // 거래 정보 조회 (채팅방 ID 가져오기)
      final transactionResponse = await _client
          .from('transactions')
          .select('chat_id')
          .eq('id', safeTransaction.transactionId)
          .single();

      final chatId = transactionResponse['chat_id'] as String?;

      // 구매자에게 배송 정보 SMS 발송
      if (safeTransaction.buyerPhone != null) {
        String buyerMessage =
            '📦 상품이 발송되었습니다.\n'
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
      if (chatId != null) {
        String chatMessage = '📦 상품이 발송되었습니다.';
        if (trackingNumber != null) {
          chatMessage += '\n운송장번호: $trackingNumber';
        }
        if (courier != null) {
          chatMessage += '\n택배사: $courier';
        }
        chatMessage += '\n상품 수령 후 완료 버튼을 눌러주세요.';

        await _chatService.sendSystemMessage(
          chatId: chatId,
          content: chatMessage,
        );
      }

      return true;
    } catch (e) {
      print('Error confirming shipping: $e');
      rethrow;
    }
  }

  // 배송 완료 확인 (구매자)
  Future<bool> confirmDelivery({required String safeTransactionId}) async {
    try {
      // 안전거래 정보 조회
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) {
        throw Exception('안전거래 정보를 찾을 수 없습니다.');
      }

      // 배송확인이 되지 않은 경우 체크
      if (!safeTransaction.shippingConfirmed) {
        throw Exception('배송이 시작되지 않았습니다.');
      }

      // 이미 배송완료 확인된 경우 체크
      if (safeTransaction.deliveryConfirmed) {
        throw Exception('이미 배송완료가 확인되었습니다.');
      }

      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'delivery_confirmed': true,
            'delivery_confirmed_at': DateTime.now().toIso8601String(),
            'settlement_status': SettlementStatus.preparing,
            'admin_notes': '배송완료 확인됨 - ${DateTime.now().toIso8601String()}',
          })
          .eq('id', safeTransactionId);

      // 거래 정보 조회 (채팅방 ID 가져오기)
      final transactionResponse = await _client
          .from('transactions')
          .select('chat_id')
          .eq('id', safeTransaction.transactionId)
          .single();

      final chatId = transactionResponse['chat_id'] as String?;

      // 회사에 거래 정상 처리 SMS 발송
      final companyMessage =
          '✅ 거래가 정상 완료되었습니다.\n'
          '상품: ${safeTransaction.productTitle ?? '상품'}\n'
          '금액: ${safeTransaction.formattedDepositAmount}\n'
          '구매자: ${safeTransaction.buyerName ?? 'N/A'}\n'
          '판매자: ${safeTransaction.sellerName ?? 'N/A'}\n'
          '정산 처리를 진행해주세요.';

      await _smsService.sendSMSToAdmin(message: companyMessage, type: '거래완료');

      // 채팅방에 시스템 메시지 전송
      if (chatId != null) {
        await _chatService.sendSystemMessage(
          chatId: chatId,
          content: '✅ 거래가 완료되었습니다.\n정산 처리가 진행됩니다.',
        );
      }

      return true;
    } catch (e) {
      print('Error confirming delivery: $e');
      rethrow;
    }
  }

  // 정산 처리 (관리자)
  Future<bool> processSettlement({
    required String safeTransactionId,
    String? adminNotes,
  }) async {
    try {
      if (!UuidUtils.isValid(safeTransactionId)) {
        throw Exception('잘못된 안전거래 ID입니다.');
      }
      // 안전거래 정보 조회
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) {
        throw Exception('안전거래 정보를 찾을 수 없습니다.');
      }

      // 배송완료 확인이 되지 않은 경우 체크
      if (!safeTransaction.deliveryConfirmed) {
        throw Exception('배송완료 확인이 되지 않았습니다.');
      }

      // 이미 정산완료된 경우 체크
      if (safeTransaction.settlementStatus == SettlementStatus.completed) {
        throw Exception('이미 정산이 완료되었습니다.');
      }

      // 거래 정보 조회 (수수료 및 대신판매자 정보)
      final transactionResponse = await _client
          .from('transactions')
          .select('reseller_id, resale_fee, chat_id')
          .eq('id', safeTransaction.transactionId)
          .single();

      final resellerId = transactionResponse['reseller_id'] as String?;
      final resaleFee = transactionResponse['resale_fee'] as int? ?? 0;
      final chatId = transactionResponse['chat_id'] as String?;

      // 안전거래 상태 업데이트
      await _client
          .from('safe_transactions')
          .update({
            'settlement_status': SettlementStatus.completed,
            'admin_notes':
                adminNotes ?? '정산 처리 완료 - ${DateTime.now().toIso8601String()}',
          })
          .eq('id', safeTransactionId);

      // 거래 상태를 완료로 업데이트
      await _client
          .from('transactions')
          .update({
            'status': '거래완료',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', safeTransaction.transactionId);

      // 대신판매자가 있는 경우 수수료 정산 SMS 발송
      if (resellerId != null && resaleFee > 0) {
        final resellerResponse = await _client
            .from('users')
            .select('name, phone')
            .eq('id', resellerId)
            .single();

        final resellerPhone = resellerResponse['phone'] as String?;
        if (resellerPhone != null) {
          final commissionMessage =
              '💰 대신판매 수수료가 정산되었습니다.\n'
              '상품: ${safeTransaction.productTitle ?? '상품'}\n'
              '수수료: ${_formatPrice(resaleFee)}\n'
              '감사합니다.';

          await _smsService.sendSMS(
            phoneNumber: resellerPhone,
            message: commissionMessage,
            type: '수수료정산',
          );
        }
      }

      // 채팅방에 시스템 메시지 전송
      if (chatId != null) {
        await _chatService.sendSystemMessage(
          chatId: chatId,
          content: '🎉 정산이 완료되었습니다.\n거래가 성공적으로 마무리되었습니다.',
        );
      }

      return true;
    } catch (e) {
      print('Error processing settlement: $e');
      rethrow;
    }
  }

  // 관리자용 안전거래 목록 조회
  Future<List<SafeTransactionModel>> getAllSafeTransactions({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('safe_transactions').select('''
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

  // 안전거래 전환 가능 여부 확인
  Future<bool> canConvertToSafeTransaction(String transactionId) async {
    try {
      // 거래 정보 확인
      final transactionResponse = await _client
          .from('transactions')
          .select('status, transaction_type')
          .eq('id', transactionId)
          .single();

      final status = transactionResponse['status'] as String;
      final transactionType =
          transactionResponse['transaction_type'] as String?;

      // 이미 안전거래인 경우
      if (transactionType == '안전거래') {
        return false;
      }

      // 거래중인 상태에서만 전환 가능
      if (status != '거래중') {
        return false;
      }

      // 이미 안전거래가 생성된 경우
      final existingSafeTransaction = await getSafeTransactionByTransactionId(
        transactionId,
      );
      if (existingSafeTransaction != null) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking safe transaction conversion: $e');
      return false;
    }
  }

  // 안전거래 진행 단계 확인
  Future<Map<String, dynamic>> getSafeTransactionProgress(
    String safeTransactionId,
  ) async {
    try {
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) {
        throw Exception('안전거래 정보를 찾을 수 없습니다.');
      }

      return {
        'current_step': safeTransaction.currentStep,
        'progress': safeTransaction.progress,
        'progress_percent': safeTransaction.progressPercent,
        'can_settle': safeTransaction.canSettle,
        'is_completed': safeTransaction.isCompleted,
        'steps': {
          'deposit_confirmed': safeTransaction.depositConfirmed,
          'shipping_confirmed': safeTransaction.shippingConfirmed,
          'delivery_confirmed': safeTransaction.deliveryConfirmed,
          'settlement_status': safeTransaction.settlementStatus,
        },
        'timestamps': {
          'deposit_confirmed_at': safeTransaction.depositConfirmedAt
              ?.toIso8601String(),
          'shipping_confirmed_at': safeTransaction.shippingConfirmedAt
              ?.toIso8601String(),
          'delivery_confirmed_at': safeTransaction.deliveryConfirmedAt
              ?.toIso8601String(),
        },
      };
    } catch (e) {
      print('Error getting safe transaction progress: $e');
      rethrow;
    }
  }

  // 안전거래 취소 (거래 시작 전에만 가능)
  Future<bool> cancelSafeTransaction(
    String safeTransactionId,
    String reason,
  ) async {
    try {
      final safeTransaction = await getSafeTransactionById(safeTransactionId);
      if (safeTransaction == null) {
        throw Exception('안전거래 정보를 찾을 수 없습니다.');
      }

      // 입금확인 전에만 취소 가능
      if (safeTransaction.depositConfirmed) {
        throw Exception('입금확인 후에는 취소할 수 없습니다.');
      }

      // 안전거래 삭제
      await _client
          .from('safe_transactions')
          .delete()
          .eq('id', safeTransactionId);

      // 거래 타입을 일반거래로 변경
      await _client
          .from('transactions')
          .update({'transaction_type': '일반거래'})
          .eq('id', safeTransaction.transactionId);

      // 거래 정보 조회 (채팅방 ID 가져오기)
      final transactionResponse = await _client
          .from('transactions')
          .select('chat_id')
          .eq('id', safeTransaction.transactionId)
          .single();

      final chatId = transactionResponse['chat_id'] as String?;

      // 채팅방에 시스템 메시지 전송
      if (chatId != null) {
        await _chatService.sendSystemMessage(
          chatId: chatId,
          content: '❌ 안전거래가 취소되었습니다.\n사유: $reason',
        );
      }

      return true;
    } catch (e) {
      print('Error canceling safe transaction: $e');
      rethrow;
    }
  }

  // 가격 포맷팅 헬퍼
  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  }
}
