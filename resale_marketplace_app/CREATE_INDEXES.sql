-- ========================================
-- 데이터베이스 성능 최적화 인덱스
-- ========================================
-- 실제 확인된 스키마:
-- ✅ products: seller_id (NOT user_id, NO buyer_id, NO deleted_at)
-- ✅ messages: chat_id (NOT chat_room_id)
-- ✅ chats: participants uuid[] (NOT chat_rooms, NOT participant1_id/2_id)
-- ✅ transactions: buyer_id, seller_id, status

-- ========================================
-- Products 테이블 인덱스
-- ========================================

-- 판매자별 상품 조회
CREATE INDEX IF NOT EXISTS idx_products_seller_id
ON products(seller_id);

-- 상태별 검색
CREATE INDEX IF NOT EXISTS idx_products_status
ON products(status);

-- 복합: 판매자 + 상태
CREATE INDEX IF NOT EXISTS idx_products_seller_status
ON products(seller_id, status);

-- 생성일 정렬
CREATE INDEX IF NOT EXISTS idx_products_created_at
ON products(created_at DESC);

-- ========================================
-- Transactions 테이블 인덱스
-- ========================================

-- 판매자별 거래
CREATE INDEX IF NOT EXISTS idx_transactions_seller
ON transactions(seller_id, created_at DESC);

-- 구매자별 거래
CREATE INDEX IF NOT EXISTS idx_transactions_buyer
ON transactions(buyer_id, created_at DESC);

-- 상태별 조회
CREATE INDEX IF NOT EXISTS idx_transactions_status
ON transactions(status);

-- ========================================
-- Messages 테이블 인덱스
-- ========================================

-- 채팅별 메시지 (chat_id 사용)
CREATE INDEX IF NOT EXISTS idx_messages_chat_id
ON messages(chat_id, created_at DESC);

-- 발신자별
CREATE INDEX IF NOT EXISTS idx_messages_sender
ON messages(sender_id);

-- ========================================
-- Chats 테이블 인덱스
-- ========================================

-- 참여자 배열 검색용 (GIN 인덱스)
CREATE INDEX IF NOT EXISTS idx_chats_participants
ON chats USING GIN (participants);

-- 상품별 채팅
CREATE INDEX IF NOT EXISTS idx_chats_product
ON chats(product_id);

-- 업데이트 시간
CREATE INDEX IF NOT EXISTS idx_chats_updated_at
ON chats(updated_at DESC);

-- ========================================
-- 생성된 인덱스 확인
-- ========================================

SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('products', 'transactions', 'messages', 'chats')
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
