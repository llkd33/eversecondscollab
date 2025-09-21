import '../models/user_model.dart';

class TestSession {
  static bool enabled = false; // Kakao-only auth: disable test session
  static UserModel? user;

  // Create a test user with proper UUID format and phone number
  static UserModel get testUser {
    if (user == null) {
      user = UserModel(
        id: '511c365a-eb85-45d4-9706-fa6cfcedac91', // Real Supabase Auth UUID
        name: '테스트 사용자',
        email: null, // 전화번호 기반 로그인이므로 이메일은 null
        phone: '01012341234', // 유저가 지정한 실제 전화번호
        profileImage: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return user!;
  }

  static void start(UserModel u) {
    enabled = true;
    user = u;
  }

  static void clear() {
    enabled = false;
    user = null;
  }
}
