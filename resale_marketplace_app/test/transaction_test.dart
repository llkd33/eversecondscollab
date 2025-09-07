import 'package:flutter_test/flutter_test.dart';
import '../lib/models/transaction_model.dart';

void main() {

  group('TransactionModel Tests', () {
    test('should create transaction model with valid data', () {
      // Arrange & Act
      final transaction = TransactionModel(
        id: 'test-id',
        productId: 'product-id',
        price: 50000,
        resaleFee: 5000,
        buyerId: 'buyer-id',
        sellerId: 'seller-id',
        resellerId: 'reseller-id',
        status: TransactionStatus.ongoing,
        transactionType: TransactionType.safe,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(transaction.id, equals('test-id'));
      expect(transaction.price, equals(50000));
      expect(transaction.resaleFee, equals(5000));
      expect(transaction.isResaleTransaction, isTrue);
      expect(transaction.isSafeTransaction, isTrue);
      expect(transaction.sellerAmount, equals(45000));
      expect(transaction.resellerCommission, equals(5000));
    });

    test('should validate transaction data', () {
      // Assert - Invalid data should throw ArgumentError
      expect(
        () => TransactionModel(
          id: '',
          productId: 'product-id',
          price: 50000,
          buyerId: 'buyer-id',
          sellerId: 'seller-id',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => TransactionModel(
          id: 'test-id',
          productId: 'product-id',
          price: -1000,
          buyerId: 'buyer-id',
          sellerId: 'seller-id',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => TransactionModel(
          id: 'test-id',
          productId: 'product-id',
          price: 50000,
          buyerId: 'same-user-id',
          sellerId: 'same-user-id',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('should convert to/from JSON correctly', () {
      // Arrange
      final transaction = TransactionModel(
        id: 'test-id',
        productId: 'product-id',
        price: 50000,
        resaleFee: 5000,
        buyerId: 'buyer-id',
        sellerId: 'seller-id',
        resellerId: 'reseller-id',
        status: TransactionStatus.completed,
        transactionType: TransactionType.safe,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );

      // Act
      final json = transaction.toJson();
      final fromJson = TransactionModel.fromJson(json);

      // Assert
      expect(fromJson.id, equals(transaction.id));
      expect(fromJson.price, equals(transaction.price));
      expect(fromJson.resaleFee, equals(transaction.resaleFee));
      expect(fromJson.status, equals(transaction.status));
      expect(fromJson.transactionType, equals(transaction.transactionType));
    });

    test('should format prices correctly', () {
      // Arrange
      final transaction = TransactionModel(
        id: 'test-id',
        productId: 'product-id',
        price: 1234567,
        resaleFee: 123456,
        buyerId: 'buyer-id',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
      );

      // Assert
      expect(transaction.formattedPrice, equals('1,234,567원'));
      expect(transaction.formattedResaleFee, equals('123,456원'));
    });

    test('should handle copyWith correctly', () {
      // Arrange
      final original = TransactionModel(
        id: 'test-id',
        productId: 'product-id',
        price: 50000,
        buyerId: 'buyer-id',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
      );

      // Act
      final updated = original.copyWith(
        status: TransactionStatus.completed,
        completedAt: DateTime.now(),
      );

      // Assert
      expect(updated.id, equals(original.id));
      expect(updated.status, equals(TransactionStatus.completed));
      expect(updated.completedAt, isNotNull);
      expect(original.status, equals(TransactionStatus.ongoing));
      expect(original.completedAt, isNull);
    });
  });

  group('Transaction Status and Type Tests', () {
    test('should validate transaction status', () {
      expect(TransactionStatus.isValid('거래중'), isTrue);
      expect(TransactionStatus.isValid('거래완료'), isTrue);
      expect(TransactionStatus.isValid('거래중단'), isTrue);
      expect(TransactionStatus.isValid('invalid-status'), isFalse);
    });

    test('should validate transaction type', () {
      expect(TransactionType.isValid('일반거래'), isTrue);
      expect(TransactionType.isValid('안전거래'), isTrue);
      expect(TransactionType.isValid('invalid-type'), isFalse);
    });

    test('should contain all status values', () {
      expect(TransactionStatus.all, contains('거래중'));
      expect(TransactionStatus.all, contains('거래완료'));
      expect(TransactionStatus.all, contains('거래중단'));
      expect(TransactionStatus.all, hasLength(3));
    });

    test('should contain all type values', () {
      expect(TransactionType.all, contains('일반거래'));
      expect(TransactionType.all, contains('안전거래'));
      expect(TransactionType.all, hasLength(2));
    });
  });
}