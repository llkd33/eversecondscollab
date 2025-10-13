import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 🔐 Encryption Configuration
/// Manages encryption keys securely from environment variables
class EncryptionConfig {
  static String get encryptionKey {
    final key = dotenv.env['ENCRYPTION_KEY'];

    if (key == null || key.isEmpty) {
      throw Exception(
        '❌ ENCRYPTION_KEY not found in .env file.\n'
        'Please add ENCRYPTION_KEY to your .env file.\n'
        'Generate a secure key with: openssl rand -base64 32'
      );
    }

    if (key == 'CHANGE_THIS_TO_SECURE_RANDOM_KEY_32_CHARS') {
      throw Exception(
        '❌ Default ENCRYPTION_KEY detected!\n'
        'Please change ENCRYPTION_KEY in .env to a secure random key.\n'
        'Generate one with: openssl rand -base64 32'
      );
    }

    if (key.length < 32) {
      throw Exception(
        '❌ ENCRYPTION_KEY is too short (must be at least 32 characters).\n'
        'Generate a secure key with: openssl rand -base64 32'
      );
    }

    return key;
  }

  /// Print configuration info (debug only)
  static void printDebugInfo() {
    if (kDebugMode) {
      print('🔐 Encryption Configuration:');
      print('  - Key configured: ${dotenv.env['ENCRYPTION_KEY'] != null}');
      print('  - Key length: ${dotenv.env['ENCRYPTION_KEY']?.length ?? 0}');
      print('  - Using secure key: ${dotenv.env['ENCRYPTION_KEY'] != 'CHANGE_THIS_TO_SECURE_RANDOM_KEY_32_CHARS'}');
    }
  }
}
