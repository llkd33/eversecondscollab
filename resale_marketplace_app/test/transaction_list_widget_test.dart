import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/models/transaction_model.dart';
import 'package:resale_marketplace_app/models/user_model.dart';
import 'package:resale_marketplace_app/screens/transaction/transaction_list_screen.dart';

void main() {
  late UserModel testUser;
  late List<TransactionModel> testTransactions;

  setUpAll(() {
    final now = DateTime.now();
    testUser = UserModel(
      id: 'user-1',
      email: 'user1@example.com',
      name: 'Test User',
      phone: '010-1234-5678',
      createdAt: now,
      updatedAt: now,
    );

    testTransactions = [
      TransactionModel(
        id: 'txn-1',
        productId: 'product-1',
        price: 10000,
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        status: TransactionStatus.ongoing,
        transactionType: TransactionType.normal,
        createdAt: now,
        productTitle: '테스트 상품',
      ),
    ];
  });

  TransactionListScreen _buildScreen({
    bool deferInitialLoad = false,
    List<TransactionModel>? initialTransactions,
    Future<List<TransactionModel>> Function({
      required String userId,
      String? status,
      String? role,
    })?
    loader,
  }) {
    return TransactionListScreen(
      initialUser: testUser,
      initialTransactions: initialTransactions,
      deferInitialLoad: deferInitialLoad,
      userLoaderOverride: () async => testUser,
      transactionLoaderOverride:
          loader ??
          ({required userId, String? status, String? role}) async =>
              testTransactions,
    );
  }

  group('TransactionListScreen Widget Tests', () {
    testWidgets('should display transaction list screen with tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            deferInitialLoad: true,
            initialTransactions: testTransactions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('거래 내역'), findsOneWidget);
      expect(find.text('전체'), findsWidgets);
      expect(find.text('구매'), findsWidgets);
      expect(find.text('판매'), findsWidgets);
      expect(find.text('대신판매'), findsWidgets);
      expect(find.text('거래중'), findsWidgets);
      expect(find.text('거래완료'), findsWidgets);
      expect(find.text('거래취소'), findsWidgets);
    });

    testWidgets('should show loading indicator initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            loader: ({required userId, String? status, String? role}) async {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              return testTransactions;
            },
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
    });

    testWidgets('should switch between tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            deferInitialLoad: true,
            initialTransactions: testTransactions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('구매'));
      await tester.pumpAndSettle();
      expect(find.text('구매'), findsOneWidget);

      await tester.tap(find.text('판매'));
      await tester.pumpAndSettle();
      expect(find.text('판매'), findsOneWidget);

      await tester.tap(find.text('대신판매'));
      await tester.pumpAndSettle();
      expect(find.text('대신판매'), findsOneWidget);
    });

    testWidgets('should filter by status when chip is tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            deferInitialLoad: true,
            initialTransactions: testTransactions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ongoingChip = find.widgetWithText(FilterChip, '거래중');
      expect(ongoingChip, findsOneWidget);

      await tester.tap(ongoingChip);
      await tester.pumpAndSettle();

      expect(ongoingChip, findsOneWidget);
    });
  });
}
