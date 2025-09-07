import '../models/user_model.dart';

class TestSession {
  static bool enabled = false;
  static UserModel? user;

  static void start(UserModel u) {
    enabled = true;
    user = u;
  }

  static void clear() {
    enabled = false;
    user = null;
  }
}

