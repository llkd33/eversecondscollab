# 🌐 웹 기반 관리자 패널 가이드
# Web-Based Admin Panel Guide

> **웹 브라우저에서 강력한 관리자 대시보드를 사용하세요!**

## 🎯 개요

에버세컨즈는 **두 가지 관리자 인터페이스**를 제공합니다:

### 1. 📱 모바일 관리자 패널
- **경로**: `/#/admin`
- **용도**: 모바일 앱에서 빠른 관리 작업
- **특징**: 모바일 최적화된 간단한 인터페이스

### 2. 🖥️ 웹 관리자 대시보드 (추천!)
- **경로**: `/#/admin/web`
- **용도**: 웹 브라우저에서 전체 관리 기능
- **특징**:
  - 📊 실시간 차트와 그래프
  - 🎨 반응형 대시보드 레이아웃
  - 📈 고급 통계 분석
  - 🔍 검색 및 필터링
  - 📋 사용자/상품/거래 관리
  - 🚨 실시간 신고 모니터링

---

## 🚀 웹 관리자 시작하기

### 1단계: 데이터베이스 설정 (이미 완료했다면 건너뛰기)

```bash
# Supabase SQL Editor에서 실행
파일: COMPLETE_ADMIN_SETUP.sql
```

### 2단계: 관리자 계정 설정

```sql
UPDATE users
SET role = '관리자'
WHERE phone = '010XXXXXXXX';
```

### 3단계: 웹 앱 실행

```bash
cd /Users/startuperdaniel/dev/everseconds/resale_marketplace_app

# 웹 브라우저로 실행
flutter run -d chrome

# 또는 웹 빌드
flutter build web
```

### 4단계: 웹 관리자 접속

브라우저에서:
```
http://localhost:8080/#/admin/web
```

또는 배포된 사이트에서:
```
https://your-domain.com/#/admin/web
```

---

## 📊 웹 관리자 기능

### 🏠 대시보드 (Dashboard)
**경로**: `/#/admin/web`

**주요 기능**:
- ✅ 실시간 통계 카드
  - 총 사용자 / 활성 사용자
  - 총 상품 / 총 거래
  - 매출 통계

- ✅ 월별 거래 추이 차트 (Line Chart)
- ✅ 카테고리별 판매 차트 (Pie Chart)
- ✅ 실시간 신고 현황
- ✅ 최근 활동 피드

### 👥 사용자 관리 (User Management)

**기능**:
- 사용자 목록 조회
- 사용자 검색
- 권한 관리
- 계정 상태 변경
- 사용자 통계

### 📦 상품 관리 (Product Management)

**기능**:
- 모든 상품 조회
- 상품 검색 및 필터링
- 상품 승인/거부
- 부적절한 상품 처리
- 카테고리별 통계

### 💳 거래 관리 (Transaction Management)

**기능**:
- 거래 내역 조회
- 거래 상태 추적
- 분쟁 처리
- 환불 관리
- 거래 통계

### 🚨 신고 관리 (Report Management)

**기능**:
- 실시간 신고 모니터링
- 신고 처리 (승인/거부)
- 사용자 제재
- 신고 통계
- 위험 사용자 추적

### 📈 통계 분석 (Analytics)

**기능**:
- 매출 분석
- 사용자 성장 추이
- 거래 패턴 분석
- 카테고리별 성과
- 리포트 생성

### ⚙️ 시스템 설정 (Settings)

**기능**:
- 앱 다운로드 링크 설정
- QR 코드 설정
- Google Play Store URL
- Apple App Store URL
- 시스템 구성

---

## 🎨 인터페이스 구성

### 사이드바 (Sidebar)
```
┌─────────────────────┐
│ 관리자 패널 LOGO    │
├─────────────────────┤
│ 👤 관리자 정보      │
├─────────────────────┤
│ 📊 대시보드         │
│ 👥 사용자 관리      │
│ 📦 상품 관리        │
│ 💳 거래 관리        │
│ 🚨 신고 관리        │
│ 📈 통계 분석        │
│ ⚙️  시스템 설정     │
├─────────────────────┤
│ ❓ 도움말           │
│ 🚪 로그아웃         │
└─────────────────────┘
```

### 상단 헤더 (Header)
```
┌───────────────────────────────────────────────┐
│ 페이지 제목  🔍 검색...  🔔 알림  🔄 새로고침 │
└───────────────────────────────────────────────┘
```

### 메인 콘텐츠 (Main Content)
- 반응형 그리드 레이아웃
- 카드 기반 UI
- 인터랙티브 차트
- 실시간 데이터 업데이트

---

## 📱 반응형 디자인

### 데스크톱 (>1024px)
✅ 웹 관리자 대시보드 표시
- 완전한 사이드바
- 다중 컬럼 레이아웃
- 큰 차트와 그래프

### 태블릿/모바일 (<1024px)
✅ 자동으로 `/admin`으로 리다이렉트
- 모바일 최적화 인터페이스
- 단순화된 레이아웃
- 터치 친화적

---

## 🔒 보안 및 권한

### 접근 제어

**라우트 가드** (app_router.dart:107-119):
```dart
if (isAdminPath) {
  if (!isAuthenticated) {
    return '/login?redirect=${Uri.encodeComponent(currentPath)}';
  }
  final userRole = authProvider.currentUser?.role ?? '';
  if (!['관리자'].contains(userRole)) {
    return '/?error=access_denied';
  }
}
```

### 권한 확인

**웹 관리자** (web_admin_dashboard.dart:75-89):
```dart
Future<void> _checkAdminAccess() async {
  final user = await _authService.getCurrentUser();

  if (user == null || !user.isAdmin) {
    context.go('/login');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('관리자 권한이 필요합니다'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  // ...
}
```

