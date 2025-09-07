import 'package:flutter_test/flutter_test.dart';
import '../lib/models/transaction_model.dart';
import '../lib/models/product_model.dart';

void main() {
  group('Transaction Integration Tests', () {
    test('should create and manage transaction lifecycle', () {
      // Arrange - Create a sample product
      final product = ProductModel(
        id: 'product-1',
        title: '테스트 상품',
        price: 50000,
        description: '테스트용 상품입니다',
        images: ['test-image.jpg'],
        category: '전자기기',
        sellerId: 'seller-1',
        resaleEnabled: true,
        resaleFee: 5000,
        status: '판매중',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act & Assert - Create transaction
      final transaction = TransactionModel(
        id: 'transaction-1',
        productId: product.id,
        price: product.price,
        resaleFee: product.resaleFee,
        buyerId: 'buyer-1',
        sellerId: product.sellerId,
        resellerId: 'reseller-1',
        status: TransactionStatus.ongoing,
        transactionType: TransactionType.safe,
        createdAt: DateTime.now(),
      );

      // Verify transaction properties
      expect(transaction.id, equals('transaction-1'));
      expect(transaction.productId, equals(product.id));
      expect(transaction.price, equals(50000));
      expect(transaction.resaleFee, equals(5000));
      expect(transaction.isResaleTransaction, isTrue);
      expect(transaction.isSafeTransaction, isTrue);
      expect(transaction.isOngoing, isTrue);
      expect(transaction.sellerAmount, equals(45000));
      expect(transaction.resellerCommission, equals(5000));

      // Test transaction status updates
      final completedTransaction = transaction.copyWith(
        status: TransactionStatus.completed,
        completedAt: DateTime.now(),
      );

      expect(completedTransaction.isCompleted, isTrue);
      expect(completedTransaction.isOngoing, isFalse);
      expect(completedTransaction.completedAt, isNotNull);
    });

    test('should handle different transaction types correctly', () {
      final baseTransaction = TransactionModel(
        id: 'transaction-1',
        productId: 'product-1',
        price: 100000,
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        createdAt: DateTime.now(),
      );

      // Normal transaction
      final normalTransaction = baseTransaction.copyWith(
        transactionType: TransactionType.normal,
      );
      expect(normalTransaction.isSafeTransaction, isFalse);

      // Safe transaction
      final safeTransaction = baseTransaction.copyWith(
        transactionType: TransactionType.safe,
      );
      expect(safeTransaction.isSafeTransaction, isTrue);

      // Resale transaction
      final resaleTransaction = baseTransaction.copyWith(
        resellerId: 'reseller-1',
        resaleFee: 10000,
      );
      expect(resaleTransaction.isResaleTransaction, isTrue);
      expect(resaleTransaction.sellerAmount, equals(90000));
      expect(resaleTransaction.resellerCommission, equals(10000));
    });

    test('should validate transaction data correctly', () {
      // Valid transaction
      expect(
        () => TransactionModel(
          id: 'valid-id',
          productId: 'product-1',
          price: 50000,
          buyerId: 'buyer-1',
          sellerId: 'seller-1',
          createdAt: DateTime.now(),
        ),
        returnsNormally,
      );

      // Invalid: empty ID
      expect(
        () => TransactionModel(
          id: '',
          productId: 'product-1',
          price: 50000,
          buyerId: 'buyer-1',
          sellerId: 'seller-1',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      // Invalid: negative price
      expect(
        () => TransactionModel(
          id: 'transaction-1',
          productId: 'product-1',
          price: -1000,
          buyerId: 'buyer-1',
          sellerId: 'seller-1',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      // Invalid: buyer and seller are the same
      expect(
        () => TransactionModel(
          id: 'transaction-1',
          productId: 'product-1',
          price: 50000,
          buyerId: 'same-user',
          sellerId: 'same-user',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      // Invalid: resale fee exceeds price
      expect(
        () => TransactionModel(
          id: 'transaction-1',
          productId: 'product-1',
          price: 50000,
          resaleFee: 60000,
          buyerId: 'buyer-1',
          sellerId: 'seller-1',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('should format prices correctly', () {
      final transaction = TransactionModel(
        id: 'transaction-1',
        productId: 'product-1',
        price: 1234567,
        resaleFee: 123456,
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        createdAt: DateTime.now(),
      );

      expect(transaction.formattedPrice, equals('1,234,567원'));
      expect(transaction.formattedResaleFee, equals('123,456원'));
    });

    test('should handle transaction status and type validation', () {
      // Valid statuses
      expect(TransactionStatus.isValid(TransactionStatus.ongoing), isTrue);
      expect(TransactionStatus.isValid(TransactionStatus.completed), isTrue);
      expect(TransactionStatus.isValid(TransactionStatus.canceled), isTrue);
      expect(TransactionStatus.isValid('invalid-status'), isFalse);

      // Valid types
      expect(TransactionType.isValid(TransactionType.normal), isTrue);
      expect(TransactionType.isValid(TransactionType.safe), isTrue);
      expect(TransactionType.isValid('invalid-type'), isFalse);

      // All values included
      expect(TransactionStatus.all, hasLength(3));
      expect(TransactionType.all, hasLength(2));
    });

    test('should handle JSON serialization correctly', () {
      final originalTransaction = TransactionModel(
        id: 'transaction-1',
        productId: 'product-1',
        price: 50000,
        resaleFee: 5000,
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        resellerId: 'reseller-1',
        status: TransactionStatus.completed,
        transactionType: TransactionType.safe,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
        productTitle: '테스트 상품',
        buyerName: '구매자',
        sellerName: '판매자',
        resellerName: '대신판매자',
      );

      // Convert to JSON and back
      final json = originalTransaction.toJson();
      final deserializedTransaction = TransactionModel.fromJson(json);

      // Verify all properties are preserved
      expect(deserializedTransaction.id, equals(originalTransaction.id));
      expect(deserializedTransaction.productId, equals(originalTransaction.productId));
      expect(deserializedTransaction.price, equals(originalTransaction.price));
      expect(deserializedTransaction.resaleFee, equals(originalTransaction.resaleFee));
      expect(deserializedTransaction.buyerId, equals(originalTransaction.buyerId));
      expect(deserializedTransaction.sellerId, equals(originalTransaction.sellerId));
      expect(deserializedTransaction.resellerId, equals(originalTransaction.resellerId));
      expect(deserializedTransaction.status, equals(originalTransaction.status));
      expect(deserializedTransaction.transactionType, equals(originalTransaction.transactionType));
      expect(deserializedTransaction.productTitle, equals(originalTransaction.productTitle));
      expect(deserializedTransaction.buyerName, equals(originalTransaction.buyerName));
      expect(deserializedTransaction.sellerName, equals(originalTransaction.sellerName));
      expect(deserializedTransaction.resellerName, equals(originalTransaction.resellerName));
    });

    test('should calculate revenue correctly for different scenarios', () {
      // Direct sale (no reseller)
      final directSale = TransactionModel(
        id: 'transaction-1',
        productId: 'product-1',
        price: 100000,
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        createdAt: DateTime.now(),
      );

      expect(directSale.sellerAmount, equals(100000));
      expect(directSale.resellerCommission, equals(0));
      expect(directSale.isResaleTransaction, isFalse);

      // Resale transaction
      final resaleTransaction = TransactionModel(
        id: 'transaction-2',
        productId: 'product-2',
        price: 100000,
        resaleFee: 15000,
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        resellerId: 'reseller-1',
        createdAt: DateTime.now(),
      );

      expect(resaleTransaction.sellerAmount, equals(85000));
      expect(resaleTransaction.resellerCommission, equals(15000));
      expect(resaleTransaction.isResaleTransaction, isTrue);
    });
  });
}