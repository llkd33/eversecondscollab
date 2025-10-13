import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/app_download_config.dart';

class AppSettingsService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<AppDownloadConfig> fetchAppDownloadConfig() async {
    try {
      final response = await _client
          .from('app_download_settings')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return AppDownloadConfig.fromJson(response);
      }
    } on PostgrestException catch (e) {
      if (e.code == '42P01') {
        debugPrint('app_download_settings 테이블을 찾을 수 없습니다. 기본값을 사용합니다.');
      } else {
        debugPrint('앱 다운로드 설정 조회 실패: ${e.message}');
      }
    } catch (e) {
      debugPrint('앱 다운로드 설정 조회 중 오류: $e');
    }

    return AppDownloadConfig.defaults();
  }

  Future<bool> upsertAppDownloadConfig(AppDownloadConfig config) async {
    try {
      final payload = config
          .copyWith(
            id: config.id ?? 'default',
            updatedAt: DateTime.now(),
          )
          .toJson();

      await _client.from('app_download_settings').upsert(payload);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('앱 다운로드 설정 저장 실패: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('앱 다운로드 설정 저장 중 오류: $e');
      return false;
    }
  }
}
