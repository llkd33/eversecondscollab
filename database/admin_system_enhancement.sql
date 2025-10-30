-- 관리자 시스템 고도화 스키마
-- Admin System Enhancement Schema

-- 1. Admin Action Logs (관리자 액션 로그) 테이블
CREATE TABLE IF NOT EXISTS admin_action_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id UUID REFERENCES users(id) ON DELETE SET NULL NOT NULL,
  action_type VARCHAR(50) NOT NULL, -- [user_update, user_delete, transaction_update, report_resolve, system_config 등]
  target_type VARCHAR(50), -- [user, transaction, product, report, system 등]
  target_id UUID, -- 대상 ID
  action_details JSONB, -- 액션 상세 정보 (변경 전/후 데이터 등)
  ip_address INET, -- IP 주소
  user_agent TEXT, -- 브라우저/앱 정보
  result VARCHAR(20) DEFAULT 'success' CHECK (result IN ('success', 'failure', 'partial')),
  error_message TEXT, -- 실패 시 오류 메시지
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 2. Access Logs (접근 로그) 테이블
CREATE TABLE IF NOT EXISTS access_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  endpoint VARCHAR(255) NOT NULL, -- 접근한 경로
  method VARCHAR(10) NOT NULL, -- GET, POST, PUT, DELETE 등
  status_code INTEGER, -- HTTP 상태 코드
  ip_address INET,
  user_agent TEXT,
  request_body JSONB, -- 요청 본문 (민감정보 제외)
  response_time INTEGER, -- 응답 시간 (ms)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 3. Error Logs (오류 로그) 테이블
CREATE TABLE IF NOT EXISTS error_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  error_type VARCHAR(50) NOT NULL, -- [database, network, validation, authentication, authorization, system 등]
  error_code VARCHAR(50), -- 에러 코드
  error_message TEXT NOT NULL,
  stack_trace TEXT, -- 스택 트레이스
  context JSONB, -- 에러 발생 컨텍스트
  severity VARCHAR(20) DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  resolved BOOLEAN DEFAULT false,
  resolved_at TIMESTAMP WITH TIME ZONE,
  resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  resolution_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 4. System Backups (백업 이력) 테이블
CREATE TABLE IF NOT EXISTS system_backups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  backup_type VARCHAR(20) DEFAULT 'manual' CHECK (backup_type IN ('manual', 'automatic', 'scheduled')),
  backup_scope VARCHAR(20) DEFAULT 'full' CHECK (backup_scope IN ('full', 'partial', 'incremental')),
  tables_included TEXT[], -- 백업에 포함된 테이블 목록
  backup_size_bytes BIGINT, -- 백업 파일 크기 (bytes)
  backup_location TEXT, -- 백업 파일 위치/URL
  status VARCHAR(20) DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'failed')),
  initiated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  completed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  metadata JSONB -- 추가 메타데이터
);

-- 5. System Notifications (시스템 알림) 테이블
CREATE TABLE IF NOT EXISTS system_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  notification_type VARCHAR(50) NOT NULL, -- [error, warning, info, success]
  severity VARCHAR(20) DEFAULT 'info' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  target_users UUID[], -- 알림을 받을 사용자 (NULL이면 모든 관리자)
  read_by UUID[], -- 읽은 사용자 목록
  action_url TEXT, -- 액션 링크
  metadata JSONB,
  expires_at TIMESTAMP WITH TIME ZONE, -- 알림 만료 시간
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 6. System Metrics (시스템 메트릭) 테이블 - 성능 모니터링
CREATE TABLE IF NOT EXISTS system_metrics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  metric_type VARCHAR(50) NOT NULL, -- [cpu, memory, disk, database, api_response_time 등]
  metric_name VARCHAR(100) NOT NULL,
  metric_value DECIMAL(20, 4) NOT NULL,
  unit VARCHAR(20), -- [percent, ms, mb, count 등]
  metadata JSONB,
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 인덱스 생성
CREATE INDEX idx_admin_action_logs_admin_id ON admin_action_logs(admin_id);
CREATE INDEX idx_admin_action_logs_action_type ON admin_action_logs(action_type);
CREATE INDEX idx_admin_action_logs_created_at ON admin_action_logs(created_at);
CREATE INDEX idx_admin_action_logs_target_type_id ON admin_action_logs(target_type, target_id);

