-- Create messages table for chat functionality
-- This table stores individual messages within chats

CREATE TABLE IF NOT EXISTS public.messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id uuid NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    recipient_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    content text NOT NULL,
    message_type text DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'system')),
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    updated_at timestamptz NOT NULL DEFAULT NOW(),
    
    -- Additional metadata for different message types
    metadata jsonb,
    
    -- Ensure content is not empty for text messages
    CONSTRAINT messages_content_not_empty CHECK (
        CASE WHEN message_type = 'text' 
        THEN LENGTH(TRIM(content)) > 0 
        ELSE TRUE END
    )
);

-- Enable RLS for security
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

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

-- Create indexes for performance (matching existing ones and adding new ones)
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON public.messages(chat_id, recipient_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON public.messages(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_type ON public.messages(message_type);

-- Also create the old index name for backward compatibility if needed
CREATE INDEX IF NOT EXISTS idx_messages_chat_room_conversation ON public.messages(chat_id, created_at DESC);

-- Create function to mark messages as read
CREATE OR REPLACE FUNCTION public.mark_messages_as_read(p_chat_id uuid, p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    updated_count integer;
BEGIN
    -- Verify user is participant in chat
    IF NOT EXISTS (
        SELECT 1 FROM public.chats c 
        WHERE c.id = p_chat_id AND p_user_id = ANY(c.participants)
    ) THEN
        RAISE EXCEPTION 'User is not a participant in this chat';
    END IF;
    
    -- Mark messages as read
    UPDATE public.messages 
    SET is_read = true, updated_at = NOW()
    WHERE chat_id = p_chat_id 
        AND recipient_id = p_user_id 
        AND is_read = false;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    -- Update chat's updated_at timestamp
    UPDATE public.chats 
    SET updated_at = NOW() 
    WHERE id = p_chat_id;
    
    RETURN updated_count;
END;
$$;

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_messages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_messages_updated_at ON public.messages;
CREATE TRIGGER update_messages_updated_at
    BEFORE UPDATE ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.update_messages_updated_at();

-- Create trigger to update chat's updated_at when new message is added
CREATE OR REPLACE FUNCTION public.update_chat_on_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.chats 
    SET updated_at = NEW.created_at 
    WHERE id = NEW.chat_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_chat_on_new_message ON public.messages;
CREATE TRIGGER update_chat_on_new_message
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.update_chat_on_message();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON public.messages TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_read TO authenticated, anon;

-- Add comments for documentation
COMMENT ON TABLE public.messages IS 'Individual messages within chat conversations';
COMMENT ON COLUMN public.messages.chat_id IS 'Reference to the chat this message belongs to';
COMMENT ON COLUMN public.messages.sender_id IS 'User who sent this message';
COMMENT ON COLUMN public.messages.recipient_id IS 'Intended recipient of the message (optional for group chats)';
COMMENT ON COLUMN public.messages.content IS 'The message content';
COMMENT ON COLUMN public.messages.message_type IS 'Type of message: text, image, file, or system';
COMMENT ON COLUMN public.messages.is_read IS 'Whether the message has been read by the recipient';
COMMENT ON COLUMN public.messages.metadata IS 'Additional data for special message types (file paths, image URLs, etc.)';