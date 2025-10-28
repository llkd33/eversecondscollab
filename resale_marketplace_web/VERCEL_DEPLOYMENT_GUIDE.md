# 🚀 Vercel 배포 가이드

## 📋 배포 전 체크리스트

### ✅ 필수 파일 (모두 준비됨)
- [x] `package.json` - 프로젝트 설정
- [x] `next.config.ts` - Next.js 설정
- [x] `.gitignore` - 보안 설정
- [x] `vercel.json` - Vercel 배포 설정
- [x] `src/app/` - 앱 페이지
- [x] `public/` - 정적 파일

### ⚠️ 환경변수 (Vercel에 등록 필요)
```bash
NEXT_PUBLIC_SUPABASE_URL=https://ewhurbwdqiemeuwdtpeg.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOi...
```

---

## 🚀 배포 방법 (3가지)

### 방법 1: Vercel CLI (권장) ⭐

**1단계: Vercel CLI 설치**
```bash
npm install -g vercel
```

**2단계: 프로젝트 폴더로 이동**
```bash
cd /Users/startuperdaniel/dev/everseconds/resale_marketplace_web
```

**3단계: 로그인 & 배포**
```bash
# 로그인 (브라우저 열림)
vercel login

# 첫 배포 (설정 질문 나옴)
vercel

# 운영 배포
vercel --prod
```

**4단계: 환경변수 설정**
```bash
# Vercel 대시보드에서 자동 등록하거나 CLI로:
vercel env add NEXT_PUBLIC_SUPABASE_URL
vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY
```

---

### 방법 2: Vercel 웹 대시보드

**1단계: GitHub에 코드 푸시**
```bash
cd /Users/startuperdaniel/dev/everseconds/resale_marketplace_web

# Git 초기화 (이미 되어있다면 생략)
git init
git add .
git commit -m "Initial commit for web deployment"

# GitHub 레포지토리 생성 후
git remote add origin https://github.com/YOUR_USERNAME/resale_marketplace_web.git
git push -u origin main
```

**2단계: Vercel 연결**
1. https://vercel.com 접속
2. "Add New Project" 클릭
3. GitHub 레포지토리 선택
4. "Import" 클릭

**3단계: 환경변수 설정**
1. Project Settings → Environment Variables
2. 아래 변수 추가:
```
NEXT_PUBLIC_SUPABASE_URL=https://ewhurbwdqiemeuwdtpeg.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**4단계: 배포**
- 자동으로 빌드 & 배포 시작
- 완료 후 URL 제공 (예: `https://resale-marketplace-web.vercel.app`)

---

### 방법 3: GitHub Actions (자동 배포)

나중에 자동화를 원할 때 사용

---

## 🔧 배포 후 설정

### 1. 커스텀 도메인 연결

**Vercel 대시보드에서:**
1. Project → Settings → Domains
2. "Add Domain" 클릭
3. `everseconds.com` 입력
4. DNS 설정 안내에 따라 도메인 제공업체에서 설정:

```
Type: A
Name: @
Value: 76.76.21.21

Type: CNAME
Name: www
Value: cname.vercel-dns.com
```

5. 검증 완료 후 자동 HTTPS 적용

---

### 2. 환경별 URL 확인

배포 완료 후 3개 URL 제공:

```bash
# 1. 프로덕션 URL
https://everseconds.com (커스텀 도메인 연결 후)
https://resale-marketplace-web.vercel.app (기본)

# 2. 프리뷰 URL (각 커밋마다)
https://resale-marketplace-web-git-main.vercel.app

# 3. 개발 URL
https://resale-marketplace-web-dev.vercel.app
```

---

### 3. Flutter 앱 URL 업데이트

**배포 완료 후 앱에서 URL 변경:**

**파일:** `lib/screens/product/product_detail_screen.dart`
```dart
// 변경 전
final shareUrl = 'https://everseconds.com/product/$productId';

// 변경 후 (임시 Vercel URL)
final shareUrl = 'https://resale-marketplace-web.vercel.app/product/$productId';

// 도메인 연결 후
final shareUrl = 'https://everseconds.com/product/$productId';
```

**파일:** `lib/screens/shop/my_shop_screen.dart`
```dart
// 변경 전
final shopLink = 'https://everseconds.com/shop/${_shop?.shareUrl}';

// 변경 후 (임시 Vercel URL)
final shopLink = 'https://resale-marketplace-web.vercel.app/shop/${_shop!.shareUrl}';

// 도메인 연결 후
final shopLink = 'https://everseconds.com/shop/${_shop!.shareUrl}';
```

---

## 📊 배포 확인

### 테스트 체크리스트

```bash
# 1. 홈페이지 접속
https://YOUR-VERCEL-URL.vercel.app

# 2. 상품 페이지 테스트
https://YOUR-VERCEL-URL.vercel.app/product/1

# 3. 샵 페이지 테스트
https://YOUR-VERCEL-URL.vercel.app/shop/shop-abc123

# 4. QR 코드 생성 테스트
각 페이지에서 "앱 설치" 버튼 클릭

# 5. 모바일에서 접속 테스트
카카오톡에 링크 공유 → 클릭 → 페이지 열림 확인
```

---

## 🔥 빠른 시작 (5분)

```bash
# 1. CLI 설치
npm install -g vercel

# 2. 프로젝트 폴더로 이동
cd /Users/startuperdaniel/dev/everseconds/resale_marketplace_web

# 3. 로그인
vercel login

# 4. 배포
vercel --prod

# 5. 환경변수 입력 (프롬프트 나오면)
# NEXT_PUBLIC_SUPABASE_URL 입력
# NEXT_PUBLIC_SUPABASE_ANON_KEY 입력

# 완료! URL 복사해서 브라우저에서 확인
```

---

## 🐛 문제 해결

### 빌드 실패 시
```bash
# 로컬에서 빌드 테스트
npm run build

# 문제 해결 후 다시 배포
vercel --prod
```

### 환경변수 문제
```bash
# Vercel 환경변수 확인
vercel env ls

# 환경변수 추가
vercel env add VARIABLE_NAME production

# 환경변수 삭제 (잘못 입력 시)
vercel env rm VARIABLE_NAME production
```

### 도메인 연결 안 됨
1. DNS 전파 대기 (최대 24시간)
2. DNS 확인: https://dnschecker.org
3. Vercel 대시보드에서 상태 확인

---

## 📞 다음 단계

1. ✅ 배포 완료 → URL 확인
2. ✅ Flutter 앱에서 URL 업데이트
3. ✅ 테스트 (카카오톡 공유)
4. ✅ 커스텀 도메인 연결
5. ✅ Universal Links 설정 (iOS)
6. ✅ App Links 설정 (Android)

---

## 💡 팁

**자동 배포 설정:**
- GitHub 연결 시 `main` 브랜치에 푸시하면 자동 배포
- Preview 배포: PR마다 자동 생성
- 롤백: 대시보드에서 이전 버전으로 1클릭 복구

**성능 최적화:**
- Vercel Edge Network 자동 활성화
- 이미지 자동 최적화
- 글로벌 CDN 배포

**모니터링:**
- Vercel Analytics (무료)
- 실시간 로그 확인
- 성능 메트릭 대시보드

---

**배포 성공하면 알려주세요! Flutter 앱 URL 업데이트 도와드리겠습니다!** 🚀
