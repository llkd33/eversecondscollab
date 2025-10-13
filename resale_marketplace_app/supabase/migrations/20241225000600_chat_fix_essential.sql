-- Essential Chat System Fixes Only
-- Fix the core issues preventing chat functionality

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can insert messages in their chats" ON messages;
DROP POLICY IF EXISTS "Users can view messages in their chats" ON messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON messages;
DROP POLICY IF EXISTS "Users can delete their own messages" ON messages;

-- Create comprehensive RLS policies for messages
CREATE POLICY "Users can insert messages in their chats" ON messages
  FOR INSERT 
  WITH CHECK (
    auth.uid() = sender_id AND 
    EXISTS (
      SELECT 1 FROM chats 
      WHERE chats.id = messages.chat_id 
      AND auth.uid() = ANY(chats.participants)
    )
  );

CREATE POLICY "Users can view messages in their chats" ON messages
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM chats 
      WHERE chats.id = messages.chat_id 
      AND auth.uid() = ANY(chats.participants)
    )
  );

CREATE POLICY "Users can update their own messages" ON messages
  FOR UPDATE 
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can delete their own messages" ON messages
  FOR DELETE 
  USING (auth.uid() = sender_id);

-- Create get_chat_messages function
CREATE OR REPLACE FUNCTION get_chat_messages(chat_id_param UUID)
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
AS $$
BEGIN
  -- Check if user is participant in the chat
  IF NOT EXISTS (
    SELECT 1 FROM chats 
    WHERE chats.id = chat_id_param 
    AND auth.uid() = ANY(chats.participants)
  ) THEN
    RAISE EXCEPTION 'Access denied: User is not a participant in this chat';
  END IF;

  -- Return messages with sender profile
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
    ) as sender_profile
  FROM messages m
  LEFT JOIN profiles p ON m.sender_id = p.id
  WHERE m.chat_id = chat_id_param
  ORDER BY m.created_at ASC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_chat_messages(UUID) TO authenticated;

-- Update get_user_chats function
CREATE OR REPLACE FUNCTION get_user_chats()
RETURNS TABLE (
  id UUID,
  participants UUID[],
  product_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  reseller_id UUID,
  original_seller_id UUID,
  is_resale_chat BOOLEAN,
  last_message JSON,
  other_participant JSON,
  product JSON
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.participants,
    c.product_id,
    c.created_at,
    c.updated_at,
    c.reseller_id,
    c.original_seller_id,
    c.is_resale_chat,
    -- Last message
    COALESCE(
      (SELECT json_build_object(
        'id', m.id,
        'content', m.content,
        'sender_id', m.sender_id,
        'created_at', m.created_at,
        'message_type', m.message_type
      )
      FROM messages m 
      WHERE m.chat_id = c.id 
      ORDER BY m.created_at DESC 
      LIMIT 1),
      NULL::json
    ) as last_message,
    -- Other participant profile
    (SELECT json_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'avatar_url', p.avatar_url,
      'username', p.username
    )
    FROM profiles p 
    WHERE p.id = ANY(c.participants) 
    AND p.id != current_user_id
    LIMIT 1) as other_participant,
    -- Product info
    (SELECT json_build_object(
      'id', pr.id,
      'title', pr.title,
      'price', pr.price,
      'image_urls', pr.image_urls
    )
    FROM products pr 
    WHERE pr.id = c.product_id) as product
  FROM chats c
  WHERE current_user_id = ANY(c.participants)
  ORDER BY 
    CASE 
      WHEN EXISTS (SELECT 1 FROM messages WHERE chat_id = c.id) 
      THEN (SELECT MAX(created_at) FROM messages WHERE chat_id = c.id)
      ELSE c.created_at
    END DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_chats() TO authenticated;