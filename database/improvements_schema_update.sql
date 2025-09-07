-- Everseconds 앱 개선사항을 위한 데이터베이스 스키마 업데이트
-- 실행일: 2025-01-07

-- 1. FCM 토큰 관리 테이블
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

-- 2. 검색 로그 테이블 (통계용)
CREATE TABLE IF NOT EXISTS search_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    search_term TEXT NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    results_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 사용자 검색 기록 테이블
CREATE TABLE IF NOT EXISTS user_search_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    search_term TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, search_term)
);

-- 4. 알림 로그 테이블
CREATE TABLE IF NOT EXISTS notification_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    notification_type TEXT NOT NULL,
    is_sent BOOLEAN DEFAULT false,
    sent_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. 에러 로그 테이블
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    error_type TEXT NOT NULL,
    error_code TEXT NOT NULL,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    user_agent TEXT,
    app_version TEXT,
    platform TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. 사용자 테이블에 신뢰도 관련 컬럼 추가
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS trust_score INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS level INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS transaction_count INTEGER DEFAULT 0;

-- 7. 리뷰 테이블에 이미지 컬럼 추가
ALTER TABLE reviews 
ADD COLUMN IF NOT EXISTS image_urls TEXT[];

-- 8. 상품 테이블에 조회수 컬럼 추가
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS like_count INTEGER DEFAULT 0;

-- 9. 상품 찜하기 테이블
CREATE TABLE IF NOT EXISTS product_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- 10. 사용자 팔로우 테이블
CREATE TABLE IF NOT EXISTS user_follows (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK(follower_id != following_id)
);

-- 11. 앱 설정 테이블
CREATE TABLE IF NOT EXISTS app_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    setting_key TEXT NOT NULL,
    setting_value JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, setting_key)
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_active ON user_fcm_tokens(is_active);
CREATE INDEX IF NOT EXISTS idx_search_logs_term ON search_logs(search_term);
CREATE INDEX IF NOT EXISTS idx_search_logs_created_at ON search_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_user_search_history_user_id ON user_search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id ON notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_type ON notification_logs(notification_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_error_type ON error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_products_view_count ON products(view_count);
CREATE INDEX IF NOT EXISTS idx_products_like_count ON products(like_count);
CREATE INDEX IF NOT EXISTS idx_product_likes_user_id ON product_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_product_likes_product_id ON product_likes(product_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_following ON user_follows(following_id);

-- RLS (Row Level Security) 정책 설정

-- FCM 토큰: 사용자는 자신의 토큰만 관리 가능
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own FCM tokens" ON user_fcm_tokens
    FOR ALL USING (auth.uid() = user_id);

-- 검색 기록: 사용자는 자신의 검색 기록만 조회/관리 가능
ALTER TABLE user_search_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own search history" ON user_search_history
    FOR ALL USING (auth.uid() = user_id);

-- 알림 로그: 사용자는 자신의 알림만 조회 가능
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own notifications" ON notification_logs
    FOR SELECT USING (auth.uid() = user_id);

-- 에러 로그: 관리자만 조회 가능
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Only admins can view error logs" ON error_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = '관리자'
        )
    );

-- 상품 찜하기: 사용자는 자신의 찜 목록만 관리 가능
ALTER TABLE product_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own likes" ON product_likes
    FOR ALL USING (auth.uid() = user_id);

-- 사용자 팔로우: 사용자는 자신과 관련된 팔로우만 관리 가능
ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own follows" ON user_follows
    FOR ALL USING (auth.uid() = follower_id OR auth.uid() = following_id);

-- 앱 설정: 사용자는 자신의 설정만 관리 가능
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own settings" ON app_settings
    FOR ALL USING (auth.uid() = user_id);

-- 검색 로그는 모든 사용자가 삽입 가능 (통계용)
ALTER TABLE search_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can insert search logs" ON search_logs
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can view their own search logs" ON search_logs
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

-- 함수: 상품 조회수 증가
CREATE OR REPLACE FUNCTION increment_product_view_count(product_uuid UUID)
RETURNS void AS $$
BEGIN
    UPDATE products 
    SET view_count = view_count + 1,
        updated_at = NOW()
    WHERE id = product_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 함수: 사용자 신뢰도 점수 계산