CREATE INDEX idx_access_logs_user_id ON access_logs(user_id);
CREATE INDEX idx_access_logs_endpoint ON access_logs(endpoint);
CREATE INDEX idx_access_logs_created_at ON access_logs(created_at);
CREATE INDEX idx_access_logs_status_code ON access_logs(status_code);

CREATE INDEX idx_error_logs_user_id ON error_logs(user_id);
CREATE INDEX idx_error_logs_error_type ON error_logs(error_type);
CREATE INDEX idx_error_logs_severity ON error_logs(severity);
CREATE INDEX idx_error_logs_resolved ON error_logs(resolved);
CREATE INDEX idx_error_logs_created_at ON error_logs(created_at);

CREATE INDEX idx_system_backups_status ON system_backups(status);
CREATE INDEX idx_system_backups_backup_type ON system_backups(backup_type);
CREATE INDEX idx_system_backups_started_at ON system_backups(started_at);

CREATE INDEX idx_system_notifications_target_users ON system_notifications USING GIN(target_users);
CREATE INDEX idx_system_notifications_read_by ON system_notifications USING GIN(read_by);
CREATE INDEX idx_system_notifications_severity ON system_notifications(severity);
CREATE INDEX idx_system_notifications_created_at ON system_notifications(created_at);

CREATE INDEX idx_system_metrics_metric_type ON system_metrics(metric_type);
CREATE INDEX idx_system_metrics_recorded_at ON system_metrics(recorded_at);

-- RLS (Row Level Security) 정책 설정
ALTER TABLE admin_action_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_backups ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_metrics ENABLE ROW LEVEL SECURITY;

-- 관리자만 접근 가능한 정책
CREATE POLICY "Only admins can view admin action logs" ON admin_action_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

CREATE POLICY "Only admins can view access logs" ON access_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

CREATE POLICY "Only admins can manage error logs" ON error_logs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

CREATE POLICY "Only admins can manage backups" ON system_backups
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

CREATE POLICY "Admins can view all notifications" ON system_notifications
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

CREATE POLICY "Admins can update notifications" ON system_notifications
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

CREATE POLICY "Only admins can view system metrics" ON system_metrics
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

-- 트리거 함수: 오래된 로그 자동 정리 (90일 이상)
CREATE OR REPLACE FUNCTION cleanup_old_logs()
RETURNS void AS $$
BEGIN
  -- 90일 이상 된 access logs 삭제
  DELETE FROM access_logs WHERE created_at < NOW() - INTERVAL '90 days';

  -- 180일 이상 된 admin action logs 삭제
  DELETE FROM admin_action_logs WHERE created_at < NOW() - INTERVAL '180 days';

  -- 해결된 지 30일 이상 된 error logs 삭제
  DELETE FROM error_logs
  WHERE resolved = true
    AND resolved_at < NOW() - INTERVAL '30 days';

  -- 90일 이상 된 system metrics 삭제
  DELETE FROM system_metrics WHERE recorded_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- 트리거 함수: 시스템 메트릭 자동 수집
CREATE OR REPLACE FUNCTION collect_system_metrics()
RETURNS void AS $$
DECLARE
  total_users INTEGER;
  active_users_today INTEGER;
  total_transactions_today INTEGER;
  error_count_today INTEGER;
  avg_response_time DECIMAL;
