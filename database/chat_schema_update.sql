-- Chat System Schema Updates
-- 실시간 채팅 시스템을 위한 스키마 업데이트

-- 1. Messages 테이블에 필요한 컬럼 추가
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'system'));

-- 2. Chats 테이블에 대신팔기 관련 컬럼 추가
ALTER TABLE chats 
ADD COLUMN IF NOT EXISTS reseller_id UUID REFERENCES users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS is_resale_chat BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS original_seller_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- 3. Transactions 테이블에 chat_id 컬럼이 없다면 추가
ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS chat_id UUID REFERENCES chats(id) ON DELETE SET NULL;

-- 4. 실시간 기능을 위한 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_chats_participants ON chats USING GIN(participants);
CREATE INDEX IF NOT EXISTS idx_chats_updated_at ON chats(updated_at);

-- 5. 채팅 관련 RLS 정책 업데이트
DROP POLICY IF EXISTS "Chat participants can view messages" ON messages;
CREATE POLICY "Chat participants can view messages" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chats 
      WHERE chats.id = messages.chat_id 
      AND auth.uid() = ANY(chats.participants)
    )
  );

DROP POLICY IF EXISTS "Chat participants can send messages" ON messages;
CREATE POLICY "Chat participants can send messages" ON messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM chats 
      WHERE chats.id = messages.chat_id 
      AND auth.uid() = ANY(chats.participants)
    )
  );

-- 6. 시스템 메시지를 위한 특별 사용자 생성 (시스템 메시지용)
INSERT INTO users (id, email, name, phone, is_verified, role) 
VALUES (
  '00000000-0000-0000-0000-000000000000',
  'system@everseconds.com',
  'System',
  '000-0000-0000',
  true,
  '관리자'
) ON CONFLICT (id) DO NOTHING;

-- 7. 채팅방 업데이트 시간 자동 갱신을 위한 트리거 함수
CREATE OR REPLACE FUNCTION update_chat_timestamp()
RETURNS TRIGGER AS $
BEGIN
  UPDATE chats 
  SET updated_at = TIMEZONE('utc', NOW())
  WHERE id = NEW.chat_id;
  RETURN NEW;
END;
$ language 'plpgsql';

-- 8. 메시지 생성 시 채팅방 업데이트 시간 갱신 트리거
DROP TRIGGER IF EXISTS update_chat_on_message ON messages;
CREATE TRIGGER update_chat_on_message
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION update_chat_timestamp();

-- 9. 실시간 구독을 위한 Publication 생성 (Supabase Realtime)
-- 이미 존재할 수 있으므로 에러 무시
DO $$ 
BEGIN
  -- Messages 테이블에 대한 실시간 구독 활성화
  ALTER PUBLICATION supabase_realtime ADD TABLE messages;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ 
BEGIN
  -- Chats 테이블에 대한 실시간 구독 활성화
  ALTER PUBLICATION supabase_realtime ADD TABLE chats;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 10. 채팅방 참여자 검색을 위한 함수
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
) AS $
BEGIN
  RETURN QUERY
  SELECT 
    c.id as chat_id,
    c.participants,
    c.product_id,
    c.reseller_id,
    c.is_resale_chat,
    c.original_seller_id,
    c.created_at,
    c.updated_at,
    p.title as product_title,
    CASE 
      WHEN p.images IS NOT NULL AND array_length(p.images, 1) > 0 
      THEN p.images[1] 
      ELSE NULL 
    END as product_image,
    p.price as product_price,
    last_msg.content as last_message,
    last_msg.created_at as last_message_time,
    COALESCE(unread.count, 0) as unread_count
  FROM chats c
  LEFT JOIN products p ON c.product_id = p.id
  LEFT JOIN LATERAL (
    SELECT content, created_at
    FROM messages m
    WHERE m.chat_id = c.id
    ORDER BY m.created_at DESC
    LIMIT 1
  ) last_msg ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(*) as count
    FROM messages m
    WHERE m.chat_id = c.id 
    AND m.sender_id != user_id
    AND m.created_at > COALESCE(
      (SELECT last_read_at FROM user_chat_read_status 
       WHERE chat_id = c.id AND user_id = get_user_chats.user_id),
      '1970-01-01'::timestamptz
    )
  ) unread ON true
  WHERE user_id = ANY(c.participants)
  ORDER BY c.updated_at DESC;
END;
$ language 'plpgsql';

-- 11. 사용자별 채팅방 읽음 상태 관리 테이블 (선택사항)
CREATE TABLE IF NOT EXISTS user_chat_read_status (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  chat_id UUID REFERENCES chats(id) ON DELETE CASCADE NOT NULL,
  last_read_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
  created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(user_id, chat_id)
);

-- 읽음 상태 테이블 RLS 정책
ALTER TABLE user_chat_read_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own read status" ON user_chat_read_status
  FOR ALL USING (auth.uid() = user_id);

-- 읽음 상태 업데이트 트리거
CREATE TRIGGER update_user_chat_read_status_updated_at 
  BEFORE UPDATE ON user_chat_read_status
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 12. 채팅방 메시지 조회 함수 (성능 최적화)
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
  message_type VARCHAR(20),
  created_at TIMESTAMPTZ,
  sender_name TEXT,
  sender_profile_image TEXT
) AS $
BEGIN
  RETURN QUERY
  SELECT 
    m.id as message_id,
    m.chat_id,
    m.sender_id,
    m.content,
    m.message_type,
    m.created_at,
    u.name as sender_name,
    u.profile_image as sender_profile_image
  FROM messages m
  LEFT JOIN users u ON m.sender_id = u.id
  WHERE m.chat_id = chat_id_param
  ORDER BY m.created_at DESC
  LIMIT limit_param
  OFFSET offset_param;
END;
$ language 'plpgsql';

-- 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_user_chat_read_status_user_id ON user_chat_read_status(user_id);
CREATE INDEX IF NOT EXISTS idx_user_chat_read_status_chat_id ON user_chat_read_status(chat_id);