# 관리자 페이지 실행 가이드
# How to Run Admin Panel

## 🚀 빠른 시작 (5분)

### 1단계: 데이터베이스 설정 ✅ COMPLETED

**Supabase Dashboard에서:**

1. https://supabase.com 접속 후 로그인
2. 프로젝트 선택
3. 왼쪽 메뉴에서 **SQL Editor** 클릭
4. **New query** 클릭
5. 아래 내용 복사 후 붙여넣기:

```bash
# 터미널에서 파일 내용 보기
cat database/admin_system_enhancement.sql
```

또는 파일 경로:
```
/Users/startuperdaniel/dev/everseconds/database/admin_system_enhancement.sql
```

6. **RUN** 클릭 → "Success" 메시지 확인

### 2단계: 패키지 설치 ✅ COMPLETED

이미 설치 완료:
- ✅ fl_chart (차트)
- ✅ device_info_plus (디바이스 정보)
- ✅ intl (날짜 포맷)

### 3단계: 관리자 계정 설정

**Supabase SQL Editor에서 실행:**

```sql
-- 자신의 전화번호로 관리자 설정
UPDATE users
SET role = '관리자'
WHERE phone = '010XXXXXXXX';  -- 본인 전화번호 입력

-- 또는 이메일로
UPDATE users
SET role = '관리자'
WHERE email = 'your@email.com';

-- 확인
SELECT id, name, phone, email, role
FROM users
WHERE role = '관리자';
```

### 4단계: 앱 실행

```bash
cd /Users/startuperdaniel/dev/everseconds/resale_marketplace_app

# 앱 실행
flutter run

# 또는 특정 디바이스로
flutter run -d chrome  # 웹
flutter run -d macos   # macOS
flutter run -d [device-id]  # 연결된 디바이스 확인: flutter devices
```

### 5단계: 관리자 페이지 접근

앱 실행 후:

#### 방법 1: URL 직접 접근 (추천)
```
/#/admin
```

#### 방법 2: 프로필에서 접근
1. 로그인
2. 프로필 화면으로 이동
3. "관리자 패널" 버튼 클릭 (관리자만 표시됨)

---

## 📊 관리자 페이지 종류

### 기본 관리자 페이지
```dart
// 경로: /admin
// 파일: lib/screens/admin/admin_dashboard_screen.dart

기능:
- 통계 요약
- 사용자 관리
- 거래 모니터링
- 신고 관리
```

### 고급 대시보드 (NEW)
```dart
// 경로: /admin/advanced
// 파일: lib/screens/admin/advanced_dashboard_screen.dart

기능:
✅ 실시간 시스템 건강 상태
✅ 월별 매출 라인 차트
✅ 신규 사용자 바 차트
✅ 오류 로그 요약
✅ 백업 상태
✅ 실시간 알림
```

### 오류 로그 화면 (NEW)
```dart
// 경로: /admin/error-logs
// 파일: lib/screens/admin/error_logs_screen.dart

기능:
✅ 심각도별 필터링
✅ 오류 상세 보기
✅ 해결 처리
```

---

## 🔧 라우팅 설정

`lib/utils/app_router.dart`에 추가:

```dart
GoRoute(
  path: '/admin',
  builder: (context, state) => const AdminDashboardScreen(),
),
GoRoute(
  path: '/admin/advanced',
  builder: (context, state) => const AdvancedAdminDashboardScreen(),
),
GoRoute(
  path: '/admin/error-logs',
  builder: (context, state) => const ErrorLogsScreen(),
),
GoRoute(
  path: '/admin/users',
  builder: (context, state) => const UserManagementScreen(),
),
GoRoute(
  path: '/admin/transactions',
  builder: (context, state) => const TransactionMonitoringScreen(),
),
GoRoute(
  path: '/admin/reports',
  builder: (context, state) => const ReportManagementScreen(),
),
```

---

## 🎯 테스트하기

### 1. 시스템 로그 테스트

```dart
// 테스트 오류 생성
await LoggingService().logError(
  errorType: 'test',
  errorMessage: '테스트 오류입니다',
  severity: 'low',
);

// 관리자 액션 로그
await LoggingService().logAdminAction(
  adminId: 'YOUR_USER_ID',
  actionType: 'test_action',
  targetType: 'system',
);
```

`/admin/error-logs`에서 확인

### 2. 알림 테스트