BEGIN
  -- 총 사용자 수
  SELECT COUNT(*) INTO total_users FROM users;
  INSERT INTO system_metrics (metric_type, metric_name, metric_value, unit)
  VALUES ('users', 'total_users', total_users, 'count');

  -- 오늘 활성 사용자 수
  SELECT COUNT(*) INTO active_users_today
  FROM access_logs
  WHERE created_at > CURRENT_DATE;
  INSERT INTO system_metrics (metric_type, metric_name, metric_value, unit)
  VALUES ('users', 'active_users_today', active_users_today, 'count');

  -- 오늘 거래 건수
  SELECT COUNT(*) INTO total_transactions_today
  FROM transactions
  WHERE created_at > CURRENT_DATE;
  INSERT INTO system_metrics (metric_type, metric_name, metric_value, unit)
  VALUES ('transactions', 'total_transactions_today', total_transactions_today, 'count');

  -- 오늘 에러 건수
  SELECT COUNT(*) INTO error_count_today
  FROM error_logs
  WHERE created_at > CURRENT_DATE;
  INSERT INTO system_metrics (metric_type, metric_name, metric_value, unit)
  VALUES ('errors', 'error_count_today', error_count_today, 'count');

  -- 평균 응답 시간
  SELECT AVG(response_time) INTO avg_response_time
  FROM access_logs
  WHERE created_at > CURRENT_DATE;
  IF avg_response_time IS NOT NULL THEN
    INSERT INTO system_metrics (metric_type, metric_name, metric_value, unit)
    VALUES ('performance', 'avg_response_time_today', avg_response_time, 'ms');
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 뷰: 관리자 대시보드 통계
CREATE OR REPLACE VIEW admin_dashboard_stats AS
SELECT
  (SELECT COUNT(*) FROM users) as total_users,
  (SELECT COUNT(*) FROM users WHERE created_at > CURRENT_DATE - INTERVAL '30 days') as new_users_30d,
  (SELECT COUNT(*) FROM users WHERE role = '관리자') as total_admins,
  (SELECT COUNT(*) FROM products) as total_products,
  (SELECT COUNT(*) FROM products WHERE status = '판매중') as active_products,
  (SELECT COUNT(*) FROM transactions) as total_transactions,
  (SELECT COUNT(*) FROM transactions WHERE status = '거래완료') as completed_transactions,
  (SELECT COUNT(*) FROM transactions WHERE created_at > CURRENT_DATE) as transactions_today,
  (SELECT COALESCE(SUM(price), 0) FROM transactions WHERE status = '거래완료') as total_revenue,
  (SELECT COALESCE(SUM(price), 0) FROM transactions WHERE status = '거래완료' AND completed_at > CURRENT_DATE) as revenue_today,
  (SELECT COUNT(*) FROM error_logs WHERE resolved = false) as unresolved_errors,
  (SELECT COUNT(*) FROM error_logs WHERE severity = 'critical' AND resolved = false) as critical_errors,
  (SELECT COUNT(*) FROM reports WHERE status = 'pending') as pending_reports,
  (SELECT COUNT(*) FROM system_notifications WHERE 'unread' = ANY(target_users)) as unread_notifications;

-- 뷰: 실시간 시스템 상태
CREATE OR REPLACE VIEW system_health_status AS
SELECT
  (SELECT COUNT(*) FROM error_logs WHERE created_at > NOW() - INTERVAL '1 hour') as errors_last_hour,
  (SELECT COUNT(*) FROM error_logs WHERE severity = 'critical' AND created_at > NOW() - INTERVAL '1 hour') as critical_errors_last_hour,
  (SELECT AVG(response_time) FROM access_logs WHERE created_at > NOW() - INTERVAL '1 hour') as avg_response_time_last_hour,
  (SELECT COUNT(*) FROM access_logs WHERE created_at > NOW() - INTERVAL '1 hour') as requests_last_hour,
  (SELECT COUNT(DISTINCT user_id) FROM access_logs WHERE created_at > NOW() - INTERVAL '1 hour') as active_users_last_hour,
  (SELECT metric_value FROM system_metrics WHERE metric_name = 'avg_response_time_today' ORDER BY recorded_at DESC LIMIT 1) as current_avg_response_time;

-- 코멘트 추가
COMMENT ON TABLE admin_action_logs IS '관리자 액션 로그 - 모든 관리자 작업을 추적';
COMMENT ON TABLE access_logs IS '접근 로그 - 모든 API 요청을 기록';
COMMENT ON TABLE error_logs IS '오류 로그 - 시스템 오류를 추적하고 관리';
COMMENT ON TABLE system_backups IS '백업 이력 - 데이터베이스 백업 상태를 관리';
COMMENT ON TABLE system_notifications IS '시스템 알림 - 관리자에게 중요 이벤트 알림';
COMMENT ON TABLE system_metrics IS '시스템 메트릭 - 성능 및 사용량 지표를 저장';
