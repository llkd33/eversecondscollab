-- Add account information fields to users table
-- This migration adds encrypted account information for settlements

-- Step 1: Add account information columns
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bank_name VARCHAR(50);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS account_number_encrypted TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS account_holder VARCHAR(50);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_account_verified BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS show_account_for_normal BOOLEAN DEFAULT false;

-- Step 2: Create indexes for account information
CREATE INDEX IF NOT EXISTS idx_users_account_verified ON public.users(is_account_verified);
CREATE INDEX IF NOT EXISTS idx_users_bank_name ON public.users(bank_name) WHERE bank_name IS NOT NULL;

-- Step 3: Create function to validate Korean bank names
CREATE OR REPLACE FUNCTION public.is_valid_korean_bank(bank_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN bank_name IN (
        'KB국민은행', '신한은행', '우리은행', '하나은행', 'KEB하나은행',
        'NH농협은행', 'IBK기업은행', '부산은행', '경남은행', '광주은행',
        '전북은행', '제주은행', '대구은행', 'SC제일은행', '한국씨티은행',
        '카카오뱅크', '케이뱅크', '토스뱅크', '우체국', '새마을금고',
        '신협', '산업은행', '수협은행', '저축은행'
    );
END;
$$;

-- Step 4: Add constraint for valid bank names
ALTER TABLE public.users 
ADD CONSTRAINT users_valid_bank_name 
CHECK (bank_name IS NULL OR public.is_valid_korean_bank(bank_name));

-- Step 5: Create function to update account information safely
CREATE OR REPLACE FUNCTION public.update_user_account_info(
    user_id UUID,
    p_bank_name TEXT,
    p_account_number_encrypted TEXT,
    p_account_holder TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get current authenticated user
    current_user_id := auth.uid();
    
    -- Only allow users to update their own account info
    IF current_user_id != user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot update other user account information';
    END IF;
    
    -- Validate bank name
    IF NOT public.is_valid_korean_bank(p_bank_name) THEN
        RAISE EXCEPTION 'Invalid bank name: %', p_bank_name;
    END IF;
    
    -- Validate account holder (basic validation)
    IF LENGTH(TRIM(p_account_holder)) < 2 THEN
        RAISE EXCEPTION 'Account holder name must be at least 2 characters';
    END IF;
    
    -- Update user account information
    UPDATE public.users 
    SET 
        bank_name = p_bank_name,
        account_number_encrypted = p_account_number_encrypted,
        account_holder = TRIM(p_account_holder),
        is_account_verified = false, -- Reset verification status
        updated_at = NOW()
    WHERE id = user_id;
    
    -- Check if update was successful
    IF FOUND THEN
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$;

-- Step 6: Create function to verify account ownership
CREATE OR REPLACE FUNCTION public.verify_user_account(
    user_id UUID,
    verification_code TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get current authenticated user
    current_user_id := auth.uid();
    
    -- Only allow users to verify their own account
    IF current_user_id != user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot verify other user account';
    END IF;
    
    -- TODO: Implement actual verification logic with external service
    -- For now, we'll assume verification is successful if verification_code is provided
    IF LENGTH(TRIM(verification_code)) < 4 THEN
        RETURN false;
    END IF;
    
    -- Update verification status
    UPDATE public.users 
    SET 
        is_account_verified = true,
        updated_at = NOW()
    WHERE id = user_id;
    
    RETURN FOUND;
END;
$$;

-- Step 7: Create RLS policies for account information
-- Users can only view their own account information
CREATE POLICY "Users can view their own account info" ON public.users
    FOR SELECT 
    USING (
        auth.uid() = id OR
        -- Allow transaction participants to view basic account info
        EXISTS (
            SELECT 1 FROM public.transactions t
            WHERE (t.buyer_id = auth.uid() OR t.seller_id = auth.uid() OR t.reseller_id = auth.uid())
            AND (t.buyer_id = users.id OR t.seller_id = users.id OR t.reseller_id = users.id)
            AND show_account_for_normal = true
        )
    );

-- Step 8: Grant permissions
GRANT EXECUTE ON FUNCTION public.is_valid_korean_bank TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.update_user_account_info TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_user_account TO authenticated;

-- Step 9: Add comments for documentation
COMMENT ON COLUMN public.users.bank_name IS 'User bank name for settlements';
COMMENT ON COLUMN public.users.account_number_encrypted IS 'Encrypted account number for security';
COMMENT ON COLUMN public.users.account_holder IS 'Account holder name (must match user name)';
COMMENT ON COLUMN public.users.is_account_verified IS 'Whether the account has been verified';
COMMENT ON COLUMN public.users.show_account_for_normal IS 'Whether to show account info for normal transactions';
COMMENT ON FUNCTION public.update_user_account_info IS 'Safely update user account information with validation';
COMMENT ON FUNCTION public.verify_user_account IS 'Verify user account ownership';