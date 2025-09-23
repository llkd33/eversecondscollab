import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/models/product_model.dart';

void main() {
  group('Product Tests', () {
    test('ProductModel creation and validation', () {
      final product = ProductModel(
        id: 'test-id',
        title: 'Test Product',
        price: 10000,
        description: 'Test description',
        images: ['https://example.com/image.jpg'],
        category: '의류',
        sellerId: 'seller-id',
        resaleEnabled: true,
        resaleFee: 1000,
        resaleFeePercentage: 10.0,
        status: '판매중',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.title, 'Test Product');
      expect(product.price, 10000);
      expect(product.resaleEnabled, true);
      expect(product.resaleFee, 1000);
      expect(product.formattedPrice, '10,000원');
      expect(product.formattedResaleFee, '1,000원');
    });

    test('ProductModel fromJson parsing', () {
      final json = {
        'id': 'test-id',
        'title': 'Test Product',
        'price': 10000,
        'description': 'Test description',
        'images': ['https://example.com/image.jpg'],
        'category': '의류',
        'seller_id': 'seller-id',
        'resale_enabled': true,
        'resale_fee': 1000,
        'resale_fee_percentage': 10.0,
        'status': '판매중',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'users': {
          'name': 'Test Seller',
          'profile_image': 'https://example.com/profile.jpg'
        }
      };

      final product = ProductModel.fromJson(json);

      expect(product.title, 'Test Product');
      expect(product.price, 10000);
      expect(product.sellerName, 'Test Seller');
      expect(product.sellerProfileImage, 'https://example.com/profile.jpg');
    });

    test('ProductModel fromJson normalizes unknown categories', () {
      final now = DateTime.now().toIso8601String();
      final json = {
        'id': 'test-id-2',
        'title': 'Product With Unknown Category',
        'price': 20000,
        'images': [],
        'category': '새로운카테고리',
        'seller_id': 'seller-id',
        'resale_enabled': false,
        'resale_fee': 0,
        'resale_fee_percentage': 0,
        'status': '판매중',
        'created_at': now,
        'updated_at': now,
      };

      final product = ProductModel.fromJson(json);

      expect(product.category, ProductCategory.etc);
    });

    test('ProductModel validation errors', () {
      expect(() => ProductModel(
        id: '',
        title: 'Test',
        price: 10000,
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);

      expect(() => ProductModel(
        id: 'test-id',
        title: '',
        price: 10000,
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);

      expect(() => ProductModel(
        id: 'test-id',
        title: 'Test',
        price: -100,
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);
    });

    // ProductService test removed due to Supabase initialization requirement

    test('Product category validation', () {
      expect(ProductCategory.all.contains('의류'), true);
      expect(ProductCategory.all.contains('전자기기'), true);
      expect(ProductCategory.all.contains('생활용품'), true);
      expect(ProductCategory.all.contains('잘못된카테고리'), false);
    });

    test('Product status validation', () {
      expect(ProductStatus.isValid('판매중'), true);
      expect(ProductStatus.isValid('판매완료'), true);
      expect(ProductStatus.isValid('잘못된상태'), false);
    });

    test('Resale fee calculation', () {
      final product = ProductModel(
        id: 'test-id',
        title: 'Test Product',
        price: 10000,
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final calculatedFee = product.calculateResaleFee(15.0);
      expect(calculatedFee, 1500);
    });

    test('Product with resale enabled', () {
      final product = ProductModel(
        id: 'test-id',
        title: 'Test Product with Resale',
        price: 50000,
        description: 'Test description for resale product',
        images: ['https://example.com/image1.jpg', 'https://example.com/image2.jpg'],
        category: '전자기기',
        sellerId: 'seller-id',
        resaleEnabled: true,
        resaleFee: 7500, // 15% of 50000
        resaleFeePercentage: 15.0,
        status: '판매중',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.resaleEnabled, true);
      expect(product.resaleFee, 7500);
      expect(product.resaleFeePercentage, 15.0);
      expect(product.resellerCommission, 7500);
      expect(product.sellerAmount, 42500);
      expect(product.thumbnailImage, 'https://example.com/image1.jpg');
    });

    test('Product validation with edge cases', () {
      // Test maximum price
      expect(() => ProductModel(
        id: 'test-id',
        title: 'Expensive Product',
        price: 200000000, // Over 100M limit
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);

      // Test invalid resale fee percentage
      expect(() => ProductModel(
        id: 'test-id',
        title: 'Test Product',
        price: 10000,
        images: [],
        category: '의류',
        sellerId: 'seller-id',
        resaleFeePercentage: 150.0, // Over 100%
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ), throwsArgumentError);
    });
  });
}
