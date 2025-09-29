import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// 🔒 계좌정보 암호화/복호화 서비스
/// AES-256-GCM 암호화를 사용하여 계좌번호를 안전하게 저장
class AccountEncryptionService {
  static const String _metadataEncryptedKey = 'account_number_encrypted';
  static const String _metadataMaskedKey = 'account_number_masked';
  static const String _metadataUpdatedAtKey = 'account_number_updated_at';

  // 🔑 암호화 키 (실제 환경에서는 환경변수나 안전한 키 관리 서비스 사용)
  static const String _baseKey = 'EverSecondsMarketplace2024!@#\$';

  // 암호화 알고리즘 설정
  static final _key = Key.fromBase64(_generateBase64Key());
  static final _encrypter = Encrypter(AES(_key, mode: AESMode.gcm));

  /// Base64 키 생성 (32바이트)
  static String _generateBase64Key() {
    final bytes = utf8.encode(_baseKey);
    final hash = sha256.convert(bytes);
    return base64.encode(hash.bytes);
  }

  /// 🔒 계좌번호 암호화
  ///
  /// [accountNumber] 암호화할 계좌번호
  /// Returns: 'iv:encrypted:tag' 형식의 문자열
  static String encryptAccountNumber(String accountNumber) {
    try {
      if (accountNumber.isEmpty) {
        throw ArgumentError('계좌번호는 비어있을 수 없습니다');
      }

      // 숫자만 추출 (하이픈, 공백 제거)
      final cleanNumber = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanNumber.isEmpty || cleanNumber.length < 8) {
        throw ArgumentError('유효하지 않은 계좌번호입니다');
      }

      // 랜덤 IV 생성 (16바이트)
      final iv = IV.fromSecureRandom(16);

      // 암호화 실행
      final encrypted = _encrypter.encrypt(cleanNumber, iv: iv);

      // IV:암호화데이터:태그 형식으로 반환
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      throw Exception('계좌번호 암호화 실패: $e');
    }
  }

  /// 🔓 계좌번호 복호화
  ///
  /// [encryptedData] 암호화된 데이터 ('iv:encrypted:tag' 형식)
  /// Returns: 복호화된 계좌번호
  static String decryptAccountNumber(String encryptedData) {
    try {
      if (encryptedData.isEmpty) {
        throw ArgumentError('암호화된 데이터가 비어있습니다');
      }

      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        throw ArgumentError('잘못된 암호화 데이터 형식입니다');
      }

      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);

      // 복호화 실행
      final decrypted = _encrypter.decrypt(encrypted, iv: iv);

      return decrypted;
    } catch (e) {
      throw Exception('계좌번호 복호화 실패: $e');
    }
  }

  /// 🎭 계좌번호 마스킹 (표시용)
  ///
  /// [accountNumber] 마스킹할 계좌번호
  /// [visibleDigits] 뒤에서 보여줄 자릿수 (기본값: 4)
  /// Returns: 마스킹된 계좌번호 (예: ****1234)
  static String maskAccountNumber(
    String accountNumber, {
    int visibleDigits = 4,
  }) {
    try {
      if (accountNumber.isEmpty) return '';

      final cleanNumber = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanNumber.length <= visibleDigits) {
        return '*' * cleanNumber.length;
      }

      final visible = cleanNumber.substring(cleanNumber.length - visibleDigits);
      final masked = '*' * (cleanNumber.length - visibleDigits);

      return '$masked$visible';
    } catch (e) {
      return '****'; // 오류 시 기본 마스킹
    }
  }

  /// ✅ 계좌번호 유효성 검증
  ///
  /// [accountNumber] 검증할 계좌번호
  /// Returns: 유효하면 true, 아니면 false
  static bool isValidAccountNumber(String accountNumber) {
    try {
      if (accountNumber.isEmpty) return false;

      final cleanNumber = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');

      // 최소 8자리, 최대 20자리
      if (cleanNumber.length < 8 || cleanNumber.length > 20) {
        return false;
      }

      // 모든 자리가 같은 숫자인지 확인 (예: 1111111111)
      if (cleanNumber.split('').toSet().length == 1) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 🎯 계좌번호 포맷팅
  ///
  /// [accountNumber] 포맷할 계좌번호
  /// Returns: 하이픈으로 구분된 계좌번호 (예: 1234-567-890123)
  static String formatAccountNumber(String accountNumber) {
    try {
      final cleanNumber = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanNumber.length <= 6) return cleanNumber;

      // 일반적인 계좌번호 패턴으로 포맷팅
      if (cleanNumber.length <= 10) {
        return '${cleanNumber.substring(0, 3)}-${cleanNumber.substring(3)}';
      } else if (cleanNumber.length <= 14) {
        return '${cleanNumber.substring(0, 4)}-${cleanNumber.substring(4, 7)}-${cleanNumber.substring(7)}';
      } else {
        return '${cleanNumber.substring(0, 4)}-${cleanNumber.substring(4, 8)}-${cleanNumber.substring(8)}';
      }
    } catch (e) {
      return accountNumber; // 오류 시 원본 반환
    }
  }

  /// 🔐 데이터 무결성 검증용 해시 생성
  ///
  /// [data] 해시할 데이터
  /// Returns: SHA-256 해시값
  static String generateDataHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 🧪 암호화/복호화 테스트
  ///
  /// 개발 환경에서 암호화 시스템이 정상 작동하는지 확인
  static bool testEncryption() {
    try {
      const testAccount = '1234567890123';

      // 암호화 테스트
      final encrypted = encryptAccountNumber(testAccount);
      print('🔒 암호화된 데이터: $encrypted');

      // 복호화 테스트
      final decrypted = decryptAccountNumber(encrypted);
      print('🔓 복호화된 데이터: $decrypted');

      // 검증
      final isValid = decrypted == testAccount;
      print('✅ 암호화/복호화 테스트: ${isValid ? '성공' : '실패'}');

      // 마스킹 테스트
      final masked = maskAccountNumber(testAccount);
      print('🎭 마스킹된 계좌번호: $masked');

      return isValid;
    } catch (e) {
      print('❌ 암호화 테스트 실패: $e');
      return false;
    }
  }

  /// 계좌 정보를 암호화하여 저장
  Future<bool> encryptAndStoreAccountNumber(
    String userId,
    String accountNumber, {
    String? bankName,
  }) async {
    try {
      final client = SupabaseConfig.client;
      final authUser = client.auth.currentUser;

      if (authUser == null) {
        throw Exception('로그인이 필요합니다');
      }
      if (authUser.id != userId) {
        throw Exception('본인 계좌정보만 저장할 수 있습니다');
      }

      final encryptedAccount = encryptAccountNumber(accountNumber);
      final maskedAccount = maskAccountNumber(accountNumber);

      final metadata = Map<String, dynamic>.from(authUser.userMetadata ?? {});
      metadata[_metadataEncryptedKey] = encryptedAccount;
      metadata[_metadataMaskedKey] = maskedAccount;
      metadata[_metadataUpdatedAtKey] = DateTime.now().toIso8601String();
      if (bankName != null && bankName.trim().isNotEmpty) {
        metadata['bank_name'] = bankName.trim();
      }

      await client.auth.updateUser(UserAttributes(data: metadata));

      return true;
    } catch (e) {
      print('계좌 정보 저장 실패: $e');
      return false;
    }
  }

  /// 저장된 계좌 정보를 복호화하여 반환
  Future<String?> decryptStoredAccountNumber(String userId) async {
    final client = SupabaseConfig.client;

    try {
      final authUser = client.auth.currentUser;
      if (authUser != null && authUser.id == userId) {
        final metadata = authUser.userMetadata ?? {};
        final encrypted = metadata[_metadataEncryptedKey];
        if (encrypted is String && encrypted.isNotEmpty) {
          return decryptAccountNumber(encrypted);
        }
      }

      // Fallback: attempt to read from users table if column exists
      try {
        final response = await client
            .from('users')
            .select('account_number_encrypted')
            .eq('id', userId)
            .maybeSingle();

        final encrypted = response?['account_number_encrypted'] as String?;
        if (encrypted != null && encrypted.isNotEmpty) {
          return decryptAccountNumber(encrypted);
        }
      } on PostgrestException catch (e) {
        final message = e.message ?? '';
        if (message.contains('account_number_encrypted')) {
          print('Users 테이블에 account_number_encrypted 컬럼이 없습니다: $message');
        } else {
          rethrow;
        }
      }

      return null;
    } catch (e) {
      print('계좌 정보 복호화 실패: $e');
      return null;
    }
  }
}