CREATE OR REPLACE FUNCTION calculate_user_trust_score(user_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    avg_rating DECIMAL;
    review_count INTEGER;
    transaction_count INTEGER;
    trust_score INTEGER;
BEGIN
    -- 평균 평점 조회
    SELECT AVG(rating), COUNT(*) 
    INTO avg_rating, review_count
    FROM reviews 
    WHERE reviewee_id = user_uuid;
    
    -- 거래 완료 수 조회
    SELECT COUNT(*) 
    INTO transaction_count
    FROM transactions 
    WHERE (buyer_id = user_uuid OR seller_id = user_uuid) 
    AND status = '거래완료';
    
    -- 신뢰도 점수 계산 (0-100)
    trust_score := 0;
    
    IF review_count > 0 THEN
        -- 평점 기반 점수 (0-60점)
        trust_score := trust_score + (avg_rating / 5.0 * 60)::INTEGER;
        
        -- 리뷰 수 기반 점수 (0-20점)
        trust_score := trust_score + LEAST(review_count, 50) * 20 / 50;
        
        -- 거래 수 기반 점수 (0-20점)
        trust_score := trust_score + LEAST(transaction_count, 100) * 20 / 100;
    END IF;
    
    -- 사용자 테이블 업데이트
    UPDATE users 
    SET trust_score = trust_score,
        level = CASE 
            WHEN trust_score >= 90 THEN 10
            WHEN trust_score >= 80 THEN 9
            WHEN trust_score >= 70 THEN 8
            WHEN trust_score >= 60 THEN 7
            WHEN trust_score >= 50 THEN 6
            WHEN trust_score >= 40 THEN 5
            WHEN trust_score >= 30 THEN 4
            WHEN trust_score >= 20 THEN 3
            WHEN trust_score >= 10 THEN 2
            ELSE 1
        END,
        transaction_count = transaction_count,
        updated_at = NOW()
    WHERE id = user_uuid;
    
    RETURN trust_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거: 리뷰 작성/수정/삭제 시 신뢰도 점수 자동 업데이트
CREATE OR REPLACE FUNCTION update_trust_score_on_review_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM calculate_user_trust_score(OLD.reviewee_id);
        RETURN OLD;
    ELSE
        PERFORM calculate_user_trust_score(NEW.reviewee_id);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_trust_score ON reviews;
CREATE TRIGGER trigger_update_trust_score
    AFTER INSERT OR UPDATE OR DELETE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_trust_score_on_review_change();

-- 트리거: 거래 완료 시 신뢰도 점수 업데이트
CREATE OR REPLACE FUNCTION update_trust_score_on_transaction_complete()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = '거래완료' AND OLD.status != '거래완료' THEN
        PERFORM calculate_user_trust_score(NEW.buyer_id);
        PERFORM calculate_user_trust_score(NEW.seller_id);
        IF NEW.reseller_id IS NOT NULL THEN
            PERFORM calculate_user_trust_score(NEW.reseller_id);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_trust_score_on_transaction ON transactions;
CREATE TRIGGER trigger_update_trust_score_on_transaction
    AFTER UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_trust_score_on_transaction_complete();

-- 뷰: 인기 검색어 (최근 7일)
CREATE OR REPLACE VIEW popular_search_terms AS
SELECT 
    search_term,
    COUNT(*) as search_count,
    MAX(created_at) as last_searched
FROM search_logs 
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY search_term
ORDER BY search_count DESC, last_searched DESC
LIMIT 20;

-- 뷰: 사용자 통계
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    u.id,
    u.name,
    u.level,
    u.trust_score,
    u.rating,
    u.review_count,
    u.transaction_count,
    COALESCE(pl.like_count, 0) as received_likes,
    COALESCE(f1.follower_count, 0) as follower_count,
    COALESCE(f2.following_count, 0) as following_count
FROM users u
LEFT JOIN (
    SELECT 
        p.seller_id,
        COUNT(*) as like_count
    FROM product_likes pl
    JOIN products p ON pl.product_id = p.id
    GROUP BY p.seller_id
) pl ON u.id = pl.seller_id
LEFT JOIN (
    SELECT 
        following_id,
        COUNT(*) as follower_count
    FROM user_follows
    GROUP BY following_id
) f1 ON u.id = f1.following_id
LEFT JOIN (
    SELECT 
        follower_id,
        COUNT(*) as following_count
    FROM user_follows
    GROUP BY follower_id
) f2 ON u.id = f2.follower_id;

-- 초기 데이터 마이그레이션: 기존 사용자들의 신뢰도 점수 계산
DO $$
DECLARE
    user_record RECORD;
BEGIN
    FOR user_record IN SELECT id FROM users LOOP
        PERFORM calculate_user_trust_score(user_record.id);
    END LOOP;
END $$;

-- 완료 메시지
SELECT 'Database schema update completed successfully!' as message;