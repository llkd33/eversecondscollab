# 에버세컨즈 웹 관리자 시스템 기획서

## 📋 프로젝트 개요

### 프로젝트명
**에버세컨즈 (Everseconds) 중고거래 플랫폼 웹 관리자 시스템**

### 목적
- Supabase 기반 중고거래 플랫폼의 통합 관리 시스템 구축
- 사용자, 상품, 거래 데이터의 실시간 모니터링 및 관리
- 관리자의 효율적인 플랫폼 운영 지원

### 기술 스택
- **Frontend**: Next.js 15.5.2 (App Router), React, TypeScript, Tailwind CSS
- **Backend**: Supabase (PostgreSQL, Authentication, Real-time)
- **배포**: Vercel (권장) 또는 커스텀 서버

---

## 🎯 핵심 기능

### 1. 대시보드 (Overview)

#### 1.1 통계 카드
실시간 플랫폼 통계를 한눈에 확인할 수 있는 카드형 UI

| 지표 | 설명 | 데이터 소스 |
|------|------|------------|
| 총 사용자 | 가입한 전체 사용자 수 | `users` 테이블 |
| 총 거래 | 전체 거래 건수 | `transactions` 테이블 |
| 총 매출 | 완료된 거래의 총 수수료 수익 | `transactions` 테이블 (completed) |
| 활성 분쟁 | 진행 중인 분쟁 건수 | `reports` 테이블 (예정) |

#### 1.2 통계 시각화
**거래 상태 차트**
- 완료된 거래와 대기 중인 거래의 비율을 프로그레스 바로 표시
- 퍼센트와 절대값 동시 표시

**수익 요약**
- 총 매출
- 완료된 거래 수
- 평균 거래액 자동 계산

**사용자/상품 통계**
- 대형 숫자로 강조 표시
- 시각적으로 중요 지표 부각

#### 1.3 최근 거래
최근 5건의 거래를 테이블로 표시

| 컬럼 | 내용 |
|------|------|
| 상품 | 거래된 상품명 |
| 구매자 | 구매자 이름 |
| 판매자 | 판매자 이름 (대신판매자 포함) |
| 금액 | 거래 금액 (KRW) |
| 상태 | 완료/대기/취소 |
| 거래일 | 거래 생성 날짜 |

---

### 2. 사용자 관리 (Users Management)

#### 2.1 사용자 목록
**표시 정보**
- 이름
- 이메일
- 전화번호
- 역할 (일반/대신판매자/관리자)
- 인증 상태 (인증됨/미인증)
- 가입일

**필터링 & 검색**
```typescript
// 검색 필드
- 이름, 이메일, 전화번호에서 검색

// 역할 필터
- 전체 / 일반 / 대신판매자 / 관리자
```

#### 2.2 사용자 관리 기능
**역할 변경**
```
1: 일반 사용자
2: 대신판매자
3: 관리자
```
- `userService.updateUserRole(userId, role)` 호출
- 즉시 페이지 새로고침

**인증 상태 토글**
- 인증 ↔ 미인증 전환
- `userService.verifyUser(userId, verified)` 호출

#### 2.3 데이터 스키마
```sql
Table: users
- id (UUID, PK)
- name (VARCHAR)
- email (VARCHAR, UNIQUE)
- phone (VARCHAR)
- role (ENUM: '일반', '대신판매자', '관리자')
- is_verified (BOOLEAN)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

---

### 3. 상품 관리 (Products Management)

#### 3.1 상품 목록
**표시 정보**
- 상품명 (이미지 썸네일 포함)
- 가격
- 판매자 이름
- 카테고리
- 상태 (판매중/판매완료/예약중)
- 대신팔기 여부 (✓ 아이콘)
- 등록일

**필터링 & 검색**
```typescript
// 검색 필드
- 상품명 검색

