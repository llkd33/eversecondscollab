-- Restore the shops → users foreign key so Supabase exposes the embedded relationship
ALTER TABLE public.shops
  DROP CONSTRAINT IF EXISTS shops_owner_id_fkey;

ALTER TABLE public.shops
  ADD CONSTRAINT shops_owner_id_fkey
  FOREIGN KEY (owner_id)
  REFERENCES public.users(id)
  ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_shops_owner_id ON public.shops(owner_id);

-- Recreate the chat RPC used by the mobile client
DROP FUNCTION IF EXISTS public.get_chat_messages(UUID);

CREATE OR REPLACE FUNCTION public.get_chat_messages(chat_id_param UUID)
RETURNS TABLE (
  id UUID,
  chat_id UUID,
  sender_id UUID,
  content TEXT,
  message_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  is_read BOOLEAN,
  sender_profile JSON
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Make sure the current user participates in the chat
  IF NOT EXISTS (
    SELECT 1
    FROM public.chats c
    WHERE c.id = chat_id_param
      AND auth.uid() = ANY(c.participants)
  ) THEN
    RAISE EXCEPTION 'Access denied: user is not a participant in this chat';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.chat_id,
    m.sender_id,
    m.content,
    m.message_type,
    m.created_at,
    m.updated_at,
    m.is_read,
    json_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'avatar_url', p.avatar_url,
      'username', p.username
    ) AS sender_profile
  FROM public.messages m
  LEFT JOIN public.profiles p ON p.id = m.sender_id
  WHERE m.chat_id = chat_id_param
  ORDER BY m.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_chat_messages(UUID) TO authenticated;
