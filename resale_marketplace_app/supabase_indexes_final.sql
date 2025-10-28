-- ========================================
-- 데이터베이스 성능 최적화 인덱스 (최종 수정본)
-- ========================================
-- 실제 스키마 확인 완료:
-- - products 테이블: seller_id 사용
-- - messages 테이블: chat_id 사용 (chat_room_id 아님)
-- - chats 테이블: chat_rooms 아님
-- - deleted_at, buyer_id (products) 컬럼 없음

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

-- 카테고리별 필터링 (카테고리 컬럼이 있는 경우)
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

-- 채팅별 메시지 (chat_id 사용)
CREATE INDEX IF NOT EXISTS idx_messages_chat_id
ON messages(chat_id, created_at DESC);

-- 발신자별 메시지
CREATE INDEX IF NOT EXISTS idx_messages_sender
ON messages(sender_id);

-- 읽지 않은 메시지 (is_read 컬럼이 있는 경우)
CREATE INDEX IF NOT EXISTS idx_messages_unread
ON messages(chat_id, is_read)
WHERE is_read = false;

-- ========================================
-- Chats 테이블 인덱스
-- ========================================

-- 참여자별 채팅 (participants 배열 또는 개별 컬럼 확인 필요)
-- participants 배열을 사용하는 경우:
CREATE INDEX IF NOT EXISTS idx_chats_participants
ON chats USING GIN (participants);

-- 상품별 채팅
CREATE INDEX IF NOT EXISTS idx_chats_product
ON chats(product_id);

-- 업데이트 시간 정렬
CREATE INDEX IF NOT EXISTS idx_chats_updated_at
ON chats(updated_at DESC);

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
  AND tablename IN ('products', 'transactions', 'messages', 'chats')
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

-- Messages 조회 테스트
EXPLAIN ANALYZE
SELECT * FROM messages
WHERE chat_id = (SELECT id FROM chats LIMIT 1)
ORDER BY created_at DESC
LIMIT 50;

-- Chats 조회 테스트 (participants 배열 사용)
EXPLAIN ANALYZE
SELECT * FROM chats
WHERE (SELECT id FROM auth.users LIMIT 1) = ANY(participants)
ORDER BY updated_at DESC;
