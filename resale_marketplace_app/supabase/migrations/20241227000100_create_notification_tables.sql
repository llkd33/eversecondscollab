-- 🔔 알림 시스템 테이블 생성
-- FCM 토큰 관리, 알림 설정, 알림 히스토리를 위한 테이블들

-- 1. FCM 토큰 관리 테이블
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    device_id TEXT,
    app_version TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 한 사용자가 같은 디바이스에서 중복 토큰을 가지지 않도록
    UNIQUE(user_id, fcm_token),
    -- 인덱스 추가
    INDEX idx_fcm_tokens_user_id (user_id),
    INDEX idx_fcm_tokens_active (user_id, is_active),
    INDEX idx_fcm_tokens_platform (platform)
);

-- 2. 사용자 알림 설정 테이블
CREATE TABLE IF NOT EXISTS user_notification_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    
    -- 알림 타입별 설정
    chat_notifications BOOLEAN DEFAULT true,
    transaction_notifications BOOLEAN DEFAULT true,
    resale_notifications BOOLEAN DEFAULT true,
    promotion_notifications BOOLEAN DEFAULT false,
    system_notifications BOOLEAN DEFAULT true,
    
    -- 방해 금지 시간 설정
    dnd_start_hour INTEGER CHECK (dnd_start_hour >= 0 AND dnd_start_hour <= 23),
    dnd_end_hour INTEGER CHECK (dnd_end_hour >= 0 AND dnd_end_hour <= 23),
    
    -- 알림 스타일 설정
    sound_enabled BOOLEAN DEFAULT true,
    vibration_enabled BOOLEAN DEFAULT true,
    badge_enabled BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    INDEX idx_notification_prefs_user_id (user_id)
);

-- 3. 알림 히스토리 테이블
CREATE TABLE IF NOT EXISTS notification_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- 알림 내용
    notification_type TEXT NOT NULL CHECK (notification_type IN (
        'chat_message', 'transaction', 'resale', 'system', 'promotion'
    )),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    
    -- 전송 정보
    fcm_message_id TEXT,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    clicked_at TIMESTAMP WITH TIME ZONE,
    
    -- 상태 정보
    status TEXT DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read', 'failed')),
    error_message TEXT,
    
    -- 관련 엔티티 정보
    related_entity_type TEXT, -- 'chat', 'transaction', 'product' 등
    related_entity_id UUID,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 인덱스
    INDEX idx_notification_history_user_id (user_id),
    INDEX idx_notification_history_type (notification_type),
    INDEX idx_notification_history_status (status),
    INDEX idx_notification_history_sent_at (sent_at),
    INDEX idx_notification_history_related (related_entity_type, related_entity_id)
);

-- 4. 알림 배치 큐 테이블 (대량 알림 처리용)
CREATE TABLE IF NOT EXISTS notification_queue (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- 알림 내용
    notification_type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    
    -- 수신자 정보
    target_user_ids UUID[] NOT NULL, -- 수신자 ID 배열
    target_criteria JSONB, -- 동적 수신자 선택 조건
    
    -- 스케줄링 정보
    scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- 처리 상태
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    processed_at TIMESTAMP WITH TIME ZONE,
    sent_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    error_message TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    INDEX idx_notification_queue_status (status),
    INDEX idx_notification_queue_scheduled (scheduled_at),
    INDEX idx_notification_queue_type (notification_type)
);

-- 5. 알림 템플릿 테이블 (재사용 가능한 알림 템플릿)
CREATE TABLE IF NOT EXISTS notification_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- 템플릿 정보
    name TEXT NOT NULL UNIQUE,
    notification_type TEXT NOT NULL,
    title_template TEXT NOT NULL, -- 예: "{{sender_name}}님이 메시지를 보냈습니다"
    body_template TEXT NOT NULL,
    
    -- 다국어 지원
    locale TEXT DEFAULT 'ko',
    
    -- 템플릿 설정
    is_active BOOLEAN DEFAULT true,
    variables JSONB DEFAULT '[]', -- 템플릿에서 사용하는 변수들
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    INDEX idx_notification_templates_type (notification_type),
    INDEX idx_notification_templates_active (is_active)
);

-- 6. 알림 성능 메트릭 테이블
CREATE TABLE IF NOT EXISTS notification_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- 메트릭 정보
    metric_date DATE NOT NULL,
    notification_type TEXT NOT NULL,
    
    -- 수치
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_read INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    total_failed INTEGER DEFAULT 0,
    
    -- 성능 지표
    avg_delivery_time_ms INTEGER,
    avg_read_time_ms INTEGER,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(metric_date, notification_type),
    INDEX idx_notification_metrics_date (metric_date),
    INDEX idx_notification_metrics_type (notification_type)
);

-- 트리거: updated_at 자동 업데이트
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 트리거 적용
CREATE TRIGGER update_user_fcm_tokens_updated_at BEFORE UPDATE ON user_fcm_tokens 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_notification_preferences_updated_at BEFORE UPDATE ON user_notification_preferences 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS (Row Level Security) 설정
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_history ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 데이터만 접근 가능
CREATE POLICY "Users can access own FCM tokens" ON user_fcm_tokens
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can access own notification preferences" ON user_notification_preferences
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can access own notification history" ON notification_history
    FOR ALL USING (auth.uid() = user_id);

-- 기본 알림 설정 데이터 삽입 함수
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_notification_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 새 사용자 가입 시 기본 알림 설정 생성
CREATE TRIGGER create_user_notification_preferences 
    AFTER INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION create_default_notification_preferences();

-- 초기 알림 템플릿 데이터
INSERT INTO notification_templates (name, notification_type, title_template, body_template, variables) VALUES
('chat_message', 'chat_message', '{{sender_name}}', '{{message_content}}', '["sender_name", "message_content"]'),
('transaction_created', 'transaction', '거래가 시작되었습니다', '{{product_title}} 거래가 시작되었습니다.', '["product_title"]'),
('transaction_completed', 'transaction', '거래가 완료되었습니다', '{{product_title}} 거래가 성공적으로 완료되었습니다.', '["product_title"]'),
('resale_request', 'resale', '대신판매 요청', '{{product_title}}에 대한 대신판매 요청이 있습니다.', '["product_title"]'),
('system_announcement', 'system', '공지사항', '{{announcement_content}}', '["announcement_content"]'),
('promotion_offer', 'promotion', '{{promotion_title}}', '{{promotion_content}}', '["promotion_title", "promotion_content"]')
ON CONFLICT (name) DO NOTHING;