```dart
await AdminNotificationService().createInfo(
  title: '테스트 알림',
  message: '알림 시스템이 정상 작동합니다',
);
```

대시보드 상단 알림 아이콘 확인

### 3. 백업 테스트

1. `/admin/advanced` 이동
2. "수동 백업" 버튼 클릭
3. Supabase에서 확인:

```sql
SELECT * FROM system_backups
ORDER BY started_at DESC
LIMIT 5;
```

---

## 🔍 문제 해결

### 문제 1: "권한이 없습니다" 오류

**원인:** 사용자 역할이 '관리자'가 아님

**해결:**
```sql
UPDATE users
SET role = '관리자'
WHERE phone = '010XXXXXXXX';
```

### 문제 2: 화면이 비어있음

**원인:** 데이터가 없음

**해결:** 테스트 데이터 생성
```sql
-- 테스트 오류 로그
INSERT INTO error_logs (error_type, error_message, severity)
VALUES ('test', '테스트 오류', 'low');

-- 테스트 알림
INSERT INTO system_notifications (
  notification_type, severity, title, message
)
VALUES ('info', 'low', '테스트', '테스트 알림입니다');
```

### 문제 3: 차트가 표시되지 않음

**원인:** 월별 통계 데이터 없음

**해결:**
1. 앱을 며칠 사용하여 데이터 생성
2. 또는 테스트 데이터 삽입:

```sql
-- 테스트 거래 데이터
INSERT INTO transactions (
  product_id, price, buyer_id, seller_id, status, created_at
)
SELECT
  (SELECT id FROM products LIMIT 1),
  50000,
  (SELECT id FROM users WHERE role != '관리자' LIMIT 1),
  (SELECT id FROM users WHERE role != '관리자' OFFSET 1 LIMIT 1),
  '거래완료',
  NOW() - interval '1 month' * generate_series(0, 5)
FROM generate_series(0, 5);
```

### 문제 4: 빌드 에러

**Flutter 클린:**
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📱 화면별 접근 방법

### URL로 직접 접근

웹 브라우저나 앱에서:

```
기본 대시보드:      /#/admin
고급 대시보드:      /#/admin/advanced
오류 로그:         /#/admin/error-logs
사용자 관리:        /#/admin/users
거래 모니터링:      /#/admin/transactions
신고 관리:         /#/admin/reports
```

### 코드로 이동

```dart
// GoRouter 사용
context.push('/admin/advanced');

// 또는
context.go('/admin/error-logs');
```

---

## 🎨 커스터마이징

### 차트 색상 변경

`lib/screens/admin/advanced_dashboard_screen.dart`:

```dart
LineChartBarData(
  color: Colors.blue,  // 원하는 색상으로 변경
  barWidth: 3,
  // ...
)
```

### 알림 스타일 변경

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(notification['message']),
    backgroundColor: Colors.red,  // 배경색
    action: SnackBarAction(
      label: '보기',
      onPressed: () { /* ... */ },
    ),
  ),
);
```

---

## 📚 더 알아보기

- **전체 가이드**: `ADMIN_SYSTEM_ENHANCEMENT_GUIDE.md`
- **빠른 설치**: `ADMIN_SETUP_QUICKSTART.md`
- **기존 가이드**: `ADMIN_GUIDE.md`

---

## ✅ 체크리스트

설치 완료 확인:

- [ ] Supabase 테이블 생성됨
- [ ] Flutter 패키지 설치됨
- [ ] 관리자 계정 설정됨
- [ ] 앱 실행됨
- [ ] `/admin` 접근 가능
- [ ] `/admin/advanced` 접근 가능
- [ ] 차트 표시됨
- [ ] 알림 작동함

모두 체크되었다면 완료! 🎉

---

## 🚨 긴급 문제 시

1. 로그 확인:
```dart
print('Current user: ${await AuthService().getCurrentUser()}');
```

2. Supabase Dashboard 확인:
   - Table Editor → 데이터 확인
   - Logs → 에러 확인

3. Flutter DevTools:
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

---

## 다음 단계

관리자 시스템이 실행되면:

1. 실제 데이터 수집 시작
2. 정기 백업 스케줄 설정
3. 알림 임계값 조정
4. 커스텀 통계 추가

자세한 내용은 `ADMIN_SYSTEM_ENHANCEMENT_GUIDE.md` 참조!
