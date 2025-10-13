import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/models/transaction_model.dart';

void main() {
  group('TransactionModel', () {
    test('should create valid transaction', () {
      final transaction = TransactionModel(
        id: 'txn_123',
        productId: 'prod_123',
        price: 100000,
        buyerId: 'buyer_123',
        sellerId: 'seller_123',
        createdAt: DateTime.now(),
      );

      expect(transaction.id, equals('txn_123'));
      expect(transaction.price, equals(100000));
      expect(transaction.status, equals('거래중'));
    });

    test('should throw on empty id', () {
      expect(
        () => TransactionModel(
          id: '',
          productId: 'prod_123',
          price: 100000,
          buyerId: 'buyer_123',
          sellerId: 'seller_123',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw on same buyer and seller', () {
      expect(
        () => TransactionModel(
          id: 'txn_123',
          productId: 'prod_123',
          price: 100000,
          buyerId: 'user_123',
          sellerId: 'user_123',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw on negative price', () {
      expect(
        () => TransactionModel(
          id: 'txn_123',
          productId: 'prod_123',
          price: -1000,
          buyerId: 'buyer_123',
          sellerId: 'seller_123',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw on negative resale fee', () {
      expect(
        () => TransactionModel(
          id: 'txn_123',
          productId: 'prod_123',
          price: 100000,
          resaleFee: -1000,
          buyerId: 'buyer_123',
          sellerId: 'seller_123',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw if resale fee exceeds price', () {
      expect(
        () => TransactionModel(
          id: 'txn_123',
          productId: 'prod_123',
          price: 100000,
          resaleFee: 150000,
          buyerId: 'buyer_123',
          sellerId: 'seller_123',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should calculate seller amount correctly', () {
      final transaction = TransactionModel(
        id: 'txn_123',
        productId: 'prod_123',
        price: 100000,
        resaleFee: 10000,
        buyerId: 'buyer_123',
        sellerId: 'seller_123',
        resellerId: 'reseller_123',
        createdAt: DateTime.now(),
      );

      expect(transaction.sellerAmount, equals(90000));
      expect(transaction.resellerCommission, equals(10000));
      expect(transaction.isResaleTransaction, isTrue);
    });

    test('should format price correctly', () {
      final transaction = TransactionModel(
        id: 'txn_123',
        productId: 'prod_123',
        price: 1234567,
        buyerId: 'buyer_123',
        sellerId: 'seller_123',
        createdAt: DateTime.now(),
      );

      expect(transaction.formattedPrice, equals('1,234,567원'));
    });

    test('should convert to and from JSON', () {
      final now = DateTime.now();
      final transaction = TransactionModel(
        id: 'txn_123',
        productId: 'prod_123',
        price: 100000,
        resaleFee: 10000,
        buyerId: 'buyer_123',
        sellerId: 'seller_123',
        resellerId: 'reseller_123',
        status: '거래완료',
        createdAt: now,
      );

      final json = transaction.toJson();
      final restored = TransactionModel.fromJson(json);

      expect(restored.id, equals(transaction.id));
      expect(restored.price, equals(transaction.price));
      expect(restored.resaleFee, equals(transaction.resaleFee));
      expect(restored.buyerId, equals(transaction.buyerId));
      expect(restored.sellerId, equals(transaction.sellerId));
      expect(restored.resellerId, equals(transaction.resellerId));
      expect(restored.status, equals(transaction.status));
    });

    test('should validate transaction status', () {
      expect(TransactionStatus.isValid('거래중'), isTrue);
      expect(TransactionStatus.isValid('거래완료'), isTrue);
      expect(TransactionStatus.isValid('거래중단'), isTrue);
      expect(TransactionStatus.isValid('invalid'), isFalse);
    });

    test('should validate transaction type', () {
      expect(TransactionType.isValid('일반거래'), isTrue);
      expect(TransactionType.isValid('안전거래'), isTrue);
      expect(TransactionType.isValid('invalid'), isFalse);
    });
  });
}
