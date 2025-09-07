import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/models/product_model.dart';
import 'package:resale_marketplace_app/services/product_service.dart';

void main() {
  group('Product Creation Tests', () {
    test('Product creation with resale enabled', () {
      // Test data
      const title = 'Test Product';
      const price = 50000;
      const description = 'This is a test product description with more than 10 characters';
      const category = '의류';
      const sellerId = 'test-seller-id';
      const resaleFeePercentage = 15.0;
      
      // Calculate expected resale fee
      final expectedResaleFee = (price * resaleFeePercentage / 100).round();
      
      // Create product model
      final product = ProductModel(
        id: 'test-id',
        title: title,
        price: price,
        description: description,
        images: ['https://example.com/image1.jpg'],
        category: category,
        sellerId: sellerId,
        resaleEnabled: true,
        resaleFee: expectedResaleFee,
        resaleFeePercentage: resaleFeePercentage,
        status: '판매중',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Verify product properties
      expect(product.title, title);
      expect(product.price, price);
      expect(product.resaleEnabled, true);
      expect(product.resaleFee, expectedResaleFee);
      expect(product.resaleFeePercentage, resaleFeePercentage);
      expect(product.resellerCommission, expectedResaleFee);
      expect(product.sellerAmount, price - expectedResaleFee);
    });
    
    test('Product creation without resale', () {
      final product = ProductModel(
        id: 'test-id',
        title: 'Test Product Without Resale',
        price: 30000,
        description: 'This is a test product without resale option',
        images: ['https://example.com/image1.jpg'],
        category: '전자기기',
        sellerId: 'test-seller-id',
        resaleEnabled: false,
        resaleFee: 0,
        status: '판매중',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(product.resaleEnabled, false);
      expect(product.resaleFee, 0);
      expect(product.resellerCommission, 0);
      expect(product.sellerAmount, 30000);
    });
    
    test('Resale fee calculation validation', () {
      const price = 100000;
      const minPercentage = 5.0;
      const maxPercentage = 30.0;
      
      final minFee = (price * minPercentage / 100).round();
      final maxFee = (price * maxPercentage / 100).round();
      
      expect(minFee, 5000);
      expect(maxFee, 30000);
      
      // Test edge cases
      expect(minFee >= 100, true); // Minimum fee should be at least 100 won
      expect(maxFee <= price * 0.5, true); // Maximum fee should not exceed 50% of price
    });
    
    test('Product validation edge cases', () {
      // Test zero/negative price validation
      expect(() => ProductModel(
        id: 'test-id',
        title: 'Free Product',
        price: 0, // Zero price
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);
      
      // Test title length validation
      expect(() => ProductModel(
        id: 'test-id',
        title: '', // Empty title
        price: 10000,
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);
      
      // Test invalid category
      expect(() => ProductModel(
        id: 'test-id',
        title: 'Test Product',
        price: 10000,
        images: [],
        category: '잘못된카테고리',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);
      
      // Test valid minimum price (should not throw)
      expect(() => ProductModel(
        id: 'test-id',
        title: 'Cheap but Valid Product',
        price: 50, // Low but positive price
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), returnsNormally);
    });
    
    test('Image validation scenarios', () {
      // Test with multiple images
      final product = ProductModel(
        id: 'test-id',
        title: 'Product with Multiple Images',
        price: 25000,
        description: 'Product with multiple images for testing',
        images: [
          'https://example.com/image1.jpg',
          'https://example.com/image2.jpg',
          'https://example.com/image3.jpg',
        ],
        category: '생활용품',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(product.images.length, 3);
      expect(product.thumbnailImage, 'https://example.com/image1.jpg');
    });
  });
}