/// 📊 계좌 접근 권한 관리 서비스
class AccountAccessControl {
  /// 🔍 계좌 정보 조회 권한 확인
  ///
  /// [requestUserId] 요청하는 사용자 ID
  /// [accountOwnerId] 계좌 소유자 ID
  /// [transactionId] 관련 거래 ID (선택사항)
  /// Returns: 접근 권한이 있으면 true
  static bool canViewAccount(
    String requestUserId,
    String accountOwnerId, {
    String? transactionId,
  }) {
    try {
      // 1. 본인 계좌는 항상 접근 가능
      if (requestUserId == accountOwnerId) return true;

      // 2. 거래 당사자는 상대방 계좌 확인 가능
      if (transactionId != null) {
        return _isTransactionParticipant(requestUserId, transactionId);
      }

      // 3. 기본적으로는 접근 불가
      return false;
    } catch (e) {
      // 오류 발생시 안전하게 접근 거부
      return false;
    }
  }

  /// 🤝 거래 당사자 확인
  ///
  /// [userId] 확인할 사용자 ID
  /// [transactionId] 거래 ID
  /// Returns: 거래 당사자이면 true
  static bool _isTransactionParticipant(String userId, String transactionId) {
    // TODO: 실제 DB에서 거래 정보 조회하여 확인
    // 현재는 임시로 true 반환 (실제 구현 필요)
    return true;
  }

