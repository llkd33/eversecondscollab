-- 채팅 테이블에 대신판매자 정보 추가
-- 대신팔기 중개 채팅방인 경우 중개자 정보를 명시

-- Chats 테이블에 대신판매자 정보 컬럼 추가
ALTER TABLE chats 
ADD COLUMN IF NOT EXISTS reseller_id UUID REFERENCES users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS is_resale_chat BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS original_seller_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- 대신팔기 채팅방인 경우:
-- - reseller_id: 대신판매자 ID
-- - is_resale_chat: true
-- - original_seller_id: 원 판매자 ID
-- - participants: [구매자ID, 대신판매자ID] (원 판매자는 별도 관리)

-- 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_chats_reseller_id ON chats(reseller_id);
CREATE INDEX IF NOT EXISTS idx_chats_product_id ON chats(product_id);
CREATE INDEX IF NOT EXISTS idx_chats_participants ON chats USING GIN(participants);

-- Messages 테이블에 읽음 상태 추가
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'system'));

-- 시스템 메시지 타입 추가 (대신팔기 안내 등)