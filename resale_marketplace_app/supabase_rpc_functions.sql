-- ========================================
-- Supabase RPC 함수 생성
-- ========================================
-- 이 스크립트를 Supabase Dashboard → SQL Editor에서 실행하세요
-- N+1 쿼리 문제 해결을 위한 최적화된 함수들

-- ========================================
-- 1. get_user_chats: 사용자의 채팅 목록 조회 (N+1 문제 해결)
-- ========================================

CREATE OR REPLACE FUNCTION get_user_chats(user_id UUID)
RETURNS TABLE (
  chat_id UUID,
  participants UUID[],
  product_id UUID,
  reseller_id UUID,
  is_resale_chat BOOLEAN,
  original_seller_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  product_title TEXT,
  product_image TEXT,
  product_price INTEGER,
  last_message TEXT,
  last_message_time TIMESTAMPTZ,
  unread_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id AS chat_id,
    c.participants,
    c.product_id,
    c.reseller_id,
    c.is_resale_chat,
    c.original_seller_id,
    c.created_at,
    c.updated_at,
    p.title AS product_title,
    CASE
      WHEN p.images IS NOT NULL AND array_length(p.images, 1) > 0
      THEN p.images[1]
      ELSE NULL
    END AS product_image,
    p.price AS product_price,
    last_msg.content AS last_message,
    last_msg.created_at AS last_message_time,
    COALESCE(unread.count, 0) AS unread_count
  FROM chats c
  LEFT JOIN products p ON c.product_id = p.id
  LEFT JOIN LATERAL (
    SELECT content, created_at
    FROM messages
    WHERE chat_id = c.id
    ORDER BY created_at DESC
    LIMIT 1
  ) last_msg ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::BIGINT AS count
    FROM messages m
    LEFT JOIN user_chat_read_status ucrs ON ucrs.user_id = user_id AND ucrs.chat_id = c.id
    WHERE m.chat_id = c.id
      AND m.sender_id != user_id
      AND m.created_at > COALESCE(ucrs.last_read_at, '1970-01-01'::TIMESTAMPTZ)
  ) unread ON true
  WHERE user_id = ANY(c.participants)
  ORDER BY c.updated_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 2. get_chat_messages: 채팅 메시지 조회
-- ========================================

CREATE OR REPLACE FUNCTION get_chat_messages(
  chat_id_param UUID,
  limit_param INTEGER DEFAULT 50,
  offset_param INTEGER DEFAULT 0
)
RETURNS TABLE (
  message_id UUID,
  chat_id UUID,
  sender_id UUID,
  content TEXT,
  message_type TEXT,
  created_at TIMESTAMPTZ,
  sender_name TEXT,
  sender_profile_image TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id AS message_id,
    m.chat_id,
    m.sender_id,
    m.content,
    m.message_type,
    m.created_at,
    u.name AS sender_name,
    u.profile_image AS sender_profile_image
  FROM messages m
  LEFT JOIN users u ON m.sender_id = u.id
  WHERE m.chat_id = chat_id_param
  ORDER BY m.created_at DESC
  LIMIT limit_param
  OFFSET offset_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 3. get_unread_counts: 여러 채팅방의 읽지 않은 메시지 수 (선택적)
-- ========================================

CREATE OR REPLACE FUNCTION get_unread_counts(
  chat_ids UUID[],
  user_id UUID
)
RETURNS TABLE(chat_id UUID, unread_count BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.chat_id,
    COUNT(*)::BIGINT as unread_count
  FROM messages m
  LEFT JOIN user_chat_read_status ucrs ON ucrs.user_id = user_id AND ucrs.chat_id = m.chat_id
  WHERE m.chat_id = ANY(chat_ids)
    AND m.sender_id != user_id
    AND m.created_at > COALESCE(ucrs.last_read_at, '1970-01-01'::TIMESTAMPTZ)
  GROUP BY m.chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 권한 설정 (필요 시)
-- ========================================

-- 인증된 사용자만 함수 실행 가능하도록 설정
GRANT EXECUTE ON FUNCTION get_user_chats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_chat_messages(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_unread_counts(UUID[], UUID) TO authenticated;

-- ========================================
-- 테스트 쿼리
-- ========================================

-- 1. get_user_chats 테스트
-- SELECT * FROM get_user_chats('your-user-id-here'::UUID);

-- 2. get_chat_messages 테스트
-- SELECT * FROM get_chat_messages('chat-id-here'::UUID, 50, 0);

-- 3. get_unread_counts 테스트
-- SELECT * FROM get_unread_counts(ARRAY['chat-id-1', 'chat-id-2']::UUID[], 'your-user-id'::UUID);