// 상태 필터
- 전체 / 판매중 / 판매완료 / 예약중
```

#### 3.2 상품 관리 기능
**상태 변경**
```
1: 판매중
2: 판매완료
3: 예약중
```
- `productService.updateProduct(productId, { status })` 호출

**상품 삭제**
- 확인 후 `productService.deleteProduct(productId)` 호출
- 관계된 거래가 있는 경우 주의 필요 (Foreign Key 제약)

#### 3.3 데이터 스키마
```sql
Table: products
- id (UUID, PK)
- title (VARCHAR)
- price (INTEGER)
- description (TEXT)
- images (ARRAY[TEXT])
- category (VARCHAR)
- seller_id (UUID, FK → users.id)
- status (ENUM: '판매중', '판매완료', '예약중')
- resale_enabled (BOOLEAN)
- commission_rate (INTEGER)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

---

### 4. 거래 관리 (Transactions Management)

#### 4.1 거래 목록
**표시 정보**
- 거래 ID (8자리 축약)
- 상품명
- 구매자
- 판매자
- 대신판매자 (있는 경우)
- 금액
- 수수료율
- 상태 (대기/완료/취소)
- 거래일

**필터링 & 검색**
```typescript
// 검색 필드
- 거래 ID, 상품명 검색

// 상태 필터
- 전체 / pending(대기) / completed(완료) / cancelled(취소)
```

#### 4.2 거래 관리 기능
**상태 변경**
```
1: pending (대기)
2: completed (완료)
3: cancelled (취소)
```
- `transactionService.updateTransactionStatus(txId, status)` 호출
- 상태 변경 시 관련 상품 상태도 업데이트 고려 필요

#### 4.3 데이터 스키마
```sql
Table: transactions
- id (UUID, PK)
- product_id (UUID, FK → products.id)
- buyer_id (UUID, FK → users.id)
- seller_id (UUID, FK → users.id)
- reseller_id (UUID, FK → users.id, NULLABLE)
- price (INTEGER)
- commission_rate (INTEGER)
- status (ENUM: 'pending', 'completed', 'cancelled')
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

---

## 🗄️ 데이터베이스 구조

### ERD (Entity Relationship Diagram)

```
┌─────────────────┐
│     users       │
├─────────────────┤
│ id (PK)         │
│ name            │
│ email           │
│ phone           │
│ role            │
│ is_verified     │
│ created_at      │
└─────────────────┘
        │
        │ seller_id, buyer_id, reseller_id
        ▼
┌─────────────────┐      ┌─────────────────┐
│  transactions   │──────│    products     │
├─────────────────┤      ├─────────────────┤
│ id (PK)         │      │ id (PK)         │
│ product_id (FK) │◄─────│ seller_id (FK)  │
│ buyer_id (FK)   │      │ title           │
│ seller_id (FK)  │      │ price           │
│ reseller_id(FK) │      │ images          │
│ price           │      │ category        │
│ commission_rate │      │ status          │
│ status          │      │ resale_enabled  │
│ created_at      │      │ created_at      │
└─────────────────┘      └─────────────────┘
```

### Supabase Services

#### userService
```typescript
// 사용자 조회 및 관리
- getAllUsers(filters)
- getAllUsersStats()
- updateUserRole(id, role)
- verifyUser(id, verified)
```

#### productService
```typescript
// 상품 조회 및 관리
- getProducts(filters)
- getProductStats()
- updateProduct(id, updates)
- deleteProduct(id)
```

#### transactionService
```typescript
// 거래 조회 및 관리
- getTransactions(filters)
- getTransactionStats()
- updateTransactionStatus(id, status)
```

---

## 🎨 UI/UX 디자인

### 디자인 시스템
**색상 팔레트**
```css
Primary Blue: #3B82F6 (탭, 주요 액션)
Green: #10B981 (완료, 성공)
Yellow: #F59E0B (대기, 경고)
Orange: #F97316 (대신팔기)
Red: #EF4444 (취소, 삭제)
Purple: #8B5CF6 (관리자, 특별)
Gray: #6B7280 (보조 텍스트)
```

**타이포그래피**
- 헤더: 2XL (1.5rem) - Semibold
- 서브헤더: LG (1.125rem) - Medium
- 본문: Base (1rem) - Regular
- 캡션: SM (0.875rem) - Regular

**컴포넌트 스타일**
- 카드: `rounded-lg shadow` (부드러운 모서리, 미묘한 그림자)
- 버튼: `hover:효과` (마우스 오버 시 색상 변화)
- 배지: `rounded-full px-2.5 py-0.5` (태그 스타일)
- 테이블: `divide-y divide-gray-200` (구분선)

### 반응형 디자인
```css
Mobile: < 768px (1열 그리드)
Tablet: 768px - 1024px (2열 그리드)
Desktop: > 1024px (4열 그리드)
```

---

## 🔐 보안 및 권한

### Row Level Security (RLS) 정책
```sql
-- 관리자만 모든 데이터 조회 가능
CREATE POLICY "Admins can view all users"
ON users FOR SELECT
USING (auth.jwt() ->> 'role' = '관리자');

