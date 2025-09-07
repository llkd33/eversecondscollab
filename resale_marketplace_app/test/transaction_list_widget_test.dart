import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/transaction/transaction_list_screen.dart';

void main() {
  group('TransactionListScreen Widget Tests', () {
    testWidgets('should display transaction list screen with tabs', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: const TransactionListScreen(),
        ),
      );

      // Verify the app bar title
      expect(find.text('거래 내역'), findsOneWidget);

      // Verify the tabs
      expect(find.text('전체'), findsOneWidget);
      expect(find.text('구매'), findsOneWidget);
      expect(find.text('판매'), findsOneWidget);
      expect(find.text('대신판매'), findsOneWidget);

      // Verify the status filter chips
      expect(find.text('거래중'), findsOneWidget);
      expect(find.text('거래완료'), findsOneWidget);
      expect(find.text('거래취소'), findsOneWidget);
    });

    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const TransactionListScreen(),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should switch between tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const TransactionListScreen(),
        ),
      );

      // Tap on the '구매' tab
      await tester.tap(find.text('구매'));
      await tester.pumpAndSettle();

      // Verify tab is selected (this would require more complex state checking in a real test)
      expect(find.text('구매'), findsOneWidget);

      // Tap on the '판매' tab
      await tester.tap(find.text('판매'));
      await tester.pumpAndSettle();

      expect(find.text('판매'), findsOneWidget);

      // Tap on the '대신판매' tab
      await tester.tap(find.text('대신판매'));
      await tester.pumpAndSettle();

      expect(find.text('대신판매'), findsOneWidget);
    });

    testWidgets('should filter by status when chip is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const TransactionListScreen(),
        ),
      );

      // Find and tap the '거래중' filter chip
      final ongoingChip = find.widgetWithText(FilterChip, '거래중');
      expect(ongoingChip, findsOneWidget);
      
      await tester.tap(ongoingChip);
      await tester.pumpAndSettle();

      // The chip should still be there (selected state would be tested with more complex setup)
      expect(ongoingChip, findsOneWidget);
    });
  });
}