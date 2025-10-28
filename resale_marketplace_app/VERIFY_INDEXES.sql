-- ========================================
-- Step 1: Verify Database Indexes
-- ========================================
-- Run this in Supabase Dashboard → SQL Editor

-- 1. Check all created indexes
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('products', 'transactions', 'messages', 'chats')
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Expected: You should see indexes like:
-- - idx_products_seller_id
-- - idx_products_status
-- - idx_messages_chat_id
-- - idx_chats_participants
-- etc.

-- ========================================
-- 2. Verify indexes are being USED
-- ========================================

-- Test Products Query (should use idx_products_seller_id)
EXPLAIN ANALYZE
SELECT * FROM products
WHERE seller_id = (SELECT id FROM auth.users LIMIT 1)
ORDER BY created_at DESC
LIMIT 20;

-- ✅ Look for: "Index Scan using idx_products_seller_id"
-- ❌ Avoid: "Seq Scan on products"

-- Test Messages Query (should use idx_messages_chat_id)
EXPLAIN ANALYZE
SELECT * FROM messages
WHERE chat_id = (SELECT id FROM chats LIMIT 1)
ORDER BY created_at DESC
LIMIT 50;

-- ✅ Look for: "Index Scan using idx_messages_chat_id"

-- Test Chats Query (should use idx_chats_participants)
EXPLAIN ANALYZE
SELECT * FROM chats
WHERE (SELECT id FROM auth.users LIMIT 1) = ANY(participants)
ORDER BY updated_at DESC;

-- ✅ Look for: "Bitmap Index Scan on idx_chats_participants"

-- ========================================
-- 3. Check index sizes and health
-- ========================================

SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY pg_relation_size(indexrelid) DESC;

-- This shows how much space each index is using
