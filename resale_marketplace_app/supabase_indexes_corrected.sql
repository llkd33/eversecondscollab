-- ========================================
-- 데이터베이스 성능 최적화 인덱스 (수정본)
-- ========================================
-- Products 테이블은 seller_id를 사용합니다 (user_id 아님)
-- 테이블: products, transactions, messages (chat_room_id 사용), chat_rooms

-- ========================================
-- Products 테이블 인덱스
-- ========================================

-- 판매자별 상품 조회 최적화
CREATE INDEX IF NOT EXISTS idx_products_seller_id
ON products(seller_id);

-- 상태별 상품 검색 최적화
CREATE INDEX IF NOT EXISTS idx_products_status
ON products(status);

-- 복합 인덱스: 판매자 + 상태
CREATE INDEX IF NOT EXISTS idx_products_seller_status
ON products(seller_id, status);

-- 생성일 정렬 최적화
CREATE INDEX IF NOT EXISTS idx_products_created_at
ON products(created_at DESC);

-- 카테고리별 필터링 (있는 경우)
CREATE INDEX IF NOT EXISTS idx_products_category
ON products(category)
WHERE category IS NOT NULL;

-- ========================================
-- Transactions 테이블 인덱스
-- ========================================

-- 판매자별 거래 조회
CREATE INDEX IF NOT EXISTS idx_transactions_seller
ON transactions(seller_id, created_at DESC);

-- 구매자별 거래 조회
CREATE INDEX IF NOT EXISTS idx_transactions_buyer
ON transactions(buyer_id, created_at DESC);

-- 상태별 조회
CREATE INDEX IF NOT EXISTS idx_transactions_status
ON transactions(status, created_at DESC);

-- 복합: 판매자/구매자 + 상태
CREATE INDEX IF NOT EXISTS idx_transactions_parties
ON transactions(buyer_id, seller_id, status);

-- ========================================
-- Messages 테이블 인덱스
-- ========================================

-- 채팅방별 메시지 (chat_room_id 사용)
CREATE INDEX IF NOT EXISTS idx_messages_chat_room
ON messages(chat_room_id, created_at DESC);

-- 읽지 않은 메시지
CREATE INDEX IF NOT EXISTS idx_messages_unread
ON messages(chat_room_id, is_read)
WHERE is_read = false;

-- ========================================
-- Chat Rooms 테이블 인덱스
-- ========================================

-- 참여자별 채팅방
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant1
ON chat_rooms(participant1_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant2
ON chat_rooms(participant2_id, updated_at DESC);

-- 상품별 채팅방
CREATE INDEX IF NOT EXISTS idx_chat_rooms_product
ON chat_rooms(product_id);

-- ========================================
-- 인덱스 확인
-- ========================================

SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('products', 'transactions', 'messages', 'chat_rooms')
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ========================================
-- 성능 테스트
-- ========================================

-- Products 조회 테스트
EXPLAIN ANALYZE
SELECT * FROM products
WHERE seller_id = (SELECT id FROM auth.users LIMIT 1)
ORDER BY created_at DESC
LIMIT 20;

-- Chat Rooms 조회 테스트
EXPLAIN ANALYZE
SELECT * FROM chat_rooms
WHERE participant1_id = (SELECT id FROM auth.users LIMIT 1)
   OR participant2_id = (SELECT id FROM auth.users LIMIT 1)
ORDER BY updated_at DESC;
