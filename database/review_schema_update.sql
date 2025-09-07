-- Add tags and images columns to reviews table
-- This script adds the missing columns for the review system

-- Add tags column (array of strings for evaluation tags)
ALTER TABLE reviews 
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- Add images column (array of strings for review image URLs)
ALTER TABLE reviews 
ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}';

-- Update the unique constraint to allow multiple reviews per transaction
-- (since users can review multiple people in a transaction)
ALTER TABLE reviews 
DROP CONSTRAINT IF EXISTS reviews_reviewer_id_transaction_id_key;

-- Add new constraint: one review per reviewer-reviewee pair per transaction
ALTER TABLE reviews 
ADD CONSTRAINT reviews_reviewer_reviewee_transaction_unique 
UNIQUE(reviewer_id, reviewed_user_id, transaction_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewed_user_id ON reviews(reviewed_user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_transaction_id ON reviews(transaction_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at);

-- Update RLS policies for reviews table
DROP POLICY IF EXISTS "Anyone can view reviews" ON reviews;
DROP POLICY IF EXISTS "Transaction participants can create reviews" ON reviews;

-- Anyone can view reviews (for public review display)
CREATE POLICY "Anyone can view reviews" ON reviews
  FOR SELECT USING (true);

-- Transaction participants can create reviews
CREATE POLICY "Transaction participants can create reviews" ON reviews
  FOR INSERT WITH CHECK (
    auth.uid() = reviewer_id AND
    EXISTS (
      SELECT 1 FROM transactions 
      WHERE transactions.id = reviews.transaction_id 
      AND auth.uid() IN (transactions.buyer_id, transactions.seller_id, transactions.reseller_id)
    )
  );

-- Reviewers can update their own reviews
CREATE POLICY "Reviewers can update own reviews" ON reviews
  FOR UPDATE USING (auth.uid() = reviewer_id);

-- Reviewers can delete their own reviews
CREATE POLICY "Reviewers can delete own reviews" ON reviews
  FOR DELETE USING (auth.uid() = reviewer_id);