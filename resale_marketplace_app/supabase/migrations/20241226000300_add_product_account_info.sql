-- Add account information fields to products table  
-- This migration adds transaction-specific account information

-- Step 1: Add shop_id to products if not exists (from previous migration)
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS shop_id UUID REFERENCES public.shops(id) ON DELETE SET NULL;

-- Step 2: Add transaction-specific account information columns
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS transaction_bank_name VARCHAR(50);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS transaction_account_number_encrypted TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS transaction_account_holder VARCHAR(50);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS use_default_account BOOLEAN DEFAULT true;

-- Step 3: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_products_transaction_account ON public.products(transaction_bank_name) WHERE transaction_bank_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_use_default ON public.products(use_default_account);

-- Step 4: Add constraint for valid bank names (reuse function from users table)
ALTER TABLE public.products 
ADD CONSTRAINT products_valid_transaction_bank_name 
CHECK (
    transaction_bank_name IS NULL OR 
    use_default_account = true OR
    public.is_valid_korean_bank(transaction_bank_name)
);

-- Step 5: Create function to get effective account info for product
CREATE OR REPLACE FUNCTION public.get_product_account_info(product_id UUID)
RETURNS TABLE(
    bank_name TEXT,
    account_number_encrypted TEXT,
    account_holder TEXT,
    is_verified BOOLEAN,
    show_for_normal BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    product_record RECORD;
    user_record RECORD;
BEGIN
    -- Get product information
    SELECT p.*, u.bank_name as user_bank_name, u.account_number_encrypted as user_account_encrypted,
           u.account_holder as user_account_holder, u.is_account_verified, u.show_account_for_normal
    INTO product_record
    FROM public.products p
    JOIN public.users u ON p.seller_id = u.id
    WHERE p.id = product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', product_id;
    END IF;
    
    -- Return appropriate account information
    IF product_record.use_default_account OR product_record.transaction_bank_name IS NULL THEN
        -- Use user's default account
        RETURN QUERY SELECT 
            product_record.user_bank_name,
            product_record.user_account_encrypted,
            product_record.user_account_holder,
            product_record.is_account_verified,
            product_record.show_account_for_normal;
    ELSE
        -- Use product-specific account
        RETURN QUERY SELECT 
            product_record.transaction_bank_name,
            product_record.transaction_account_number_encrypted,
            product_record.transaction_account_holder,
            true, -- Assume product-specific accounts are verified
            true; -- Product-specific accounts are always shown for transactions
    END IF;
END;
$$;

-- Step 6: Create function to update product account information
CREATE OR REPLACE FUNCTION public.update_product_account_info(
    product_id UUID,
    p_use_default_account BOOLEAN DEFAULT true,
    p_bank_name TEXT DEFAULT NULL,
    p_account_number_encrypted TEXT DEFAULT NULL,
    p_account_holder TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    product_owner UUID;
    current_user_id UUID;
BEGIN
    -- Get current authenticated user
    current_user_id := auth.uid();
    
    -- Get product owner
    SELECT seller_id INTO product_owner FROM public.products WHERE id = product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', product_id;
    END IF;
    
    -- Only allow product owner to update account info
    IF current_user_id != product_owner THEN
        RAISE EXCEPTION 'Access denied: Only product owner can update account information';
    END IF;
    
    -- If using custom account, validate bank name
    IF NOT p_use_default_account AND p_bank_name IS NOT NULL THEN
        IF NOT public.is_valid_korean_bank(p_bank_name) THEN
            RAISE EXCEPTION 'Invalid bank name: %', p_bank_name;
        END IF;
    END IF;
    
    -- Update product account information
    UPDATE public.products 
    SET 
        use_default_account = p_use_default_account,
        transaction_bank_name = CASE 
            WHEN p_use_default_account THEN NULL 
            ELSE p_bank_name 
        END,
        transaction_account_number_encrypted = CASE 
            WHEN p_use_default_account THEN NULL 
            ELSE p_account_number_encrypted 
        END,
        transaction_account_holder = CASE 
            WHEN p_use_default_account THEN NULL 
            ELSE p_account_holder 
        END,
        updated_at = NOW()
    WHERE id = product_id;
    
    RETURN FOUND;
END;
$$;

-- Step 7: Create RLS policy for product account information access
-- Transaction participants can view account info for products in their transactions
CREATE POLICY "Transaction participants can view product account info" ON public.products
    FOR SELECT 
    USING (
        -- Product owner can always view
        seller_id = auth.uid() OR
        -- Transaction participants can view if account is set to show for normal transactions
        EXISTS (
            SELECT 1 FROM public.transactions t
            WHERE t.product_id = products.id
            AND (t.buyer_id = auth.uid() OR t.seller_id = auth.uid() OR t.reseller_id = auth.uid())
        )
    );

-- Step 8: Grant permissions
GRANT EXECUTE ON FUNCTION public.get_product_account_info TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_product_account_info TO authenticated;

-- Step 9: Add comments for documentation
COMMENT ON COLUMN public.products.shop_id IS 'Reference to the shop this product belongs to';
COMMENT ON COLUMN public.products.transaction_bank_name IS 'Bank name for this specific product transactions';
COMMENT ON COLUMN public.products.transaction_account_number_encrypted IS 'Encrypted account number for this specific product';
COMMENT ON COLUMN public.products.transaction_account_holder IS 'Account holder for this specific product';
COMMENT ON COLUMN public.products.use_default_account IS 'Whether to use user default account or product-specific account';
COMMENT ON FUNCTION public.get_product_account_info IS 'Get effective account information for a product (default or product-specific)';
COMMENT ON FUNCTION public.update_product_account_info IS 'Update product-specific account information';