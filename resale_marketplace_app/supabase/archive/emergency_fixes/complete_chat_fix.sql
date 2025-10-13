-- COMPLETE CHAT FIX - Run this to fix all chat-related database issues
-- This script fixes both chats and messages tables with all required columns

-- =====================================
-- STEP 1: Fix chats table
-- =====================================

-- Add missing columns to chats table
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS reseller_id uuid;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS original_seller_id uuid;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS is_resale_chat boolean NOT NULL DEFAULT false;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS participants uuid[];
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS product_id uuid;

-- Add foreign key constraints for chats
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
    
    -- Add foreign key for product_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'chats_product_id_fkey'
    ) THEN
        ALTER TABLE public.chats 
        ADD CONSTRAINT chats_product_id_fkey 
        FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Add indexes for chats table
CREATE INDEX IF NOT EXISTS idx_chats_reseller_id ON public.chats(reseller_id);
CREATE INDEX IF NOT EXISTS idx_chats_original_seller_id ON public.chats(original_seller_id);
CREATE INDEX IF NOT EXISTS idx_chats_is_resale ON public.chats(is_resale_chat);
CREATE INDEX IF NOT EXISTS idx_chats_participants_gin ON public.chats USING gin(participants);
CREATE INDEX IF NOT EXISTS idx_chats_product_id ON public.chats(product_id);

-- Enable RLS for chats
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- =====================================
-- STEP 2: Fix messages table
-- =====================================

-- Add missing columns to messages table
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS chat_id uuid;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS sender_id uuid;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS recipient_id uuid;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS content text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_type text DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS metadata jsonb;

-- Add foreign key constraints for messages
DO $$ 
BEGIN
    -- Add foreign key for chat_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'messages_chat_id_fkey'
    ) THEN
        ALTER TABLE public.messages 
        ADD CONSTRAINT messages_chat_id_fkey 
        FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;
    END IF;
    
    -- Add foreign key for sender_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'messages_sender_id_fkey'
    ) THEN
        ALTER TABLE public.messages 
        ADD CONSTRAINT messages_sender_id_fkey 
        FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
    
    -- Add foreign key for recipient_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'messages_recipient_id_fkey'
    ) THEN
        ALTER TABLE public.messages 
        ADD CONSTRAINT messages_recipient_id_fkey 
        FOREIGN KEY (recipient_id) REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Add check constraints for messages
DO $$
BEGIN
    -- Drop existing constraints if they exist
    ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_message_type_check;
    ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_content_not_empty;
    
    -- Add message type constraint
    ALTER TABLE public.messages 
    ADD CONSTRAINT messages_message_type_check 
    CHECK (message_type IN ('text', 'image', 'file', 'system'));
    
    -- Add content not empty constraint for text messages
    ALTER TABLE public.messages 
    ADD CONSTRAINT messages_content_not_empty 
    CHECK (
        CASE WHEN message_type = 'text' 
        THEN LENGTH(TRIM(content)) > 0 
        ELSE TRUE END
    );
END $$;

-- Add indexes for messages table
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON public.messages(chat_id, recipient_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON public.messages(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_type ON public.messages(message_type);

-- Enable RLS for messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- =====================================
-- STEP 3: Create RLS policies
-- =====================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view chats they participate in" ON public.chats;
DROP POLICY IF EXISTS "Users can create chats they participate in" ON public.chats;
DROP POLICY IF EXISTS "Users can update chats they participate in" ON public.chats;
DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "Users can create messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON public.messages;

-- Create RLS policies for chats
CREATE POLICY "Users can view chats they participate in" ON public.chats
    FOR SELECT 
    USING (auth.uid() = ANY(participants));

CREATE POLICY "Users can create chats they participate in" ON public.chats
    FOR INSERT 
    WITH CHECK (auth.uid() = ANY(participants));

CREATE POLICY "Users can update chats they participate in" ON public.chats
    FOR UPDATE 
    USING (auth.uid() = ANY(participants))
    WITH CHECK (auth.uid() = ANY(participants));

-- Create RLS policies for messages
CREATE POLICY "Users can view messages in their chats" ON public.messages
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM public.chats c 
            WHERE c.id = chat_id AND auth.uid() = ANY(c.participants)
        )
    );

CREATE POLICY "Users can create messages in their chats" ON public.messages
    FOR INSERT 
    WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.chats c 
            WHERE c.id = chat_id AND auth.uid() = ANY(c.participants)
        )
    );

CREATE POLICY "Users can update their own messages" ON public.messages
    FOR UPDATE 
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());

-- =====================================
-- STEP 4: Grant permissions
-- =====================================

GRANT SELECT, INSERT, UPDATE ON public.chats TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE ON public.messages TO authenticated, anon;

-- =====================================
-- STEP 5: Verification
-- =====================================

-- Show chats table structure
SELECT 'CHATS TABLE STRUCTURE' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'chats'
ORDER BY ordinal_position;

-- Show messages table structure
SELECT 'MESSAGES TABLE STRUCTURE' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'messages'
ORDER BY ordinal_position;