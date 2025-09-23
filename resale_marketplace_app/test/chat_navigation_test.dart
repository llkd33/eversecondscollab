import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase/supabase.dart';
import 'package:resale_marketplace_app/models/chat_model.dart';
import 'package:resale_marketplace_app/models/message_model.dart';
import 'package:resale_marketplace_app/models/user_model.dart';
import 'package:resale_marketplace_app/screens/chat/chat_list_screen.dart';
import 'package:resale_marketplace_app/screens/chat/chat_room_screen.dart';
import 'package:resale_marketplace_app/theme/app_theme.dart';
import 'package:resale_marketplace_app/services/chat_service.dart';
import 'package:resale_marketplace_app/services/auth_service.dart';

import 'realtime_chat_test.mocks.dart';

class NoopChatService extends ChatService {
  NoopChatService(SupabaseClient client) : super(client: client);

  @override
  Future<void> markChatAsRead(String chatId, String userId) async {}

  @override
  void unsubscribeFromChat(String roomId) {}
}

class NoopAuthService extends AuthService {
  NoopAuthService(SupabaseClient client, this._testUser)
    : super(client: client);

  final UserModel? _testUser;

  @override
  Future<UserModel?> getCurrentUser() async => _testUser;

  @override
  User? get currentUser => null;
}

void main() {
  late UserModel testUser;
  late List<ChatModel> testChats;
  late List<MessageModel> testMessages;

  late MockSupabaseClient mockSupabaseClient;
  late NoopChatService noopChatService;
  late NoopAuthService noopAuthService;

  setUpAll(() {
    mockSupabaseClient = MockSupabaseClient();

    final now = DateTime.now();
    testUser = UserModel(
      id: 'user-1',
      email: 'user1@example.com',
      name: 'Test User',
      phone: '010-1234-5678',
      createdAt: now,
      updatedAt: now,
    );

    testChats = [
      ChatModel(
        id: 'chat-1',
        participants: ['user-1', 'user-2'],
        productTitle: '테스트 상품',
        productPrice: 10000,
        otherUserName: 'Other User',
        lastMessage: '안녕하세요',
        lastMessageTime: now,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    testMessages = [
      MessageModel(
        id: 'message-1',
        chatId: 'chat-1',
        senderId: 'user-2',
        content: '안녕하세요',
        createdAt: now,
      ),
    ];

    noopChatService = NoopChatService(mockSupabaseClient);
    noopAuthService = NoopAuthService(mockSupabaseClient, testUser);
  });

  GoRouter _buildRouter({required List<ChatModel> chats}) {
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ChatListScreen(
            initialUser: testUser,
            initialChats: chats,
            deferInitialLoad: true,
          ),
        ),
        GoRoute(
          path: '/chat_room',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return ChatRoomScreen(
              chatRoomId: (extra['chatRoomId'] as String?) ?? 'chat-1',
              userName: (extra['userName'] as String?) ?? 'Other User',
              productTitle: (extra['productTitle'] as String?) ?? '테스트 상품',
              skipInitialization: true,
              initialMessages: testMessages,
              testCurrentUser: testUser,
              chatService: noopChatService,
              authService: noopAuthService,
            );
          },
        ),
      ],
    );
  }

  group('Chat Navigation Tests', () {
    testWidgets('Navigation from chat list to chat room works', (tester) async {
      final router = _buildRouter(chats: testChats);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatListScreen), findsOneWidget);

      final firstChatItem = find.byType(Card).first;
      await tester.tap(firstChatItem);
      await tester.pumpAndSettle();

      expect(find.byType(ChatRoomScreen), findsOneWidget);
    });

    testWidgets('Chat room displays transaction buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ChatRoomScreen(
            chatRoomId: 'test_room',
            userName: 'Test User',
            productTitle: 'Test Product',
            skipInitialization: true,
            initialMessages: testMessages,
            testCurrentUser: testUser,
            chatService: noopChatService,
            authService: noopAuthService,
          ),
        ),
      );

      expect(find.text('안전거래'), findsOneWidget);
      expect(find.text('일반거래'), findsOneWidget);
    });

    testWidgets('Report functionality is accessible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ChatRoomScreen(
            chatRoomId: 'test_room',
            userName: 'Test User',
            productTitle: 'Test Product',
            skipInitialization: true,
            initialMessages: testMessages,
            testCurrentUser: testUser,
            chatService: noopChatService,
            authService: noopAuthService,
          ),
        ),
      );

      final menuButton = find.byType(PopupMenuButton<String>);
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('신고하기'), findsOneWidget);
    });
  });
}
