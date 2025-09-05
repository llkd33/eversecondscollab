import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/screens/chat/chat_list_screen.dart';
import 'package:resale_marketplace_app/screens/chat/chat_room_screen.dart';
import 'package:resale_marketplace_app/theme/app_theme.dart';

void main() {
  group('Chat System Tests', () {
    testWidgets('ChatListScreen displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChatListScreen(),
        ),
      );

      // Verify the screen loads
      expect(find.byType(ChatListScreen), findsOneWidget);
      
      // Verify chat list items are displayed
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('ChatRoomScreen displays correctly', (WidgetTester tester) async {
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

      // Verify the screen loads
      expect(find.byType(ChatRoomScreen), findsOneWidget);
      
      // Verify key UI elements
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Test Product'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Chat message input works', (WidgetTester tester) async {
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

      // Find the message input field
      final messageField = find.byType(TextField);
      expect(messageField, findsOneWidget);

      // Enter a test message
      await tester.enterText(messageField, 'Test message');
      expect(find.text('Test message'), findsOneWidget);

      // Find and tap the send button
      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pump();

      // Verify the message was sent (input should be cleared)
      expect(find.text('Test message'), findsNothing);
    });
  });
}