# 🔐 Everseconds 어드민 접속 가이드

## 📱 어드민 접속 방법

### 1️⃣ **어드민 URL 접속**

**배포된 URL:**
```
https://everseconds.vercel.app/admin/web
```

또는 커스텀 도메인:
```
https://everseconds.com/admin/web
https://admin.everseconds.com
```

### 2️⃣ **관리자 계정 설정**

#### **방법 A: Supabase 대시보드에서 직접 설정**

1. [Supabase 대시보드](https://app.supabase.com) 로그인
2. 프로젝트 선택 → Table Editor → `users` 테이블
3. 관리자로 만들 사용자 찾기
4. `role` 컬럼을 `'관리자'`로 변경
5. Save

#### **방법 B: SQL로 설정**

Supabase SQL Editor에서:
```sql
-- 특정 사용자를 관리자로 변경
UPDATE users 
SET role = '관리자' 
WHERE email = 'admin@everseconds.com';

-- 또는 전화번호로
UPDATE users 
SET role = '관리자' 
WHERE phone = '010-1234-5678';
```

### 3️⃣ **관리자 권한 체크**

어드민 페이지는 자동으로 권한을 체크합니다:

```dart
// 권한 체크 로직
if (userRole != '관리자') {
  // 홈페이지로 리다이렉트
  return '/';
}
```

---

## 🎨 태블릿 QR 코드 구현

### 1️⃣ **구매 버튼 수정**

`product_detail_screen.dart`에서:

```dart
import '../../widgets/tablet_app_download.dart';

// 구매 버튼 onPressed 수정
ElevatedButton(
  onPressed: () {
    TabletPurchaseHelper.handlePurchase(
      context,
      _buyProduct, // 원래 구매 함수
    );
  },
  child: Text('구매하기'),
)
```

### 2️⃣ **자동 디바이스 감지**

태블릿 판별 기준:
- 화면 너비 ≥ 600px
- 최소 변 ≥ 600px
- 웹 브라우저 환경

### 3️⃣ **QR 코드 동작**

```
태블릿/웹 → 구매하기 클릭 → QR 코드 팝업
    ↓
QR 스캔 → 앱 스토어 or 앱 실행
```

---

## 🔧 설정 필요 사항

### 1️⃣ **의존성 설치**
```bash
flutter pub get
```

### 2️⃣ **앱 스토어 URL 설정**

`tablet_app_download.dart`에서 수정:
```dart
const String playStoreUrl = 'https://play.google.com/store/apps/details?id=실제_패키지_ID';
const String appStoreUrl = 'https://apps.apple.com/app/실제_앱_ID';
```

### 3️⃣ **유니버설 링크 설정**

서버에서 리다이렉트 설정:
```nginx
# everseconds.com/app 접속시
location /app {
  # User-Agent로 판별
  if ($http_user_agent ~* "Android") {
    return 302 https://play.google.com/store/apps/details?id=...;
  }
  if ($http_user_agent ~* "iPhone|iPad") {
    return 302 https://apps.apple.com/app/...;
  }
  # 기본: 웹 홈페이지
  return 302 /;
}
```

---

## 📊 어드민 기능 목록

### 현재 구현된 기능
- ✅ 대시보드 (실시간 통계)
- ✅ 사용자 관리
- ✅ 상품 관리
- ✅ 거래 모니터링
- ✅ 신고 관리
- ✅ 월별 차트 (수익, 거래량)
- ✅ 카테고리별 통계
- ✅ 실시간 활동 피드

### 접근 가능한 페이지
```
/admin/web          → 메인 대시보드
/admin/users        → 사용자 관리
/admin/products     → 상품 관리
/admin/transactions → 거래 관리
/admin/reports      → 신고 관리
```

---

## 🚀 빠른 시작

### 1. 관리자 만들기
```sql
-- Supabase SQL Editor에서 실행
UPDATE users 
SET role = '관리자' 
WHERE id = '사용자_UUID';
```

### 2. 어드민 접속
```
https://everseconds.vercel.app/admin/web
```

### 3. 로그인
- 관리자 계정으로 로그인
- 자동으로 대시보드 표시

---

## ⚠️ 보안 주의사항

1. **관리자 계정은 최소한으로**
   - 필요한 사람만 관리자 권한 부여
   - 정기적으로 권한 검토

2. **RLS (Row Level Security) 설정**
   ```sql
   -- 관리자만 모든 데이터 조회 가능
   CREATE POLICY "Admin access" ON users
   FOR ALL 
   USING (auth.jwt() ->> 'role' = '관리자');
   ```

3. **2FA 활성화 권장**
   - Supabase Auth에서 2FA 설정
   - 관리자 계정 추가 보안

---

## 📱 태블릿 대응 시나리오

### 일반 사용자 (태블릿)
1. 상품 페이지 접속 ✅
2. 구매하기 클릭
3. QR 코드 팝업 표시
4. 스마트폰으로 QR 스캔
5. 앱 다운로드 or 앱 실행
6. 앱에서 구매 진행

### 관리자 (태블릿/데스크톱)
1. /admin/web 접속
2. 관리자 계정 로그인
3. 대시보드 사용
4. 모든 기능 웹에서 가능

---

## 🆘 문제 해결

### Q: 관리자 로그인 후에도 홈으로 리다이렉트
**A:** `users` 테이블의 `role`이 정확히 `'관리자'`인지 확인

### Q: QR 코드가 안 나타남
**A:** 
- `flutter pub get` 실행
- `qr_flutter` 패키지 설치 확인
- 태블릿 감지 로직 확인

### Q: 어드민 페이지가 404
**A:** 
- URL이 `/admin/web`인지 확인
- 빌드가 최신인지 확인
- 라우터 설정 확인