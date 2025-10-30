# 데이터베이스 설정 순서
# Database Setup Order

> ⚠️ **중요**: SQL 파일을 반드시 아래 순서대로 실행해야 합니다!

## 🔢 실행 순서

### 1단계: 기본 스키마 (이미 완료되었을 가능성 높음)
```sql
-- 파일: database/schema.sql
-- 기본 테이블: users, shops, products, transactions 등
```

**확인 방법:**
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('users', 'products', 'transactions');
```

### 2단계: Reports 테이블 추가 ⭐ **먼저 실행!**
```sql
-- 파일: database/add_reports_table.sql
```

**Supabase SQL Editor에서 실행:**

1. SQL Editor 열기
2. 아래 SQL 복사 & 붙여넣기:

```sql
-- Reports (신고) 테이블 추가
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID REFERENCES users(id) ON DELETE SET NULL NOT NULL,
  reported_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reported_product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  reported_transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  report_type VARCHAR(50) NOT NULL,
  report_category VARCHAR(50),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  evidence_urls TEXT[],
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'rejected')),
  admin_notes TEXT,
  resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  resolved_at TIMESTAMP WITH TIME ZONE,
  resolution TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_report_type ON reports(report_type);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at);

-- RLS 설정
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own reports" ON reports
  FOR SELECT USING (auth.uid() = reporter_id);

CREATE POLICY "Users can view reports about themselves" ON reports
  FOR SELECT USING (auth.uid() = reported_user_id);

CREATE POLICY "Users can create reports" ON reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Admins can manage all reports" ON reports
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

-- updated_at 트리거
CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

3. **Run** 클릭
4. "Success" 메시지 확인

**확인:**
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_name = 'reports';
```

### 3단계: 관리자 시스템 고도화 ⭐ **그 다음 실행!**
```sql
-- 파일: database/admin_system_enhancement.sql
```

**Supabase SQL Editor에서 실행:**

1. SQL Editor에서 새 쿼리 생성
2. `database/admin_system_enhancement.sql` 파일 전체 내용 복사
3. 붙여넣기
4. **Run** 클릭

**확인:**
```sql
-- 새 테이블 확인
SELECT table_name
FROM information_schema.tables
WHERE table_name IN (
  'admin_action_logs',
  'access_logs',
  'error_logs',
  'system_backups',
  'system_notifications',
  'system_metrics'
);

-- View 확인
SELECT table_name
FROM information_schema.views
WHERE table_name IN ('admin_dashboard_stats', 'system_health_status');
```

---

## ✅ 전체 확인 스크립트

모든 설정이 완료되었는지 확인:

```sql
-- 1. 필수 테이블 확인
SELECT
  CASE
    WHEN COUNT(*) = 17 THEN '✅ 모든 테이블 존재'
    ELSE '❌ 일부 테이블 누락: ' || (17 - COUNT(*))::TEXT || '개'
  END as table_status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'users', 'shops', 'products', 'shop_products',
  'chats', 'messages', 'transactions', 'reviews',
  'safe_transactions', 'sms_logs', 'reports',
  'admin_action_logs', 'access_logs', 'error_logs',
  'system_backups', 'system_notifications', 'system_metrics'
);

-- 2. View 확인
SELECT
  table_name,
  '✅ 존재' as status
FROM information_schema.views
WHERE table_name IN ('admin_dashboard_stats', 'system_health_status');

-- 3. Function 확인
SELECT
  routine_name,
  '✅ 존재' as status
FROM information_schema.routines
WHERE routine_name IN ('cleanup_old_logs', 'collect_system_metrics');
```

---

## 🚨 에러 해결

### 에러: "relation reports does not exist"

**원인**: reports 테이블이 없는데 admin_system_enhancement.sql을 먼저 실행함

**해결책**:
1. 2단계(Reports 테이블)부터 다시 실행
2. 그 다음 3단계 실행

### 에러: "function update_updated_at_column does not exist"

**원인**: 기본 schema.sql이 실행되지 않음

**해결책**:
```sql
-- 트리거 함수 생성
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc', NOW());
  RETURN NEW;
END;
$$ language 'plpgsql';
```

### View 생성 에러

**원인**: 참조하는 테이블이 없음

**해결책**:
1. reports 테이블 먼저 생성
2. View 다시 생성

```sql
-- View 재생성
DROP VIEW IF EXISTS admin_dashboard_stats;
DROP VIEW IF EXISTS system_health_status;

-- 그 다음 admin_system_enhancement.sql의 View 부분만 실행
```

---

## 📋 체크리스트

설치 완료 확인:

- [ ] reports 테이블 생성 완료
- [ ] admin_action_logs 테이블 생성 완료
- [ ] access_logs 테이블 생성 완료
- [ ] error_logs 테이블 생성 완료
- [ ] system_backups 테이블 생성 완료
- [ ] system_notifications 테이블 생성 완료
- [ ] system_metrics 테이블 생성 완료
- [ ] admin_dashboard_stats view 생성 완료
- [ ] system_health_status view 생성 완료
- [ ] cleanup_old_logs 함수 생성 완료
- [ ] collect_system_metrics 함수 생성 완료

---

## 🔄 초기화 (처음부터 다시)

모든 것을 삭제하고 처음부터:

```sql
-- ⚠️ 경고: 모든 관리자 데이터가 삭제됩니다!

-- Tables 삭제
DROP TABLE IF EXISTS system_metrics CASCADE;
DROP TABLE IF EXISTS system_notifications CASCADE;
DROP TABLE IF EXISTS system_backups CASCADE;
DROP TABLE IF EXISTS error_logs CASCADE;
DROP TABLE IF EXISTS access_logs CASCADE;
DROP TABLE IF EXISTS admin_action_logs CASCADE;
DROP TABLE IF EXISTS reports CASCADE;

-- Views 삭제
DROP VIEW IF EXISTS system_health_status;
DROP VIEW IF EXISTS admin_dashboard_stats;

-- Functions 삭제
DROP FUNCTION IF EXISTS cleanup_old_logs();
DROP FUNCTION IF EXISTS collect_system_metrics();
```

그 다음 2단계부터 다시 시작

---

## 다음 단계

데이터베이스 설정이 완료되면:

1. ✅ 관리자 계정 설정
```sql
UPDATE users SET role = '관리자' WHERE phone = '본인_전화번호';
```

2. ✅ Flutter 앱 실행
```bash
flutter run
```

3. ✅ 관리자 페이지 접근
```
/#/admin
/#/admin/advanced
```

상세 가이드: `HOW_TO_RUN_ADMIN.md` 참조
