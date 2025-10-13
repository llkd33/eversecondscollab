# 📚 Everseconds 웹 배포 가이드

## 🎯 배포 개요

### 완료된 작업
✅ **실제 데이터 연동 구현**
- AdminService 생성 - Supabase와 실시간 데이터 연동
- 대시보드 통계 실시간 업데이트
- 차트 시각화 (fl_chart 라이브러리)
- 최근 활동 모니터링

✅ **구현된 기능**
- 사용자 통계 (총 사용자, 활성 사용자)
- 상품 관리 통계
- 거래 모니터링
- 신고 관리
- 월별 차트 (수익, 거래량)
- 카테고리별 파이 차트

---

## 🚀 즉시 배포 방법

### 1. 웹 빌드 생성
```bash
# 프로젝트 디렉토리에서
cd /Users/startuperdaniel/dev/everseconds/resale_marketplace_app

# 의존성 설치
flutter pub get

# 웹 빌드 (프로덕션)
flutter build web --release --web-renderer html
```

### 2. 환경변수 설정
`.env` 파일 생성:
```env
# Supabase 설정
SUPABASE_URL=your_production_supabase_url
SUPABASE_ANON_KEY=your_production_anon_key

# 카카오 설정 (이미 설정됨)
KAKAO_JAVASCRIPT_KEY=bcbbbc27c5bfa788f960c55acdd1c90a
KAKAO_NATIVE_APP_KEY=0d0b331b737c31682e666aadc2d97763
```

---

## 📦 배포할 파일들

### 웹 어드민용
```
build/web/
├── index.html              # 메인 HTML
├── main.dart.js           # 컴파일된 Dart 코드
├── flutter.js             # Flutter 부트스트랩
├── flutter_bootstrap.js   # 부트스트랩 로더
├── manifest.json          # PWA 매니페스트
├── favicon.png            # 파비콘
├── version.json           # 버전 정보
├── assets/
│   ├── AssetManifest.json
│   ├── FontManifest.json
│   └── fonts/            # 폰트 파일
├── icons/                # 아이콘 파일들
└── canvaskit/           # 렌더링 엔진
```

---

## 🌐 배포 플랫폼별 가이드

### 옵션 A: Vercel 배포 (추천) ⭐
```bash
# 1. Vercel CLI 설치
npm install -g vercel

# 2. 배포
cd build/web
vercel --prod

# 3. 환경변수 설정 (Vercel 대시보드에서)
SUPABASE_URL=your_url
SUPABASE_ANON_KEY=your_key

# 4. 도메인 연결
vercel domains add everseconds.com
vercel domains add admin.everseconds.com
```

### 옵션 B: Firebase Hosting
```bash
# 1. Firebase 초기화
firebase init hosting

# 2. firebase.json 설정
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|wasm)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000"
          }
        ]
      }
    ]
  }
}

# 3. 배포
firebase deploy --only hosting
```

### 옵션 C: AWS S3 + CloudFront
```bash
# 1. S3 버킷 생성
aws s3 mb s3://everseconds-web

# 2. 정적 웹사이트 호스팅 활성화
aws s3 website s3://everseconds-web/ \
  --index-document index.html \
  --error-document index.html

# 3. 파일 업로드
aws s3 sync build/web/ s3://everseconds-web/ \
  --acl public-read

# 4. CloudFront 설정
# AWS 콘솔에서 CloudFront 배포 생성
# Origin: S3 버킷
# Default Root Object: index.html
```

### 옵션 D: Nginx 서버
```nginx
# /etc/nginx/sites-available/everseconds
server {
    listen 80;
    server_name everseconds.com www.everseconds.com;
    
    root /var/www/everseconds/build/web;
    index index.html;
    
    # SPA 라우팅 처리
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # 캐시 설정
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # CORS 헤더
    add_header Access-Control-Allow-Origin *;
    
    # gzip 압축
    gzip on;
    gzip_types text/plain text/css text/javascript application/javascript application/json;
    gzip_min_length 1000;
}

# 어드민 도메인 설정
server {
    listen 80;
    server_name admin.everseconds.com;
    
    root /var/www/everseconds/build/web;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 🔐 프로덕션 체크리스트

### 1. Supabase 설정
```sql
-- RLS (Row Level Security) 정책 확인
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- 어드민 권한 정책
CREATE POLICY "Admins can view all users" 
ON users FOR SELECT
TO authenticated
USING (auth.jwt() ->> 'role' = '관리자');
```

### 2. 카카오 개발자 설정
1. [카카오 개발자 콘솔](https://developers.kakao.com) 접속
2. 애플리케이션 > 플랫폼 > Web 플랫폼 등록
3. 사이트 도메인 추가:
   - https://everseconds.com
   - https://admin.everseconds.com
   - https://www.everseconds.com
4. Redirect URI 등록:
   - https://everseconds.com/auth/kakao/callback
   - https://admin.everseconds.com/auth/kakao/callback

### 3. SSL 인증서 설정
```bash
# Let's Encrypt 사용
sudo certbot --nginx -d everseconds.com -d www.everseconds.com -d admin.everseconds.com
```

### 4. 환경별 설정
```javascript
// 프로덕션 환경변수
const isProduction = window.location.hostname === 'everseconds.com';
const apiUrl = isProduction 
  ? 'https://your-prod-supabase.supabase.co' 
  : 'http://localhost:54321';
```

---

## 📱 반응형 대응

### 태블릿/모바일 웹
동일한 빌드 파일 사용, CSS 미디어 쿼리로 대응:

```dart
// lib/utils/responsive.dart
class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;
}
```

---

## 🔧 배포 후 관리

### 모니터링 설정
```javascript
// Google Analytics 추가 (index.html)
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>

// Sentry 에러 트래킹
import * as Sentry from "@sentry/browser";
Sentry.init({
  dsn: "YOUR_SENTRY_DSN",
  environment: "production"
});
```

### 업데이트 배포
```bash
# 1. 새 빌드 생성
flutter build web --release

# 2. 버전 업데이트
# pubspec.yaml의 version 수정

# 3. 배포
vercel --prod  # 또는 선택한 플랫폼
```

---

## 📝 문제 해결

### 빌드 오류
```bash
# 캐시 정리
flutter clean
flutter pub get
flutter build web --release
```

### CORS 오류
Supabase 대시보드 > Settings > API > CORS 설정:
- https://everseconds.com
- https://admin.everseconds.com

### 404 오류 (라우팅)
SPA 라우팅 처리 필수 - 모든 경로를 index.html로 리다이렉트

---

## 🎉 배포 완료!

웹 어드민 접속:
- https://admin.everseconds.com (어드민 전용)
- https://everseconds.com (일반 사용자)

기본 관리자 계정으로 로그인 후 대시보드 확인 가능합니다.