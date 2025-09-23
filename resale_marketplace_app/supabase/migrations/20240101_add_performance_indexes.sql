-- Performance optimization indexes for Everseconds marketplace
-- Created: 2024-01-01
-- Purpose: Improve query performance for common operations

-- ============================================
-- Products table indexes
-- ============================================

-- Index for user's products listing (My Products screen)
CREATE INDEX IF NOT EXISTS idx_products_user_status 
ON products(user_id, status, created_at DESC);

-- Index for active products search
CREATE INDEX IF NOT EXISTS idx_products_active_search 
ON products(status, created_at DESC) 
WHERE status = 'active';

-- Index for category-based filtering
CREATE INDEX IF NOT EXISTS idx_products_category_status 
ON products(category, status, price);

-- Index for text search (title and description)
CREATE INDEX IF NOT EXISTS idx_products_search_text 
ON products USING GIN(to_tsvector('korean', title || ' ' || description));

-- ============================================
-- Transactions table indexes
-- ============================================

-- Index for user's transactions (both buyer and seller)
CREATE INDEX IF NOT EXISTS idx_transactions_buyer 
ON transactions(buyer_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_seller 
ON transactions(seller_id, status, created_at DESC);

-- Composite index for transaction parties
CREATE INDEX IF NOT EXISTS idx_transactions_parties 
ON transactions(buyer_id, seller_id, status);

-- Index for pending transactions monitoring
CREATE INDEX IF NOT EXISTS idx_transactions_pending 
ON transactions(status, created_at DESC) 
WHERE status IN ('pending', 'in_progress');

-- ============================================
-- Messages table indexes
-- ============================================

-- Index for chat room messages (optimized for pagination)
CREATE INDEX IF NOT EXISTS idx_messages_conversation 
ON messages(chat_room_id, created_at DESC);

-- Index for unread messages count
CREATE INDEX IF NOT EXISTS idx_messages_unread 
ON messages(chat_room_id, recipient_id, is_read) 
WHERE is_read = false;

-- ============================================
-- Chat rooms table indexes
-- ============================================

-- Index for user's chat rooms
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant1 
ON chat_rooms(participant1_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant2 
ON chat_rooms(participant2_id, updated_at DESC);

-- Index for product-related chats
CREATE INDEX IF NOT EXISTS idx_chat_rooms_product 
ON chat_rooms(product_id, created_at DESC);

-- ============================================
-- Reviews table indexes
-- ============================================

-- Index for user's received reviews
CREATE INDEX IF NOT EXISTS idx_reviews_reviewed_user 
ON reviews(reviewed_user_id, created_at DESC);

-- Index for transaction reviews
CREATE INDEX IF NOT EXISTS idx_reviews_transaction 
ON reviews(transaction_id);

-- Index for rating statistics
CREATE INDEX IF NOT EXISTS idx_reviews_rating_stats 
ON reviews(reviewed_user_id, rating);

-- ============================================
-- Shops table indexes
-- ============================================

-- Index for shop search by name
CREATE INDEX IF NOT EXISTS idx_shops_name_search 
ON shops USING GIN(to_tsvector('korean', name || ' ' || description));

-- Index for verified shops
CREATE INDEX IF NOT EXISTS idx_shops_verified 
ON shops(is_verified, created_at DESC) 
WHERE is_verified = true;

-- ============================================
-- Reports table indexes
-- ============================================

-- Index for pending reports (admin)
CREATE INDEX IF NOT EXISTS idx_reports_pending 
ON reports(status, created_at DESC) 
WHERE status = 'pending';

-- Index for user's reports
CREATE INDEX IF NOT EXISTS idx_reports_reporter 
ON reports(reporter_id, created_at DESC);

-- ============================================
-- Product images table indexes
-- ============================================

-- Index for product images retrieval
CREATE INDEX IF NOT EXISTS idx_product_images_product 
ON product_images(product_id, display_order);

-- ============================================
-- User favorites table indexes
-- ============================================

-- Index for user's favorite products
CREATE INDEX IF NOT EXISTS idx_user_favorites_user 
ON user_favorites(user_id, created_at DESC);

-- Index for product's favorite count
CREATE INDEX IF NOT EXISTS idx_user_favorites_product 
ON user_favorites(product_id);

-- ============================================
-- Notifications table indexes (if exists)
-- ============================================

-- Check if notifications table exists before creating indexes
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'notifications') THEN
        -- Index for user's notifications
        CREATE INDEX IF NOT EXISTS idx_notifications_user 
        ON notifications(user_id, is_read, created_at DESC);
        
        -- Index for unread notifications
        CREATE INDEX IF NOT EXISTS idx_notifications_unread 
        ON notifications(user_id, created_at DESC) 
        WHERE is_read = false;
    END IF;
END $$;

-- ============================================
-- Function to update updated_at timestamp
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================
-- Apply updated_at triggers to all tables
-- ============================================

-- Products
DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at 
BEFORE UPDATE ON products 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Transactions
DROP TRIGGER IF EXISTS update_transactions_updated_at ON transactions;
CREATE TRIGGER update_transactions_updated_at 
BEFORE UPDATE ON transactions 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Chat rooms
DROP TRIGGER IF EXISTS update_chat_rooms_updated_at ON chat_rooms;
CREATE TRIGGER update_chat_rooms_updated_at 
BEFORE UPDATE ON chat_rooms 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Shops
DROP TRIGGER IF EXISTS update_shops_updated_at ON shops;
CREATE TRIGGER update_shops_updated_at 
BEFORE UPDATE ON shops 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Analyze tables for query planner optimization
-- ============================================

ANALYZE products;
ANALYZE transactions;
ANALYZE messages;
ANALYZE chat_rooms;
ANALYZE reviews;
ANALYZE shops;
ANALYZE reports;
ANALYZE product_images;
ANALYZE user_favorites;

-- ============================================
-- Create materialized view for user statistics
-- ============================================

CREATE MATERIALIZED VIEW user_statistics AS
SELECT 
    u.id as user_id,
    COUNT(DISTINCT p.id) as total_products,
    COUNT(DISTINCT p.id) FILTER (WHERE p.status = 'active') as active_products,
    COUNT(DISTINCT t.id) FILTER (WHERE t.seller_id = u.id) as total_sales,
    COUNT(DISTINCT t.id) FILTER (WHERE t.buyer_id = u.id) as total_purchases,
    AVG(r.rating) FILTER (WHERE r.reviewed_user_id = u.id) as average_rating,
    COUNT(DISTINCT r.id) FILTER (WHERE r.reviewed_user_id = u.id) as total_reviews
FROM 
    users u
    LEFT JOIN products p ON p.user_id = u.id
    LEFT JOIN transactions t ON t.seller_id = u.id OR t.buyer_id = u.id
    LEFT JOIN reviews r ON r.reviewed_user_id = u.id
GROUP BY u.id;

-- Create index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_statistics_user 
ON user_statistics(user_id);

-- Refresh materialized view (schedule this to run periodically)
REFRESH MATERIALIZED VIEW user_statistics;

-- ============================================
-- Performance monitoring views
-- ============================================

-- View for slow queries monitoring
CREATE OR REPLACE VIEW slow_queries AS
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    max_time,
    min_time
FROM pg_stat_statements
WHERE mean_time > 100 -- queries taking more than 100ms on average
ORDER BY mean_time DESC
LIMIT 50;

-- View for table sizes and bloat
CREATE OR REPLACE VIEW table_maintenance_info AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- ============================================
-- Comments for documentation
-- ============================================

COMMENT ON INDEX idx_products_user_status IS 'Optimizes user product listings and status filtering';
COMMENT ON INDEX idx_products_active_search IS 'Partial index for active products only, reduces index size';
COMMENT ON INDEX idx_transactions_parties IS 'Optimizes transaction lookups by involved parties';
COMMENT ON INDEX idx_messages_conversation IS 'Optimizes chat message pagination';
COMMENT ON MATERIALIZED VIEW user_statistics IS 'Pre-calculated user statistics for profile display';
