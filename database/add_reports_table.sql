-- Reports (신고) 테이블 추가
-- Add Reports Table for Admin System

-- 11. Reports (신고) 테이블
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID REFERENCES users(id) ON DELETE SET NULL NOT NULL, -- 신고자
  reported_user_id UUID REFERENCES users(id) ON DELETE SET NULL, -- 신고 대상 사용자
  reported_product_id UUID REFERENCES products(id) ON DELETE SET NULL, -- 신고 대상 상품
  reported_transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL, -- 신고 대상 거래
  report_type VARCHAR(50) NOT NULL, -- [사기, 욕설, 허위정보, 불건전, 기타]
  report_category VARCHAR(50), -- [user, product, transaction, chat]
  title TEXT NOT NULL, -- 신고 제목
  description TEXT NOT NULL, -- 신고 내용
  evidence_urls TEXT[], -- 증거 자료 URL 리스트
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'rejected')),
  admin_notes TEXT, -- 관리자 메모
  resolved_by UUID REFERENCES users(id) ON DELETE SET NULL, -- 처리한 관리자
  resolved_at TIMESTAMP WITH TIME ZONE, -- 처리 일시
  resolution TEXT, -- 처리 내용
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_report_type ON reports(report_type);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at);

-- RLS (Row Level Security) 설정
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- 신고자는 자신의 신고만 볼 수 있음
CREATE POLICY "Users can view own reports" ON reports
  FOR SELECT USING (auth.uid() = reporter_id);

-- 신고 대상자는 자신에 대한 신고를 볼 수 있음
CREATE POLICY "Users can view reports about themselves" ON reports
  FOR SELECT USING (auth.uid() = reported_user_id);

-- 사용자는 신고를 생성할 수 있음
CREATE POLICY "Users can create reports" ON reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- 관리자는 모든 신고를 관리할 수 있음
CREATE POLICY "Admins can manage all reports" ON reports
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

-- updated_at 트리거 추가
CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 코멘트 추가
COMMENT ON TABLE reports IS '사용자/상품/거래에 대한 신고 관리 테이블';
COMMENT ON COLUMN reports.report_type IS '신고 유형: 사기, 욕설, 허위정보, 불건전, 기타';
COMMENT ON COLUMN reports.report_category IS '신고 카테고리: user, product, transaction, chat';
COMMENT ON COLUMN reports.status IS '처리 상태: pending(대기중), investigating(조사중), resolved(해결됨), rejected(기각됨)';
