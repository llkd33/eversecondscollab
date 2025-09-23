# Admin Panel Guide / 관리자 패널 가이드

## 관리자 구조 (Admin Structure)

### 1. 관리자 접근 방법 (How to Access Admin Panel)

#### 현재 상태:
- 관리자 패널이 구현되어 있음 (`/admin` route)
- 하지만 프로필 화면에 관리자 메뉴 버튼이 없음
- URL 직접 접근만 가능: `http://localhost/#/admin`

#### 관리자 권한 필요 조건:
1. 사용자의 `role` 필드가 `'관리자'`로 설정되어야 함
2. `AdminGuard`가 권한을 체크함

### 2. 관리자 라우트 구조

```
/admin                  - 관리자 대시보드 (AdminDashboardScreen)
/admin/users           - 사용자 관리 (UserManagementScreen)  
/admin/transactions    - 거래 모니터링 (TransactionMonitoringScreen)
/admin/reports         - 신고 관리 (ReportManagementScreen)
```

### 3. 사용자를 관리자로 설정하는 방법

#### Supabase Dashboard에서 직접 수정:

1. Supabase Dashboard 접속
2. Table Editor → `users` 테이블
3. 관리자로 만들 사용자 찾기
4. `role` 필드를 `'관리자'`로 변경
5. Save

#### SQL로 수정:

```sql
UPDATE users 
SET role = '관리자'
WHERE email = 'admin@example.com';  -- 또는 phone = '01012345678'
```

### 4. 사용자 Role 종류

- `'일반'` - 일반 사용자 (기본값)
- `'대신판매자'` - 대신판매 권한이 있는 사용자
- `'관리자'` - 모든 관리 기능 접근 가능

### 5. 프로필에 관리자 메뉴 추가하기

프로필 화면에 관리자 버튼을 추가하려면 `lib/screens/profile/profile_screen.dart`에 다음 코드 추가:

```dart
// _MenuSection 위젯의 Column children에 추가
if (context.read<AuthProvider>().currentUser?.role == '관리자') 
  _MenuItem(
    icon: Icons.admin_panel_settings,
    title: '관리자 패널',
    onTap: () {
      context.push('/admin');
    },
  ),
```

### 6. 관리자 기능

#### AdminDashboardScreen:
- 전체 통계 보기
- 신규 가입자 수
- 활성 사용자 수
- 총 거래 수
- 대기 중 신고 수

#### UserManagementScreen:
- 사용자 목록 조회
- 사용자 검색
- 사용자 상태 변경
- 역할(role) 변경

#### TransactionMonitoringScreen:
- 거래 목록 조회
- 거래 상태 모니터링
- 문제 거래 확인

#### ReportManagementScreen:
- 신고 내역 조회
- 신고 처리
- 사용자 제재

### 7. 보안

- `AdminGuard`가 모든 admin 라우트를 보호
- 권한이 없으면 자동으로 로그인 페이지로 리다이렉트
- role이 '관리자'인 사용자만 접근 가능

### 8. 테스트 방법

1. 개발 중 테스트:
   - 자신의 계정을 Supabase에서 '관리자'로 변경
   - 앱에서 로그아웃 후 다시 로그인
   - 브라우저에서 `/#/admin` 접속

2. 프로덕션:
   - 특정 신뢰할 수 있는 사용자만 관리자 권한 부여
   - 정기적으로 관리자 활동 모니터링

## Quick Setup for Admin Access

```bash
# 1. Supabase SQL Editor에서 실행
UPDATE users 
SET role = '관리자'
WHERE phone = '당신의_전화번호';

# 2. 앱에서 로그아웃 후 재로그인

# 3. 브라우저에서 접속
http://localhost:포트번호/#/admin
```