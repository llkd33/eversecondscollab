-- Add missing columns to existing chats table
-- This handles the case where chats table exists but is missing required columns

-- Check and add reseller_id column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'chats' 
        AND column_name = 'reseller_id'
    ) THEN
        ALTER TABLE public.chats ADD COLUMN reseller_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Check and add original_seller_id column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'chats' 
        AND column_name = 'original_seller_id'
    ) THEN
        ALTER TABLE public.chats ADD COLUMN original_seller_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Check and add is_resale_chat column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'chats' 
        AND column_name = 'is_resale_chat'
    ) THEN
        ALTER TABLE public.chats ADD COLUMN is_resale_chat boolean NOT NULL DEFAULT false;
    END IF;
END $$;

-- Check and add participants column if it doesn't exist (for UUID array)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'chats' 
        AND column_name = 'participants'
    ) THEN
        ALTER TABLE public.chats ADD COLUMN participants uuid[] NOT NULL DEFAULT '{}';
    END IF;
END $$;

-- Check and add product_id column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'chats' 
        AND column_name = 'product_id'
    ) THEN
        ALTER TABLE public.chats ADD COLUMN product_id uuid REFERENCES public.products(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Add indexes for the new columns if they don't exist
CREATE INDEX IF NOT EXISTS idx_chats_reseller_id ON public.chats(reseller_id);
CREATE INDEX IF NOT EXISTS idx_chats_original_seller_id ON public.chats(original_seller_id);
CREATE INDEX IF NOT EXISTS idx_chats_is_resale ON public.chats(is_resale_chat);
CREATE INDEX IF NOT EXISTS idx_chats_participants_gin ON public.chats USING gin(participants);
CREATE INDEX IF NOT EXISTS idx_chats_product_id ON public.chats(product_id);

-- Add constraint for participants array validation
DO $$
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'chats' 
        AND constraint_name = 'chats_participants_valid'
    ) THEN
        ALTER TABLE public.chats DROP CONSTRAINT chats_participants_valid;
    END IF;
    
    -- Add the constraint
    ALTER TABLE public.chats ADD CONSTRAINT chats_participants_valid CHECK (
        participants IS NOT NULL AND 
        array_length(participants, 1) >= 2 AND
        array_length(participants, 1) <= 10
    );
END $$;

-- Ensure RLS is enabled
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Create or replace RLS policies
DROP POLICY IF EXISTS "Users can view chats they participate in" ON public.chats;
CREATE POLICY "Users can view chats they participate in" ON public.chats
    FOR SELECT 
    USING (auth.uid() = ANY(participants));

DROP POLICY IF EXISTS "Users can create chats they participate in" ON public.chats;
CREATE POLICY "Users can create chats they participate in" ON public.chats
    FOR INSERT 
    WITH CHECK (auth.uid() = ANY(participants));

DROP POLICY IF EXISTS "Users can update chats they participate in" ON public.chats;
CREATE POLICY "Users can update chats they participate in" ON public.chats
    FOR UPDATE 
    USING (auth.uid() = ANY(participants))
    WITH CHECK (auth.uid() = ANY(participants));

-- Add comments for new columns
COMMENT ON COLUMN public.chats.reseller_id IS 'ID of the user acting as reseller (for resale chats)';
COMMENT ON COLUMN public.chats.original_seller_id IS 'ID of the original product seller (for resale chats)';
COMMENT ON COLUMN public.chats.is_resale_chat IS 'Whether this is a resale chat or direct sale chat';
COMMENT ON COLUMN public.chats.participants IS 'Array of user IDs participating in the chat';
COMMENT ON COLUMN public.chats.product_id IS 'ID of the product being discussed';