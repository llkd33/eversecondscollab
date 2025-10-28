# Database Schema Fix - Column Name Corrections

## Issues Found

The SQL index files were referencing columns that don't exist in the actual database schema:

### ❌ Incorrect Column References
1. **`deleted_at`** - Column doesn't exist in `products` table
2. **`buyer_id`** - Column doesn't exist in `products` table (uses `user_id` instead)
3. **`seller_id`** - Products table uses `user_id`, not `seller_id`
4. **`chat_id`** - Table is named `chat_rooms`, messages reference `chat_room_id`
5. **`chats`** - Table is actually named `chat_rooms`

### ✅ Actual Schema (from 20240101_add_performance_indexes.sql)

**Products Table:**
- `user_id` - The owner/seller of the product
- `status` - Product status (active, sold, etc.)
- `category` - Product category
- `price` - Product price
- `created_at` - Creation timestamp
- **NO** `deleted_at`, `buyer_id`, or `seller_id` columns

**Transactions Table:**
- `buyer_id` - ✅ Exists
- `seller_id` - ✅ Exists
- `product_id` - ✅ Exists
- `status` - ✅ Exists

**Messages Table:**
- `chat_room_id` - ✅ Exists (not `chat_id`)
- `recipient_id` - ✅ Exists
- `is_read` - ✅ Exists

**Chat Rooms Table:**
- `participant1_id` - ✅ Exists
- `participant2_id` - ✅ Exists
- `product_id` - ✅ Exists

## Files Fixed

### 1. `supabase_indexes.sql`
**Changes:**
- Removed all references to non-existent `deleted_at` column
- Removed references to non-existent `buyer_id` in products table
- Changed `seller_id` to `user_id` for products
- Changed `chats` to `chat_rooms`
- Changed `chat_id` to `chat_room_id`
- **Added note:** Most indexes already exist from migration `20240101_add_performance_indexes.sql`

### 2. `PERFORMANCE_GUIDE.md`
**Changes:**
- Updated section 2: Changed from "인덱스 부재" to acknowledge existing indexes
- Updated index creation examples to match actual schema
- Changed `seller:users!seller_id` to `user:users!user_id`
- Removed `buyer_id` from products queries
- Updated test queries to use correct column names
- Updated checklist to show indexes already applied

## Current Index Status

### ✅ Already Applied (from 20240101_add_performance_indexes.sql)

**Products:**
- `idx_products_user_status` - ON products(user_id, status, created_at DESC)
- `idx_products_active_search` - ON products(status, created_at DESC) WHERE status = 'active'
- `idx_products_category_status` - ON products(category, status, price)
- `idx_products_search_text` - Full-text search on title and description

**Transactions:**
- `idx_transactions_buyer` - ON transactions(buyer_id, status, created_at DESC)
- `idx_transactions_seller` - ON transactions(seller_id, status, created_at DESC)
- `idx_transactions_parties` - ON transactions(buyer_id, seller_id, status)
- `idx_transactions_pending` - Partial index for pending transactions

**Messages:**
- `idx_messages_conversation` - ON messages(chat_room_id, created_at DESC)
- `idx_messages_unread` - Partial index for unread messages

**Chat Rooms:**
- `idx_chat_rooms_participant1` - ON chat_rooms(participant1_id, updated_at DESC)
- `idx_chat_rooms_participant2` - ON chat_rooms(participant2_id, updated_at DESC)
- `idx_chat_rooms_product` - ON chat_rooms(product_id, created_at DESC)

**Other Tables:**
- Reviews, Shops, Reports, Product Images, User Favorites, Notifications

## Verification Steps

Run this query in Supabase SQL Editor to verify all indexes:

```sql
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
```

## Test Query Examples

### Products - User's Products
```sql
EXPLAIN ANALYZE
SELECT * FROM products
WHERE user_id = 'user-uuid-here'
  AND status = 'active'
ORDER BY created_at DESC
LIMIT 20;
```

### Chat Rooms - User's Chats
```sql
EXPLAIN ANALYZE
SELECT * FROM chat_rooms
WHERE participant1_id = 'user-uuid-here'
   OR participant2_id = 'user-uuid-here'
ORDER BY updated_at DESC;
```

## Next Steps

1. ✅ Schema errors fixed in SQL files
2. ✅ Documentation updated to reflect actual schema
3. ⏳ Verify indexes are being used (run EXPLAIN ANALYZE queries)
4. ⏳ Implement N+1 query optimizations in Dart code
5. ⏳ Add performance monitoring

## Notes

- The original `supabase_indexes.sql` file was based on assumptions about soft-delete and different column naming
- The actual migration `20240101_add_performance_indexes.sql` already created comprehensive indexes
- No new indexes need to be created - focus should be on query optimization in application code
- If soft-delete functionality is needed in the future, add migration to add `deleted_at TIMESTAMPTZ` column
