import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/screens/chat/chat_list_screen.dart';
import 'package:resale_marketplace_app/screens/chat/chat_room_screen.dart';
import 'package:resale_marketplace_app/theme/app_theme.dart';

void main() {
  group('Chat Navigation Tests', () {
    testWidgets('Navigation from chat list to chat room works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChatListScreen(),
        ),
      );

      // Verify we're on the chat list screen
      expect(find.byType(ChatListScreen), findsOneWidget);
      
      // Find and tap the first chat item
      final firstChatItem = find.byType(Card).first;
      await tester.tap(firstChatItem);
      await tester.pumpAndSettle();

      // Verify we navigated to the chat room screen
      expect(find.byType(ChatRoomScreen), findsOneWidget);
    });

    testWidgets('Chat room displays transaction buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChatRoomScreen(
            chatRoomId: 'test_room',
            userName: 'Test User',
            productTitle: 'Test Product',
          ),
        ),
      );

      // Verify transaction buttons are present
      expect(find.text('안전거래'), findsOneWidget);
      expect(find.text('운송장'), findsOneWidget);
    });

    testWidgets('Report functionality is accessible', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChatRoomScreen(
            chatRoomId: 'test_room',
            userName: 'Test User',
            productTitle: 'Test Product',
          ),
        ),
      );

      // Find and tap the menu button
      final menuButton = find.byType(PopupMenuButton<String>);
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Verify report option is available
      expect(find.text('신고하기'), findsOneWidget);
    });
  });
}