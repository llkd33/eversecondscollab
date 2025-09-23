-- Ensure supporting table for per-user read timestamps exists
CREATE TABLE IF NOT EXISTS public.user_chat_read_status (
  user_id uuid NOT NULL,
  chat_id uuid NOT NULL,
  last_read_at timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, chat_id)
);

-- Optional indexes to speed up lookups if the table is newly created
CREATE INDEX IF NOT EXISTS idx_user_chat_read_status_chat ON public.user_chat_read_status (chat_id);
CREATE INDEX IF NOT EXISTS idx_user_chat_read_status_user ON public.user_chat_read_status (user_id);

ALTER TABLE public.user_chat_read_status ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_chat_read_status'
      AND policyname = 'user_chat_read_status_self_access'
  ) THEN
    CREATE POLICY user_chat_read_status_self_access
    ON public.user_chat_read_status
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.get_user_chats(p_user_id uuid)
RETURNS TABLE (
  chat_id uuid,
  participants uuid[],
  product_id uuid,
  reseller_id uuid,
  is_resale_chat boolean,
  original_seller_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  product_title text,
  product_image text,
  product_price integer,
  last_message text,
  last_message_time timestamptz,
  unread_count integer,
  other_user_name text,
  other_user_profile_image text,
  reseller_name text,
  original_seller_name text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH base_chats AS (
  SELECT
    c.id AS chat_id,
    c.participants,
    c.product_id,
    NULLIF((to_jsonb(c)->>'reseller_id'), '')::uuid AS reseller_id,
    COALESCE(NULLIF((to_jsonb(c)->>'is_resale_chat'), '')::boolean, false) AS is_resale_chat,
    NULLIF((to_jsonb(c)->>'original_seller_id'), '')::uuid AS original_seller_id,
    c.created_at,
    c.updated_at,
    p.title AS product_title,
    CASE
      WHEN coalesce(array_length(p.images, 1), 0) > 0 THEN p.images[1]
      ELSE NULL
    END AS product_image,
    p.price AS product_price
  FROM chats c
  LEFT JOIN products p ON p.id = c.product_id
  WHERE p_user_id = ANY (c.participants)
),
last_messages AS (
  SELECT DISTINCT ON (m.chat_id)
    m.chat_id,
    m.content AS last_message,
    m.created_at AS last_message_time
  FROM messages m
  ORDER BY m.chat_id, m.created_at DESC
),
read_status AS (
  SELECT
    bc.chat_id,
    COALESCE(ucrs.last_read_at, to_timestamp(0) AT TIME ZONE 'UTC') AS last_read_at
  FROM base_chats bc
  LEFT JOIN user_chat_read_status ucrs
    ON ucrs.chat_id = bc.chat_id
   AND ucrs.user_id = p_user_id
),
unread_counts AS (
  SELECT
    bc.chat_id,
    COUNT(m.id) AS unread_count
  FROM base_chats bc
  LEFT JOIN read_status rs ON rs.chat_id = bc.chat_id
  LEFT JOIN messages m
    ON m.chat_id = bc.chat_id
   AND m.created_at > rs.last_read_at
   AND (m.sender_id IS DISTINCT FROM p_user_id)
  GROUP BY bc.chat_id
),
other_participants AS (
  SELECT
    bc.chat_id,
    op.participant AS other_user_id
  FROM base_chats bc
  LEFT JOIN LATERAL (
    SELECT participant
    FROM unnest(bc.participants) AS participant
    WHERE participant IS DISTINCT FROM p_user_id
    LIMIT 1
  ) op ON TRUE
),
other_user_details AS (
  SELECT
    op.chat_id,
    u.name AS other_user_name,
    u.profile_image AS other_user_profile_image
  FROM other_participants op
  LEFT JOIN users u ON u.id = op.other_user_id
)
SELECT
  bc.chat_id,
  bc.participants,
  bc.product_id,
  bc.reseller_id,
  bc.is_resale_chat,
  bc.original_seller_id,
  bc.created_at,
  bc.updated_at,
  bc.product_title,
  bc.product_image,
  bc.product_price,
  lm.last_message,
  lm.last_message_time,
  COALESCE(uc.unread_count, 0) AS unread_count,
  oud.other_user_name,
  oud.other_user_profile_image,
  ur.name AS reseller_name,
  uos.name AS original_seller_name
FROM base_chats bc
LEFT JOIN last_messages lm ON lm.chat_id = bc.chat_id
LEFT JOIN unread_counts uc ON uc.chat_id = bc.chat_id
LEFT JOIN other_user_details oud ON oud.chat_id = bc.chat_id
LEFT JOIN users ur ON ur.id = bc.reseller_id
LEFT JOIN users uos ON uos.id = bc.original_seller_id
ORDER BY COALESCE(lm.last_message_time, bc.updated_at) DESC, bc.updated_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_chats(uuid) TO authenticated, service_role, anon;
ALTER FUNCTION public.get_user_chats(uuid) OWNER TO postgres;

ALTER TABLE public.user_chat_read_status OWNER TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_chat_read_status TO authenticated, service_role;
GRANT SELECT ON TABLE public.user_chat_read_status TO anon;