---

## 🧪 테스트하기

### 1. 테스트 데이터 생성

```sql
-- Supabase SQL Editor에서 실행
-- 파일: TEST_DATA.sql
```

이 스크립트는 다음을 생성합니다:
- 4개의 테스트 오류 로그 (low, medium, high, critical)
- 4개의 테스트 알림 (info, warning, error, critical)
- 5개의 접근 로그
- 4개의 시스템 지표
- 3개의 백업 기록

### 2. 대시보드 확인

웹 관리자 접속 후:
1. ✅ 통계 카드에 데이터 표시됨
2. ✅ 차트가 정상 렌더링됨
3. ✅ 최근 활동이 표시됨
4. ✅ 알림이 작동함

---

## 🎯 실제 배포

### 웹 호스팅 옵션

#### 1. Firebase Hosting (추천)
```bash
# Firebase 설치
npm install -g firebase-tools

# Firebase 로그인
firebase login

# 프로젝트 초기화
firebase init hosting

# 빌드 및 배포
flutter build web
firebase deploy --only hosting
```

#### 2. Vercel
```bash
# Vercel CLI 설치
npm install -g vercel

# 빌드
flutter build web

# 배포
cd build/web
vercel --prod
```

#### 3. Netlify
```bash
# 빌드
flutter build web

# Netlify에서:
# - build/web 폴더를 드래그 & 드롭
# - 또는 Git 연동
```

#### 4. GitHub Pages
```bash
# 빌드
flutter build web --base-href "/repository-name/"

# GitHub Pages 활성화
# Settings > Pages > Source: gh-pages branch
```

---

## 🔧 커스터마이징

### 색상 테마 변경

**파일**: `lib/theme/app_theme.dart`
```dart
static const Color primaryColor = Color(0xFF6C63FF); // 변경
static const Color secondaryColor = Color(0xFF4CAF50); // 변경
```

### 사이드바 메뉴 항목 추가

**파일**: `lib/screens/admin/web_admin_dashboard.dart:356-411`
```dart
_buildMenuItem(
  icon: Icons.your_icon,
  title: '새 메뉴',
  index: 8, // 다음 인덱스
  badge: null,
),
```

### 새로운 대시보드 페이지 추가

1. 메뉴 항목 추가 (위와 같음)
2. `_buildContent()` 메서드에 케이스 추가:
```dart
case 8:
  return _buildYourNewPage();
```
3. 페이지 빌더 메서드 구현:
```dart
Widget _buildYourNewPage() {
  return Container(
    padding: const EdgeInsets.all(30),
    child: Text('Your New Page'),
  );
}
```

---

## 🐛 문제 해결

### 문제 1: "관리자 권한이 필요합니다"

**원인**: 사용자 역할이 '관리자'가 아님

**해결**:
```sql
UPDATE users
SET role = '관리자'
WHERE phone = 'YOUR_PHONE';
```

### 문제 2: 웹 앱이 시작되지 않음

**원인**: Flutter 웹 지원이 활성화되지 않음

**해결**:
```bash
flutter config --enable-web
flutter clean
flutter pub get
flutter run -d chrome
```

### 문제 3: 차트가 표시되지 않음

**원인**: 데이터가 없음

**해결**: `TEST_DATA.sql` 실행

### 문제 4: 모바일에서 웹 관리자 보임

**원인**: 화면 크기 감지 오류

**해결**: 웹 관리자는 자동으로 >1024px에서만 표시됩니다. 모바일에서는 `/admin`으로 리다이렉트됩니다.

---

## 📊 성능 최적화

### 1. 데이터 캐싱
```dart
// 통계 데이터 캐싱
Timer.periodic(Duration(minutes: 5), (_) {
  _loadStatistics();
});
```

### 2. 레이지 로딩
```dart
// 무한 스크롤 구현
ScrollController _scrollController = ScrollController();

_scrollController.addListener(() {
  if (_scrollController.position.pixels ==
      _scrollController.position.maxScrollExtent) {
    _loadMore();
  }
});
```

### 3. 이미지 최적화
```dart
// 최적화된 이미지 로딩
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

---

## 📈 모니터링

### 실시간 알림

**기능**: 중요한 이벤트 발생 시 알림
- 🚨 신규 신고
- ⚠️ 시스템 오류
- 📊 일일 리포트

### 통계 대시보드

**주요 지표**:
- DAU (Daily Active Users)
- MAU (Monthly Active Users)
- 거래 완료율
- 평균 거래 금액
- 신고 해결율

---

## ✅ 체크리스트

웹 관리자 준비 완료:

- [ ] 데이터베이스 설정 완료 (`COMPLETE_ADMIN_SETUP.sql`)
- [ ] 관리자 계정 설정 완료
- [ ] 테스트 데이터 생성 (`TEST_DATA.sql`)
- [ ] Flutter 웹 앱 실행 (`flutter run -d chrome`)
- [ ] `/#/admin/web` 접근 가능
- [ ] 대시보드에 데이터 표시됨
- [ ] 차트가 정상 작동함
- [ ] 모든 메뉴 탐색 가능

---

## 🎉 완료!

이제 강력한 웹 기반 관리자 대시보드를 사용할 수 있습니다!

**주요 경로**:
- **웹 관리자**: `/#/admin/web` (1024px 이상)
- **모바일 관리자**: `/#/admin` (1024px 미만)

**관련 파일**:
- 웹 대시보드: `lib/screens/admin/web_admin_dashboard.dart`
- 라우팅: `lib/utils/app_router.dart`
- 서비스: `lib/services/admin_service.dart`

---

**마지막 업데이트**: 2025-10-29
**버전**: 1.0
