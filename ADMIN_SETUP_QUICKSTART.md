# 관리자 시스템 고도화 빠른 시작 가이드
# Admin System Enhancement Quick Start

> 5분 안에 새로운 관리자 시스템을 설치하고 실행하세요

## 🚀 빠른 설치

### 1단계: 패키지 설치

`pubspec.yaml`에 다음 추가:

```yaml
dependencies:
  fl_chart: ^0.68.0
  device_info_plus: ^10.1.0
  intl: ^0.19.0
```

터미널에서 실행:
```bash
flutter pub get
```

### 2단계: 데이터베이스 스키마 적용

1. Supabase Dashboard 열기
2. SQL Editor 클릭
3. `database/admin_system_enhancement.sql` 파일 내용 복사
4. 붙여넣기 후 **Run** 클릭

### 3단계: 서비스 파일 확인

다음 파일들이 생성되었는지 확인:

```
lib/services/
├── logging_service.dart
├── backup_service.dart
└── admin_notification_service.dart

lib/screens/admin/
├── advanced_dashboard_screen.dart
└── error_logs_screen.dart
```

### 4단계: 앱에 통합

#### main.dart에 초기화 코드 추가

```dart
import 'package:flutter/material.dart';
import 'services/logging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  // 로깅 서비스 초기화
  await LoggingService().initialize();

  runApp(MyApp());
}
```

#### app_router.dart에 라우트 추가

```dart
GoRoute(
  path: '/admin/advanced',
  builder: (context, state) => const AdvancedAdminDashboardScreen(),
),
GoRoute(
  path: '/admin/error-logs',
  builder: (context, state) => const ErrorLogsScreen(),
),
```

### 5단계: 관리자 권한 설정

Supabase SQL Editor에서 실행:

```sql
-- 자신을 관리자로 설정
UPDATE users
SET role = '관리자'
WHERE phone = '당신의_전화번호';

-- 또는 email로
UPDATE users
SET role = '관리자'
WHERE email = 'your@email.com';
```

---

## ✅ 작동 확인

### 1. 고급 대시보드 접근

앱에서 `/admin/advanced` 경로로 이동하여 다음을 확인:
- ✅ 시스템 건강 상태 카드
- ✅ 월별 매출 차트
- ✅ 신규 사용자 차트
- ✅ 오류 로그 요약

### 2. 백업 테스트

대시보드에서 "수동 백업" 버튼 클릭 후:

```sql
-- Supabase에서 백업 확인
SELECT * FROM system_backups
ORDER BY started_at DESC
LIMIT 5;
```

### 3. 오류 로그 테스트

```dart
// 테스트 오류 생성
await LoggingService().logError(
  errorType: 'test',
  errorMessage: '테스트 오류입니다',
  severity: 'low',
);
```

`/admin/error-logs`에서 오류 확인

### 4. 알림 테스트

```dart
await AdminNotificationService().createInfo(
  title: '테스트 알림',
  message: '알림 시스템이 정상 작동합니다',
);
```

---

## 📊 기능 개요

### 구현된 6가지 주요 기능

| 기능 | 설명 | 파일 |
|-----|------|------|
| 1️⃣ 시스템 로그 | 모든 관리자 액션, 접근, 오류 추적 | `logging_service.dart` |
| 2️⃣ 백업/복구 | 자동/수동 데이터 백업 및 복구 | `backup_service.dart` |
| 3️⃣ 실시간 모니터링 | Supabase Realtime 통합 | `admin_notification_service.dart` |
| 4️⃣ 통계 대시보드 | 차트와 시각화된 통계 | `advanced_dashboard_screen.dart` |
| 5️⃣ 오류 로그 관리 | 심각도별 오류 추적 및 해결 | `error_logs_screen.dart` |
| 6️⃣ 알림 시스템 | 실시간 관리자 알림 | `admin_notification_service.dart` |

---

## 🎯 다음 단계

### 권장 설정

1. **자동 백업 스케줄 설정**
   ```sql
   -- 매일 새벽 2시 자동 백업
   SELECT cron.schedule(
     'daily-backup',
     '0 2 * * *',
     $$
       INSERT INTO system_backups (backup_type, backup_scope, initiated_by)
       VALUES ('automatic', 'full', (SELECT id FROM users WHERE role = '관리자' LIMIT 1));
     $$
   );
   ```

2. **오래된 로그 자동 정리**
   ```sql
   -- 매일 새벽 3시 로그 정리
   SELECT cron.schedule(
     'cleanup-logs',
     '0 3 * * *',
     $$ SELECT cleanup_old_logs(); $$
   );
   ```

3. **시스템 메트릭 자동 수집**
   ```sql
   -- 매시간 메트릭 수집
   SELECT cron.schedule(
     'collect-metrics',
     '0 * * * *',
     $$ SELECT collect_system_metrics(); $$
   );
   ```

### 커스터마이징

#### 차트 색상 변경
`advanced_dashboard_screen.dart`에서:

```dart
LineChartBarData(
  color: Colors.blue, // 원하는 색상
  // ...
)
```

#### 알림 임계값 조정
`logging_service.dart`에서:

```dart
// 심각한 오류만 알림
if (severity == 'critical' || severity == 'high') {
  await _createErrorNotification(errorType, errorMessage);
}
```

---

## 🔧 문제 해결

### 자주 발생하는 문제

#### 문제 1: "권한이 없습니다" 오류
**해결책:**
```sql
-- RLS 정책 확인
SELECT * FROM users WHERE id = auth.uid();

-- 역할 확인
SELECT role FROM users WHERE id = auth.uid();
```

#### 문제 2: 차트가 표시되지 않음
**해결책:**
1. `flutter clean`
2. `flutter pub get`
3. 앱 재시작

#### 문제 3: 백업 실패
**해결책:**
- Supabase Storage 활성화 확인
- `system_backups` 테이블의 `error_message` 확인

---

## 📚 추가 리소스

- **전체 가이드**: `ADMIN_SYSTEM_ENHANCEMENT_GUIDE.md`
- **API 문서**: 각 서비스 파일의 주석 참조
- **예제 코드**: `lib/screens/admin/` 디렉토리

---

## 🎉 완료!

모든 설정이 완료되었습니다. 이제 고도화된 관리자 시스템을 사용할 수 있습니다.

질문이 있으시면 `ADMIN_SYSTEM_ENHANCEMENT_GUIDE.md`를 참조하세요.
