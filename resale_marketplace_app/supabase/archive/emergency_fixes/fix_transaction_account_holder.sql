-- Fix missing transaction_account_holder column in products table
-- Run this directly in Supabase SQL Editor if migration system is having issues

-- Add the missing column if it doesn't exist
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS transaction_account_holder VARCHAR(50);

-- Verify the column was added
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'products' 
AND column_name = 'transaction_account_holder';