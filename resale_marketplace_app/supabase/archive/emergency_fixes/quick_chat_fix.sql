-- QUICK FIX for missing chats table columns
-- Run this in Supabase SQL Editor to fix the "reseller_id does not exist" error

-- Step 1: Add missing columns to chats table
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS reseller_id uuid;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS original_seller_id uuid;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS is_resale_chat boolean NOT NULL DEFAULT false;

-- Step 2: Add foreign key constraints
DO $$ 
BEGIN
    -- Add foreign key for reseller_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'chats_reseller_id_fkey'
    ) THEN
        ALTER TABLE public.chats 
        ADD CONSTRAINT chats_reseller_id_fkey 
        FOREIGN KEY (reseller_id) REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
    
    -- Add foreign key for original_seller_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'chats_original_seller_id_fkey'
    ) THEN
        ALTER TABLE public.chats 
        ADD CONSTRAINT chats_original_seller_id_fkey 
        FOREIGN KEY (original_seller_id) REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Step 3: Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chats_reseller_id ON public.chats(reseller_id);
CREATE INDEX IF NOT EXISTS idx_chats_original_seller_id ON public.chats(original_seller_id);
CREATE INDEX IF NOT EXISTS idx_chats_is_resale ON public.chats(is_resale_chat);

-- Step 4: Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'chats'
ORDER BY ordinal_position;