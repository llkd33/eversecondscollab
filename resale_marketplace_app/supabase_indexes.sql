-- ========================================
-- 데이터베이스 성능 최적화 인덱스
-- ========================================
-- 이 스크립트를 Supabase Dashboard → SQL Editor에서 실행하세요
-- 예상 실행 시간: 1-2분
-- 예상 효과: 쿼리 속도 5-10배 개선

-- ========================================
-- Products 테이블 인덱스
-- ========================================
-- Note: These indexes are already created in 20240101_add_performance_indexes.sql
-- This file is kept for documentation and reference purposes

-- Already exists: idx_products_user_status
-- CREATE INDEX IF NOT EXISTS idx_products_user_status
-- ON products(user_id, status, created_at DESC);

-- Already exists: idx_products_active_search
-- CREATE INDEX IF NOT EXISTS idx_products_active_search
-- ON products(status, created_at DESC)
-- WHERE status = 'active';

-- Already exists: idx_products_category_status
-- CREATE INDEX IF NOT EXISTS idx_products_category_status
-- ON products(category, status, price);

-- ========================================
-- Transactions 테이블 인덱스
-- ========================================
-- Note: These indexes are already created in 20240101_add_performance_indexes.sql

-- Already exists: idx_transactions_buyer
-- CREATE INDEX IF NOT EXISTS idx_transactions_buyer
-- ON transactions(buyer_id, status, created_at DESC);

-- Already exists: idx_transactions_seller
-- CREATE INDEX IF NOT EXISTS idx_transactions_seller
-- ON transactions(seller_id, status, created_at DESC);

-- Already exists: idx_transactions_parties
-- CREATE INDEX IF NOT EXISTS idx_transactions_parties
-- ON transactions(buyer_id, seller_id, status);

-- ========================================
-- Messages 테이블 인덱스
-- ========================================
-- Note: These indexes are already created in 20240101_add_performance_indexes.sql

-- Already exists: idx_messages_conversation
-- CREATE INDEX IF NOT EXISTS idx_messages_conversation
-- ON messages(chat_room_id, created_at DESC);

-- Already exists: idx_messages_unread
-- CREATE INDEX IF NOT EXISTS idx_messages_unread
-- ON messages(chat_room_id, recipient_id, is_read)
-- WHERE is_read = false;

-- ========================================
-- Chat Rooms 테이블 인덱스
-- ========================================
-- Note: These indexes are already created in 20240101_add_performance_indexes.sql

-- Already exists: idx_chat_rooms_participant1
-- CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant1
-- ON chat_rooms(participant1_id, updated_at DESC);

-- Already exists: idx_chat_rooms_participant2
-- CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant2
-- ON chat_rooms(participant2_id, updated_at DESC);

-- Already exists: idx_chat_rooms_product
-- CREATE INDEX IF NOT EXISTS idx_chat_rooms_product
-- ON chat_rooms(product_id, created_at DESC);

-- ========================================
-- 인덱스 생성 확인
-- ========================================

-- 생성된 인덱스 확인
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ========================================
-- 성능 테스트 쿼리
-- ========================================

-- 1. Products 조회 성능 테스트
EXPLAIN ANALYZE
SELECT * FROM products
WHERE seller_id = (SELECT id FROM auth.users LIMIT 1)
ORDER BY created_at DESC
LIMIT 20;

-- 2. Chat Rooms 조회 성능 테스트
EXPLAIN ANALYZE
SELECT * FROM chat_rooms
WHERE participant1_id = (SELECT id FROM auth.users LIMIT 1)
   OR participant2_id = (SELECT id FROM auth.users LIMIT 1)
ORDER BY updated_at DESC;

-- 인덱스가 사용되면 "Index Scan"이 표시되어야 합니다.
-- "Seq Scan"이 표시되면 인덱스가 사용되지 않는 것입니다.