  /// 🛡️ 관리자 권한 확인
  ///
  /// [userId] 확인할 사용자 ID
  /// Returns: 관리자이면 true
  static bool isAdmin(String userId) {
    // TODO: 실제 DB에서 사용자 역할 확인
    // 현재는 임시로 false 반환 (실제 구현 필요)
    return false;
  }

  /// 📝 접근 로그 기록
  ///
  /// [userId] 접근한 사용자 ID
  /// [accountOwnerId] 계좌 소유자 ID
  /// [action] 수행한 작업
  /// [success] 성공 여부
  static void logAccess(
    String userId,
    String accountOwnerId,
    String action,
    bool success,
  ) {
    // TODO: 실제 로그 시스템에 기록
    final timestamp = DateTime.now().toIso8601String();
    print(
      '📋 계좌접근로그 [$timestamp]: $userId -> $accountOwnerId ($action) ${success ? '성공' : '실패'}',
    );
  }
}

/// 📱 사용 예시 및 상수 정의
class AccountConstants {
  // 🏦 지원되는 은행 목록
  static const List<String> supportedBanks = [
    'KB국민은행',
    '신한은행',
    '우리은행',
    '하나은행',
    'KEB하나은행',
    'NH농협은행',
    'IBK기업은행',
    '부산은행',
    '경남은행',
    '광주은행',
    '전북은행',
    '제주은행',
    '대구은행',
    'SC제일은행',
    '한국씨티은행',
    '카카오뱅크',
    '케이뱅크',
    '토스뱅크',
    '우체국',
    '새마을금고',
    '신협',
    '산업은행',
    '수협은행',
    '저축은행',
  ];

  // 📏 계좌번호 제한
  static const int minAccountLength = 8;
  static const int maxAccountLength = 20;
  static const int defaultMaskingDigits = 4;

  // 🔒 암호화 설정
  static const String encryptionAlgorithm = 'AES-256-GCM';
  static const int ivLength = 16; // bytes
  static const int keyLength = 32; // bytes
}
