# 관리자 시스템 고도화 가이드
# Admin System Enhancement Guide

> 에버세컨즈 관리자 시스템 전체 고도화 구현 가이드

## 📋 목차
1. [개요](#개요)
2. [새로운 기능](#새로운-기능)
3. [데이터베이스 설정](#데이터베이스-설정)
4. [서비스 구조](#서비스-구조)
5. [화면 구조](#화면-구조)
6. [사용 가이드](#사용-가이드)
7. [보안 및 권한](#보안-및-권한)
8. [문제 해결](#문제-해결)

---

## 개요

### 구현된 기능 체크리스트

✅ **1. 시스템 로그 기록**
- admin_action_logs: 관리자 액션 로그
- access_logs: 접근 로그
- error_logs: 오류 로그
- system_metrics: 시스템 메트릭

✅ **2. 데이터 백업 및 복구**
- 수동 백업 트리거
- 자동 백업 스케줄링
- 백업 이력 관리
- 복구 기능

✅ **3. 실시간 모니터링**
- Supabase Realtime 통합
- WebSocket 연결
- 실시간 알림

✅ **4. 통계 대시보드 고도화**
- fl_chart 차트 라이브러리
- 월별 매출 추이 라인 차트
- 신규 사용자 추이 바 차트
- 시스템 건강 상태 카드

✅ **5. 오류 로그 시각화**
- 심각도별 필터링
- 오류 상세 보기
- 해결 처리 기능

✅ **6. 알림 시스템**
- 관리자 전용 알림
- 심각도별 알림
- 실시간 푸시 알림

---

## 새로운 기능

### 1. 시스템 로그 테이블

#### admin_action_logs (관리자 액션 로그)
```sql
CREATE TABLE admin_action_logs (
  id UUID PRIMARY KEY,
  admin_id UUID REFERENCES users(id),
  action_type VARCHAR(50), -- user_update, user_delete, etc.
  target_type VARCHAR(50), -- user, transaction, product, etc.
  target_id UUID,
  action_details JSONB,
  ip_address INET,
  user_agent TEXT,
  result VARCHAR(20), -- success, failure, partial
  error_message TEXT,
  created_at TIMESTAMP
);
```

**사용 예시:**
```dart
await LoggingService().logAdminAction(
  adminId: currentUser.id,
  actionType: 'user_update',
  targetType: 'user',
  targetId: userId,
  actionDetails: {
    'changed_fields': ['role', 'status'],
    'old_values': {'role': '일반', 'status': 'active'},
    'new_values': {'role': '관리자', 'status': 'active'},
  },
);
```

#### access_logs (접근 로그)
모든 API 요청을 기록하여 시스템 사용 패턴 분석

#### error_logs (오류 로그)
심각도별 오류 추적 및 해결 관리

### 2. 백업 시스템

#### 수동 백업
```dart
final backupService = BackupService();
await backupService.createManualBackup(
  adminId: currentUserId,
  scope: 'full', // full, partial, incremental
  tables: ['users', 'products', 'transactions'],
);
```

#### 자동 백업 스케줄
```dart
await backupService.scheduleBackup(
  schedule: '0 2 * * *', // 매일 새벽 2시
  scope: 'full',
);
```

#### 백업 복구
```dart
await backupService.restoreFromBackup(backupId);
```

### 3. 실시간 모니터링

#### Supabase Realtime 설정
```dart
final notificationService = AdminNotificationService();
await notificationService.initialize(
  userId: currentUserId,
  onNotificationReceived: (notification) {
    // 새 알림 처리
    print('새 알림: ${notification['title']}');
  },
);
```

#### 실시간 통계 업데이트
```dart
// 시스템 메트릭 자동 수집 (데이터베이스 함수)
SELECT collect_system_metrics(); -- 실행
```

### 4. 고도화된 대시보드

#### 새로운 대시보드 화면
- `advanced_dashboard_screen.dart`
- fl_chart 라이브러리 사용
- 실시간 업데이트

#### 차트 종류
1. **월별 매출 라인 차트**
   - 최근 6개월 매출 추이
   - 곡선형 라인
   - 영역 채우기

2. **신규 사용자 바 차트**
   - 월별 신규 가입자 수
   - 애니메이션 효과

3. **시스템 건강 상태**
   - 실시간 오류 카운트
   - 평균 응답 시간
   - 색상 코드 (녹색/주황/빨강)

### 5. 오류 로그 관리

#### 오류 로그 화면
```dart
// 오류 로그 조회
final errorLogs = await loggingService.getErrorLogs(
  severity: 'critical',
  resolved: false,
  limit: 50,
);

// 오류 해결 처리
await loggingService.resolveError(
  errorId: errorId,
  resolvedBy: adminId,
  resolutionNotes: '데이터베이스 연결 재설정으로 해결',
);
```

#### 오류 자동 알림
- 심각한 오류 발생 시 자동으로 관리자에게 알림
- `error_logs` 테이블에 'critical' 심각도로 로그 추가 시 트리거

### 6. 알림 시스템

#### 알림 생성
```dart
// 심각한 시스템 알림
await notificationService.createSystemAlert(
  title: '데이터베이스 연결 오류',
  message: 'Supabase 연결이 끊어졌습니다.',
  actionUrl: '/admin/system-health',
);

// 경고 알림
await notificationService.createWarning(
  title: '높은 오류 발생율',
  message: '지난 1시간 동안 50개 이상의 오류가 발생했습니다.',
  targetUsers: [adminId],
);

// 정보 알림
await notificationService.createInfo(
  title: '백업 완료',
  message: '오늘의 자동 백업이 성공적으로 완료되었습니다.',
);
```

#### 알림 읽음 처리
```dart
// 개별 알림 읽음
await notificationService.markAsRead(
  notificationId: notificationId,
  userId: currentUserId,
);

// 모두 읽음
await notificationService.markAllAsRead(userId: currentUserId);
```

---

## 데이터베이스 설정

### 1. 스키마 적용

```bash
# Supabase SQL Editor에서 실행
cd database
psql -U postgres -d your_database < admin_system_enhancement.sql
```

또는 Supabase Dashboard에서:
1. SQL Editor 열기
2. `admin_system_enhancement.sql` 내용 복사
3. Run 클릭

### 2. Row Level Security (RLS) 정책

모든 관리자 전용 테이블은 RLS가 활성화되어 있습니다:

```sql
-- 관리자만 접근 가능
CREATE POLICY "Only admins can view admin action logs" ON admin_action_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );
```

### 3. 자동 정리 함수

오래된 로그를 자동으로 정리하는 함수:

```sql
-- 수동 실행
SELECT cleanup_old_logs();

-- 또는 cron job 설정 (pg_cron 확장 필요)
SELECT cron.schedule(
  'cleanup-old-logs',
  '0 3 * * *', -- 매일 새벽 3시
  $$ SELECT cleanup_old_logs(); $$
);
```

---

## 서비스 구조

### 서비스 파일 목록

```
lib/services/
├── admin_service.dart                 # 기존 관리자 서비스
├── logging_service.dart               # 로깅 서비스 (NEW)
├── backup_service.dart                # 백업 서비스 (NEW)
├── admin_notification_service.dart    # 관리자 알림 서비스 (NEW)
└── notification_service.dart          # 기존 푸시 알림 서비스
```

### LoggingService

```dart
class LoggingService {
  // Admin Action Logs
  Future<bool> logAdminAction({...});
  Future<List<Map<String, dynamic>>> getAdminActionLogs({...});

  // Access Logs
  Future<bool> logAccess({...});
  Future<List<Map<String, dynamic>>> getAccessLogs({...});

  // Error Logs
  Future<bool> logError({...});
  Future<List<Map<String, dynamic>>> getErrorLogs({...});
  Future<bool> resolveError({...});

  // System Metrics
  Future<bool> recordMetric({...});
  Future<List<Map<String, dynamic>>> getSystemMetrics({...});

  // Statistics
  Future<Map<String, dynamic>> getLoggingStatistics({...});
}
```

### BackupService

```dart
class BackupService {
  Future<List<Map<String, dynamic>>> getBackups({...});
  Future<Map<String, dynamic>?> createManualBackup({...});
  Future<bool> scheduleBackup({...});
  Future<bool> restoreFromBackup(String backupId);
  Future<bool> deleteBackup(String backupId);
  Future<Map<String, dynamic>> getBackupStatistics();
}
```

### AdminNotificationService

```dart
class AdminNotificationService {
  Future<void> initialize({...});
  Future<Map<String, dynamic>?> createNotification({...});
  Future<List<Map<String, dynamic>>> getNotifications({...});
  Future<bool> markAsRead({...});
  Future<bool> markAllAsRead({...});
  Future<int> getUnreadCount({...});

  // Helper methods
  Future<void> createSystemAlert({...});
  Future<void> createWarning({...});
  Future<void> createInfo({...});
  Future<void> createSuccess({...});
}
```

---

## 화면 구조

### 화면 파일 목록

```
lib/screens/admin/
├── admin_dashboard_screen.dart           # 기본 대시보드
├── advanced_dashboard_screen.dart        # 고급 대시보드 (NEW)
├── error_logs_screen.dart                # 오류 로그 화면 (NEW)
├── user_management_screen.dart           # 사용자 관리
├── transaction_monitoring_screen.dart    # 거래 모니터링
└── report_management_screen.dart         # 신고 관리
```

### 라우팅 설정

```dart
// lib/utils/app_router.dart에 추가
GoRoute(
  path: '/admin/advanced',
  builder: (context, state) => const AdvancedAdminDashboardScreen(),
),
GoRoute(
  path: '/admin/error-logs',
  builder: (context, state) => const ErrorLogsScreen(),
),
```

---

## 사용 가이드

### 초기 설정

#### 1. 패키지 추가

`pubspec.yaml`에 다음 패키지 추가:

```yaml
dependencies:
  fl_chart: ^0.68.0           # 차트 라이브러리
  device_info_plus: ^10.1.0   # 디바이스 정보
  intl: ^0.19.0               # 날짜 포맷팅
```

#### 2. 데이터베이스 스키마 적용

```bash
# Supabase Dashboard SQL Editor에서 실행
admin_system_enhancement.sql
```

#### 3. 서비스 초기화

```dart
// main.dart 또는 앱 시작 시
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화
  await Supabase.initialize(...);

  // 로깅 서비스 초기화
  await LoggingService().initialize();

  runApp(MyApp());
}
```

### 일반 사용 시나리오

#### 시나리오 1: 관리자 액션 로깅

```dart
// 사용자 역할 변경 시
Future<void> updateUserRole(String userId, String newRole) async {
  final oldRole = await getUserRole(userId);

  // 역할 업데이트
  await supabase
    .from('users')
    .update({'role': newRole})
    .eq('id', userId);

  // 액션 로그 기록
  await LoggingService().logAdminAction(
    adminId: currentAdminId,
    actionType: 'user_role_update',
    targetType: 'user',
    targetId: userId,
    actionDetails: {
      'old_role': oldRole,
      'new_role': newRole,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
}
```

#### 시나리오 2: 오류 로깅

```dart
// 전역 오류 핸들러
try {
  // 작업 수행
  await performCriticalOperation();
} catch (e, stackTrace) {
  // 오류 로그 기록
  await LoggingService().logError(
    userId: currentUserId,
    errorType: 'database',
    errorCode: 'DB_CONNECTION_FAILED',
    errorMessage: e.toString(),
    stackTrace: stackTrace.toString(),
    context: {
      'operation': 'performCriticalOperation',
      'user_id': currentUserId,
    },
    severity: 'critical',
  );

  // 사용자에게 표시
  showErrorDialog(context, '작업 중 오류가 발생했습니다.');
}
```

#### 시나리오 3: 실시간 알림

```dart
// 앱 시작 시 알림 서비스 초기화
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    final currentUser = await AuthService().getCurrentUser();
    if (currentUser?.isAdmin == true) {
      await AdminNotificationService().initialize(
        userId: currentUser!.id,
        onNotificationReceived: (notification) {
          // 새 알림 처리
          _showNotificationSnackBar(notification);
        },
      );
    }
  }

  void _showNotificationSnackBar(Map<String, dynamic> notification) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(notification['message']),
        action: SnackBarAction(
          label: '보기',
          onPressed: () {
            // 알림 상세로 이동
            Navigator.pushNamed(
              context,
              notification['action_url'] ?? '/admin/notifications',
            );
          },
        ),
      ),
    );
  }
}
```

#### 시나리오 4: 정기 백업

```dart
// 백업 화면에서 수동 백업 트리거
class BackupManagementScreen extends StatefulWidget {
  // ...

  Future<void> _performBackup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('백업 중...'),
          ],
        ),
      ),
    );

    final backup = await BackupService().createManualBackup(
      adminId: currentAdminId,
      scope: 'full',
    );

    Navigator.pop(context); // 로딩 다이얼로그 닫기

    if (backup != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('백업이 성공적으로 시작되었습니다')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('백업 시작 실패'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

## 보안 및 권한

### RLS 정책

모든 관리자 테이블은 Row Level Security가 활성화되어 있습니다:

```sql
-- 관리자만 접근 가능한 정책
CREATE POLICY "admin_only" ON admin_action_logs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = '관리자'
    )
  );
```

### IP 주소 기록

모든 관리자 액션은 IP 주소와 사용자 에이전트를 기록합니다:

```dart
await LoggingService().logAdminAction(
  adminId: adminId,
  actionType: 'user_delete',
  // IP 주소는 자동으로 수집됨
);
```

### 민감 정보 보호

- 백업 파일에 비밀번호 제외
- 로그에 개인정보 마스킹
- 오류 로그에 스택 트레이스만 저장

---

## 문제 해결

### 자주 묻는 질문

#### Q1: 백업이 실패했습니다
**A:**
1. Supabase Storage 권한 확인
2. `system_backups` 테이블의 `error_message` 컬럼 확인
3. 백업 크기가 제한을 초과하지 않았는지 확인

#### Q2: 실시간 알림이 작동하지 않습니다
**A:**
1. Supabase Realtime이 활성화되어 있는지 확인
2. RLS 정책이 올바른지 확인
3. `AdminNotificationService.initialize()` 호출 확인

#### Q3: 차트가 표시되지 않습니다
**A:**
1. fl_chart 패키지 설치 확인: `flutter pub get`
2. 데이터가 올바른 형식인지 확인
3. `_monthlyStats`가 빈 리스트인지 확인

#### Q4: 오류 로그가 너무 많습니다
**A:**
자동 정리 함수를 실행하세요:
```sql
SELECT cleanup_old_logs();
```

또는 cron job 설정:
```sql
SELECT cron.schedule(
  'cleanup-logs',
  '0 3 * * *',
  $$ SELECT cleanup_old_logs(); $$
);
```

### 디버깅 팁

1. **로그 확인**
```dart
// 디버그 모드에서 자세한 로그 출력
LoggingService().logError(
  errorType: 'debug',
  errorMessage: 'Debugging information',
  context: {'data': debugData},
);
```

2. **Supabase Dashboard 활용**
- Table Editor에서 직접 데이터 확인
- SQL Editor에서 복잡한 쿼리 실행
- Logs 섹션에서 에러 추적

3. **Flutter DevTools**
- Network 탭에서 Supabase 요청 모니터링
- Performance 탭에서 차트 렌더링 성능 확인

---

## 추가 리소스

### 관련 문서
- [Supabase Documentation](https://supabase.com/docs)
- [fl_chart Documentation](https://pub.dev/packages/fl_chart)
- [Flutter Best Practices](https://flutter.dev/docs/development/best-practices)

### 커스터마이징

#### 차트 색상 변경
```dart
LineChartBarData(
  color: Colors.blue, // 원하는 색상으로 변경
  barWidth: 3,
  // ...
)
```

#### 알림 아이콘 변경
```dart
Icon(Icons.notification_important), // 원하는 아이콘으로 변경
```

#### 백업 스케줄 변경
```dart
await BackupService().scheduleBackup(
  schedule: '0 3 * * *', // cron 형식으로 스케줄 지정
);
```

---

## 라이선스

이 프로젝트는 에버세컨즈의 일부이며, 모든 권리는 에버세컨즈에 있습니다.

---

## 연락처

문제가 있거나 질문이 있으시면:
- GitHub Issues: [프로젝트 Issues 페이지]
- 이메일: [support@everseconds.com]
