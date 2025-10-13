import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// 📱 알림 선호도 관리 서비스
/// 사용자별 알림 설정을 서버에 저장하고 관리
class NotificationPreferencesService {
  static final NotificationPreferencesService _instance = 
      NotificationPreferencesService._internal();
  factory NotificationPreferencesService() => _instance;
  NotificationPreferencesService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  /// 🔄 사용자 알림 설정 불러오기
  Future<Map<String, bool>> getUserPreferences(String userId) async {
    try {
      final response = await _supabase
          .from('user_notification_preferences')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // 기본 설정 반환
        return {
          'chat_notifications': true,
          'transaction_notifications': true,
          'resale_notifications': true,
          'promotion_notifications': false,
          'system_notifications': true,
        };
      }

      return {
        'chat_notifications': response['chat_notifications'] ?? true,
        'transaction_notifications': response['transaction_notifications'] ?? true,
        'resale_notifications': response['resale_notifications'] ?? true,
        'promotion_notifications': response['promotion_notifications'] ?? false,
        'system_notifications': response['system_notifications'] ?? true,
      };
    } catch (e) {
      print('알림 설정 로드 실패: $e');
      // 에러 시 기본 설정 반환
      return {
        'chat_notifications': true,
        'transaction_notifications': true,
        'resale_notifications': true,
        'promotion_notifications': false,
        'system_notifications': true,
      };
    }
  }

  /// 💾 사용자 알림 설정 저장
  Future<bool> updatePreference(String userId, String type, bool enabled) async {
    try {
      await _supabase.from('user_notification_preferences').upsert({
        'user_id': userId,
        type: enabled,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('알림 설정 저장 성공: $type = $enabled');
      return true;
    } catch (e) {
      print('알림 설정 저장 실패: $e');
      return false;
    }
  }

  /// 🚫 방해 금지 시간 설정
  Future<bool> setDoNotDisturbHours(String userId, int startHour, int endHour) async {
    try {
      await _supabase.from('user_notification_preferences').upsert({
        'user_id': userId,
        'dnd_start_hour': startHour,
        'dnd_end_hour': endHour,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('방해 금지 시간 설정 실패: $e');
      return false;
    }
  }

  /// ⏰ 현재 시간이 방해 금지 시간인지 확인
  Future<bool> isDoNotDisturbTime(String userId) async {
    try {
      final response = await _supabase
          .from('user_notification_preferences')
          .select('dnd_start_hour, dnd_end_hour')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return false;

      final startHour = response['dnd_start_hour'] as int?;
      final endHour = response['dnd_end_hour'] as int?;

      if (startHour == null || endHour == null) return false;

      final now = DateTime.now();
      final currentHour = now.hour;

      // 같은 날 내 시간 범위
      if (startHour < endHour) {
        return currentHour >= startHour && currentHour < endHour;
      }
      // 다음 날로 넘어가는 시간 범위
      else {
        return currentHour >= startHour || currentHour < endHour;
      }
    } catch (e) {
      print('방해 금지 시간 확인 실패: $e');
      return false;
    }
  }

  /// 🔍 알림 허용 여부 검사
  Future<bool> shouldSendNotification(String userId, String notificationType) async {
    try {
      // 방해 금지 시간 확인
      if (await isDoNotDisturbTime(userId)) {
        return false;
      }

      // 알림 타입별 설정 확인
      final preferences = await getUserPreferences(userId);
      return preferences[notificationType] ?? false;
    } catch (e) {
      print('알림 허용 여부 확인 실패: $e');
      return true; // 에러 시 기본적으로 허용
    }
  }
}