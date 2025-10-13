-- Fix missing account-related columns in products table
-- Run this directly in Supabase SQL Editor

-- Add all missing account-related columns if they don't exist
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS use_default_account BOOLEAN DEFAULT true;

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS transaction_bank_name VARCHAR(50);

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS transaction_account_number_encrypted TEXT;

-- Verify all columns were added
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'products' 
AND column_name IN ('use_default_account', 'transaction_bank_name', 'transaction_account_number_encrypted', 'transaction_account_holder')
ORDER BY column_name;