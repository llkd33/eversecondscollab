-- SMS 관련 테이블 업데이트
-- 안전거래 시스템을 위한 SMS 기능 강화

-- SMS 큐 테이블 (배치 발송용)
CREATE TABLE IF NOT EXISTS sms_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_number TEXT NOT NULL,
  message_type VARCHAR(50) NOT NULL,
  message_content TEXT NOT NULL,
  priority INTEGER DEFAULT 5 CHECK (priority >= 1 AND priority <= 10), -- 1(높음) ~ 10(낮음)
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'cancelled')),
  scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  sent_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- SMS 로그 테이블에 retry_count 컬럼 추가 (없는 경우)
ALTER TABLE sms_logs 
ADD COLUMN IF NOT EXISTS retry_count INTEGER DEFAULT 0;

-- SMS 템플릿 테이블 (동적 템플릿 관리용)
CREATE TABLE IF NOT EXISTS sms_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  template_key VARCHAR(100) UNIQUE NOT NULL,
  template_name VARCHAR(200) NOT NULL,
  template_content TEXT NOT NULL,
  variables JSONB, -- 템플릿에서 사용하는 변수들
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- SMS 발송 통계 테이블 (일별 통계)
CREATE TABLE IF NOT EXISTS sms_daily_stats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  date DATE NOT NULL,
  message_type VARCHAR(50) NOT NULL,
  total_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  failed_count INTEGER DEFAULT 0,
  total_cost INTEGER DEFAULT 0, -- 예상 비용 (원)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(date, message_type)
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_sms_queue_status ON sms_queue(status);
CREATE INDEX IF NOT EXISTS idx_sms_queue_scheduled_at ON sms_queue(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_sms_queue_priority ON sms_queue(priority);
CREATE INDEX IF NOT EXISTS idx_sms_logs_phone_number ON sms_logs(phone_number);
CREATE INDEX IF NOT EXISTS idx_sms_logs_message_type ON sms_logs(message_type);
CREATE INDEX IF NOT EXISTS idx_sms_logs_sent_at ON sms_logs(sent_at);
CREATE INDEX IF NOT EXISTS idx_sms_logs_is_sent ON sms_logs(is_sent);
CREATE INDEX IF NOT EXISTS idx_sms_daily_stats_date ON sms_daily_stats(date);

-- RLS 정책 설정
ALTER TABLE sms_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_daily_stats ENABLE ROW LEVEL SECURITY;

-- SMS 큐 RLS 정책 (관리자만 접근)
CREATE POLICY "Only admins can manage SMS queue" ON sms_queue
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

-- SMS 템플릿 RLS 정책 (관리자만 수정, 모든 사용자 조회 가능)
CREATE POLICY "Anyone can view SMS templates" ON sms_templates
  FOR SELECT USING (is_active = true);

CREATE POLICY "Only admins can manage SMS templates" ON sms_templates
  FOR INSERT, UPDATE, DELETE USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

-- SMS 통계 RLS 정책 (관리자만 접근)
CREATE POLICY "Only admins can view SMS stats" ON sms_daily_stats
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

-- 트리거 함수: SMS 큐 updated_at 자동 업데이트
CREATE TRIGGER update_sms_queue_updated_at BEFORE UPDATE ON sms_queue
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sms_templates_updated_at BEFORE UPDATE ON sms_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sms_daily_stats_updated_at BEFORE UPDATE ON sms_daily_stats
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 트리거 함수: SMS 발송 시 일별 통계 업데이트
CREATE OR REPLACE FUNCTION update_sms_daily_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- SMS 발송 성공/실패 시 일별 통계 업데이트
  INSERT INTO sms_daily_stats (date, message_type, total_count, success_count, failed_count)
  VALUES (
    DATE(NEW.sent_at),
    NEW.message_type,
    1,
    CASE WHEN NEW.is_sent THEN 1 ELSE 0 END,
    CASE WHEN NEW.is_sent THEN 0 ELSE 1 END
  )
  ON CONFLICT (date, message_type)
  DO UPDATE SET
    total_count = sms_daily_stats.total_count + 1,
    success_count = sms_daily_stats.success_count + CASE WHEN NEW.is_sent THEN 1 ELSE 0 END,
    failed_count = sms_daily_stats.failed_count + CASE WHEN NEW.is_sent THEN 0 ELSE 1 END,
    updated_at = TIMEZONE('utc', NOW());
  
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_sms_stats_on_log
  AFTER INSERT ON sms_logs
  FOR EACH ROW EXECUTE FUNCTION update_sms_daily_stats();

-- 기본 SMS 템플릿 데이터 삽입
INSERT INTO sms_templates (template_key, template_name, template_content, variables) VALUES
('verification_code', '인증번호 발송', '[에버세컨즈] 인증번호: {code}\n타인에게 절대 알려주지 마세요.\n유효시간: 5분', '["code"]'),
('deposit_request_admin', '입금확인 요청 (관리자)', '💰 입금확인 요청\n구매자: {buyer_name} ({buyer_phone})\n상품: {product_title}\n금액: {amount}\n어드민에서 확인 후 처리해주세요.', '["buyer_name", "buyer_phone", "product_title", "amount"]'),
('deposit_confirmed_seller', '입금확인 완료 (판매자)', '✅ 입금이 확인되었습니다.\n상품: {product_title}\n금액: {amount}\n상품을 발송해주세요.', '["product_title", "amount"]'),
('deposit_confirmed_reseller', '입금확인 완료 (대신판매자)', '✅ 입금이 확인되었습니다.\n상품: {product_title}\n대신판매 수수료 정산이 예정되어 있습니다.', '["product_title"]'),
('shipping_info_buyer', '배송정보 안내 (구매자)', '📦 상품이 발송되었습니다.\n상품: {product_title}\n{tracking_info}상품 수령 후 완료 버튼을 눌러주세요.', '["product_title", "tracking_info"]'),
('transaction_completed_admin', '거래완료 알림 (관리자)', '✅ 거래가 정상 완료되었습니다.\n구매자: {buyer_name}\n판매자: {seller_name}\n상품: {product_title}\n금액: {amount}\n정산 처리를 진행해주세요.', '["buyer_name", "seller_name", "product_title", "amount"]'),
('commission_settlement', '수수료 정산 완료', '💰 대신판매 수수료가 정산되었습니다.\n상품: {product_title}\n수수료: {commission}\n감사합니다.', '["product_title", "commission"]')
ON CONFLICT (template_key) DO NOTHING;

-- 데이터베이스 함수: SMS 큐 처리
CREATE OR REPLACE FUNCTION process_sms_queue(batch_size INTEGER DEFAULT 10)
RETURNS TABLE(processed_count INTEGER, success_count INTEGER, failed_count INTEGER) AS $$
DECLARE
  sms_record RECORD;
  processed INTEGER := 0;
  success INTEGER := 0;
  failed INTEGER := 0;
BEGIN
  -- 대기중인 SMS 조회 및 처리
  FOR sms_record IN
    SELECT * FROM sms_queue
    WHERE status = 'pending'
      AND scheduled_at <= TIMEZONE('utc', NOW())
    ORDER BY priority ASC, scheduled_at ASC
    LIMIT batch_size
  LOOP
    BEGIN
      -- 실제 SMS 발송 로직은 애플리케이션에서 처리
      -- 여기서는 상태만 업데이트
      UPDATE sms_queue
      SET status = 'sent',
          sent_at = TIMEZONE('utc', NOW()),
          updated_at = TIMEZONE('utc', NOW())
      WHERE id = sms_record.id;
      
      processed := processed + 1;
      success := success + 1;
      
    EXCEPTION WHEN OTHERS THEN
      -- 실패 시 상태 업데이트
      UPDATE sms_queue
      SET status = 'failed',
          error_message = SQLERRM,
          sent_at = TIMEZONE('utc', NOW()),
          updated_at = TIMEZONE('utc', NOW())
      WHERE id = sms_record.id;
      
      processed := processed + 1;
      failed := failed + 1;
    END;
  END LOOP;
  
  RETURN QUERY SELECT processed, success, failed;
END;
$$ LANGUAGE plpgsql;

-- 데이터베이스 함수: SMS 통계 조회
CREATE OR REPLACE FUNCTION get_sms_stats(
  start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
  end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
  date DATE,
  message_type VARCHAR(50),
  total_count INTEGER,
  success_count INTEGER,
  failed_count INTEGER,
  success_rate DECIMAL(5,2)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.date,
    s.message_type,
    s.total_count,
    s.success_count,
    s.failed_count,
    CASE 
      WHEN s.total_count > 0 THEN ROUND((s.success_count::DECIMAL / s.total_count) * 100, 2)
      ELSE 0
    END as success_rate
  FROM sms_daily_stats s
  WHERE s.date BETWEEN start_date AND end_date
  ORDER BY s.date DESC, s.message_type;
END;
$$ LANGUAGE plpgsql;

-- 데이터베이스 함수: 실패한 SMS 재시도
CREATE OR REPLACE FUNCTION retry_failed_sms(max_retry_count INTEGER DEFAULT 3)
RETURNS INTEGER AS $$
DECLARE
  retry_count INTEGER := 0;
BEGIN
  -- 실패한 SMS를 큐에 다시 추가
  INSERT INTO sms_queue (phone_number, message_type, message_content, priority, scheduled_at)
  SELECT 
    phone_number,
    message_type,
    message_content,
    8, -- 재시도는 낮은 우선순위
    TIMEZONE('utc', NOW()) + INTERVAL '5 minutes' -- 5분 후 재시도
  FROM sms_logs
  WHERE is_sent = false
    AND retry_count < max_retry_count
    AND sent_at >= TIMEZONE('utc', NOW()) - INTERVAL '24 hours';
  
  GET DIAGNOSTICS retry_count = ROW_COUNT;
  
  -- 재시도 횟수 업데이트
  UPDATE sms_logs
  SET retry_count = retry_count + 1
  WHERE is_sent = false
    AND retry_count < max_retry_count
    AND sent_at >= TIMEZONE('utc', NOW()) - INTERVAL '24 hours';
  
  RETURN retry_count;
END;
$$ LANGUAGE plpgsql;

-- 코멘트 추가
COMMENT ON TABLE sms_queue IS 'SMS 발송 큐 - 배치 발송 및 예약 발송용';
COMMENT ON TABLE sms_templates IS 'SMS 템플릿 관리 - 동적 템플릿 설정';
COMMENT ON TABLE sms_daily_stats IS 'SMS 발송 일별 통계';
COMMENT ON FUNCTION process_sms_queue IS 'SMS 큐 배치 처리 함수';
COMMENT ON FUNCTION get_sms_stats IS 'SMS 발송 통계 조회 함수';
COMMENT ON FUNCTION retry_failed_sms IS '실패한 SMS 재시도 함수';