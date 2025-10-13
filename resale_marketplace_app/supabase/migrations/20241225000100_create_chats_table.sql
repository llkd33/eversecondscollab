-- Create chats table with resale functionality support
-- This table stores chat conversations between users for product transactions

CREATE TABLE IF NOT EXISTS public.chats (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    participants uuid[] NOT NULL CHECK (array_length(participants, 1) >= 2),
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    reseller_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    original_seller_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    is_resale_chat boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    updated_at timestamptz NOT NULL DEFAULT NOW(),
    
    -- Ensure participants array contains valid UUIDs and references users
    CONSTRAINT chats_participants_valid CHECK (
        participants IS NOT NULL AND 
        array_length(participants, 1) >= 2 AND
        array_length(participants, 1) <= 10
    )
);

-- Enable RLS for security
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
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

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_chats_participants_gin ON public.chats USING gin(participants);
CREATE INDEX IF NOT EXISTS idx_chats_product_id ON public.chats(product_id);
CREATE INDEX IF NOT EXISTS idx_chats_reseller_id ON public.chats(reseller_id);
CREATE INDEX IF NOT EXISTS idx_chats_original_seller_id ON public.chats(original_seller_id);
CREATE INDEX IF NOT EXISTS idx_chats_created_at ON public.chats(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chats_updated_at ON public.chats(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chats_is_resale ON public.chats(is_resale_chat);

-- Create function to check if user is participant in chat
CREATE OR REPLACE FUNCTION public.is_chat_participant(chat_id uuid, user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT user_id = ANY(participants) 
    FROM public.chats 
    WHERE id = chat_id;
$$;

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_chats_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_chats_updated_at ON public.chats;
CREATE TRIGGER update_chats_updated_at
    BEFORE UPDATE ON public.chats
    FOR EACH ROW
    EXECUTE FUNCTION public.update_chats_updated_at();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON public.chats TO authenticated, anon;
GRANT USAGE ON SEQUENCE chats_id_seq TO authenticated, anon;

-- Add comments for documentation
COMMENT ON TABLE public.chats IS 'Chat conversations between users for product transactions';
COMMENT ON COLUMN public.chats.participants IS 'Array of user IDs participating in the chat';
COMMENT ON COLUMN public.chats.product_id IS 'ID of the product being discussed';
COMMENT ON COLUMN public.chats.reseller_id IS 'ID of the user acting as reseller (for resale chats)';
COMMENT ON COLUMN public.chats.original_seller_id IS 'ID of the original product seller (for resale chats)';
COMMENT ON COLUMN public.chats.is_resale_chat IS 'Whether this is a resale chat or direct sale chat';