# Supabase Database 설정 가이드

## 📋 SQL 스키마 실행 순서

Supabase SQL Editor에서 다음 순서대로 실행하세요:

### 1단계: Extension 및 기본 테이블 생성
```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### 2단계: 테이블 생성
`schema.sql` 파일의 테이블 생성 부분을 순차적으로 실행:
1. Users 테이블
2. Shops 테이블
3. Products 테이블
4. Shop_Products 테이블
5. Chats 테이블
6. Messages 테이블
7. Transactions 테이블
8. Reviews 테이블
9. Safe_Transactions 테이블
10. SMS_Logs 테이블

### 3단계: 인덱스 생성
모든 테이블 생성 후 인덱스 부분 실행

### 4단계: RLS (Row Level Security) 정책
RLS 활성화 및 정책 설정 부분 실행

### 5단계: 트리거 함수 및 트리거
마지막으로 트리거 함수와 트리거 생성 부분 실행

## ⚠️ 주의사항

1. **순서 중요**: 외래키 관계 때문에 테이블 생성 순서를 지켜야 합니다.
2. **에러 발생 시**: 이미 존재하는 테이블 에러는 무시하고 진행
3. **RLS 활성화**: 보안을 위해 반드시 RLS 정책을 설정해야 합니다.

## 🔧 실행 방법

### 방법 1: 전체 실행 (권장)
1. Supabase Dashboard → SQL Editor
2. New Query 클릭
3. `schema.sql` 파일 전체 내용 복사/붙여넣기
4. Run 버튼 클릭

### 방법 2: 단계별 실행
에러가 발생하는 경우 위의 순서대로 나누어서 실행

## 📌 실행 후 확인사항

1. **Database** 탭에서 모든 테이블이 생성되었는지 확인
2. **Authentication** → **Policies** 에서 RLS 정책이 적용되었는지 확인
3. **Database** → **Functions** 에서 트리거 함수들이 생성되었는지 확인

## 🚀 테스트 데이터 (선택사항)

필요시 다음 테스트 데이터를 추가할 수 있습니다:

```sql
-- 테스트 관리자 계정
INSERT INTO users (email, name, phone, is_verified, role) 
VALUES ('admin@everseconds.com', '관리자', '010-0000-0000', true, '관리자');
```

## 📱 Storage Bucket 설정

이미지 업로드를 위해 Storage Bucket도 생성해야 합니다:

1. Supabase Dashboard → Storage
2. New Bucket 클릭
3. Bucket 이름: `product-images`
4. Public bucket 옵션 체크
5. Create 클릭

## ✅ 완료 체크리스트

- [ ] UUID Extension 활성화
- [ ] 모든 테이블 생성 (10개)
- [ ] 인덱스 생성
- [ ] RLS 정책 설정
- [ ] 트리거 함수 생성
- [ ] Storage Bucket 생성
- [ ] 테스트 데이터 추가 (선택)