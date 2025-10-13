-- QUICK FIX for missing messages table columns
-- Run this in Supabase SQL Editor to fix the "is_read does not exist" error

-- Step 1: Add missing columns to messages table
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS chat_id uuid;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS sender_id uuid;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS recipient_id uuid;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS content text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_type text DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS metadata jsonb;

-- Step 2: Add foreign key constraints
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

-- Step 3: Add check constraints
DO $$
BEGIN
    -- Add message type constraint
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'messages_message_type_check'
    ) THEN
        ALTER TABLE public.messages 
        ADD CONSTRAINT messages_message_type_check 
        CHECK (message_type IN ('text', 'image', 'file', 'system'));
    END IF;
    
    -- Add content not empty constraint for text messages
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'messages_content_not_empty'
    ) THEN
        ALTER TABLE public.messages 
        ADD CONSTRAINT messages_content_not_empty 
        CHECK (
            CASE WHEN message_type = 'text' 
            THEN LENGTH(TRIM(content)) > 0 
            ELSE TRUE END
        );
    END IF;
END $$;

-- Step 4: Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON public.messages(chat_id, recipient_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON public.messages(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_type ON public.messages(message_type);

-- Step 5: Enable RLS and create policies
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "Users can create messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON public.messages;

-- Create RLS policies
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

-- Step 6: Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'messages'
ORDER BY ordinal_position;