-- 관리자만 사용자 역할 업데이트 가능
CREATE POLICY "Admins can update user roles"
ON users FOR UPDATE
USING (auth.jwt() ->> 'role' = '관리자');
```

### 인증 흐름
1. Kakao OAuth 로그인
2. Supabase Auth 세션 생성
3. 사용자 역할 확인 (관리자 여부)
4. Admin 페이지 접근 권한 부여

---

## 📊 성능 최적화

### 데이터 로딩 전략
**초기 로드**
- Overview 탭: 통계 데이터 + 최근 거래 5건
- 다른 탭: 탭 전환 시 lazy loading

**페이지네이션**
```typescript
// 현재: limit 100
// 추후: offset 기반 페이지네이션 구현
getUsers({ limit: 100, offset: 0 })
```

**캐싱**
- 통계 데이터: 1분 캐시
- 목록 데이터: 30초 캐시

### Console Logging
```typescript
// 개발용 로그
console.log('🔄 데이터 로딩 중...')
console.log('✅ 데이터 로딩 완료:', data)
console.error('❌ 데이터 로딩 실패:', error)
```

---

## 🚀 배포 및 운영

### 환경 변수
```env
NEXT_PUBLIC_SUPABASE_URL=https://[project-id].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=[anon-key]
```

### 배포 절차
1. 코드 빌드: `npm run build`
2. Vercel 배포 또는 커스텀 서버
3. 환경 변수 설정
4. Supabase RLS 정책 확인

### 모니터링
- **에러 추적**: Sentry 또는 Vercel Analytics
- **성능 모니터링**: Web Vitals
- **사용자 활동**: Supabase Real-time Logs

---

## 📝 향후 개선 사항

### 단기 (1-2주)
- [ ] 페이지네이션 구현
- [ ] 엑셀 내보내기 기능
- [ ] 고급 필터링 (날짜 범위, 다중 조건)
- [ ] 실시간 업데이트 (Supabase Realtime)

### 중기 (1-2개월)
- [ ] 분쟁 처리 시스템 완성 (reports 테이블)
- [ ] 이메일/SMS 알림 시스템
- [ ] 통계 차트 라이브러리 적용 (Chart.js, Recharts)
- [ ] 관리자 권한 세분화 (역할별 접근 제어)

### 장기 (3개월+)
- [ ] AI 기반 이상 거래 탐지
- [ ] 자동화된 보고서 생성
- [ ] 모바일 앱 관리자 버전
- [ ] 고객 지원 채팅 시스템 통합

---

## 👥 팀 및 역할

### 개발팀
- **Full Stack Developer**: Next.js + Supabase 개발
- **UI/UX Designer**: 관리자 인터페이스 디자인
- **QA Engineer**: 테스트 및 품질 보증

### 운영팀
- **Platform Manager**: 일일 운영 및 모니터링
- **CS Manager**: 분쟁 처리 및 고객 지원
- **Data Analyst**: 통계 분석 및 리포트

---

## 📞 지원 및 문의

### 기술 문서
- Next.js: https://nextjs.org/docs
- Supabase: https://supabase.com/docs
- Tailwind CSS: https://tailwindcss.com/docs

### 프로젝트 정보
- **개발 시작일**: 2025-01-29
- **현재 버전**: v1.0.0
- **라이센스**: MIT

---

## 📄 변경 이력

### v1.0.0 (2025-01-29)
- ✅ 초기 관리자 대시보드 구현
- ✅ Supabase 데이터베이스 연동
- ✅ 사용자 관리 기능 완성
- ✅ 상품 관리 기능 완성
- ✅ 거래 관리 기능 완성
- ✅ 통계 시각화 추가
- ✅ 실시간 데이터 로딩 구현

---
