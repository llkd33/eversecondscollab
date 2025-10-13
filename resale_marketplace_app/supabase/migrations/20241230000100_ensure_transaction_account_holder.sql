-- Ensure transaction_account_holder column exists in products table
-- This migration ensures the column exists to fix upload issues

-- Add transaction_account_holder column if it doesn't exist
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS transaction_account_holder VARCHAR(50);

-- Add comment for documentation
COMMENT ON COLUMN public.products.transaction_account_holder IS 'Account holder name for product-specific transactions';

-- Create index if it doesn't exist for performance
CREATE INDEX IF NOT EXISTS idx_products_transaction_account_holder 
ON public.products(transaction_account_holder) 
WHERE transaction_account_holder IS NOT NULL;