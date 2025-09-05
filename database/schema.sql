-- Everseconds Resale Marketplace Database Schema
-- 중고거래 대신팔기 마켓플레이스 데이터베이스 스키마

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users (사용자) 테이블
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL, -- 사용자 ID (카카오/전화번호 로그인 시 변경 활용)
  name TEXT NOT NULL, -- 사용자 이름
  phone TEXT UNIQUE NOT NULL, -- 전화번호 (고유)
  is_verified BOOLEAN DEFAULT false, -- 인증 여부
  profile_image TEXT, -- 프로필 사진 URL
  role VARCHAR(20) DEFAULT '일반', -- [일반, 대신판매자, 관리자]
  shop_id UUID, -- 나의 샵 연결 (shops 테이블 생성 후 FK 추가)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 2. Shops (개인샵) 테이블
CREATE TABLE IF NOT EXISTS shops (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL, -- 샵 이름
  description TEXT, -- 설명
  share_url TEXT UNIQUE, -- 공유 가능한 URL
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Users 테이블에 shop_id 외래키 추가
ALTER TABLE users 
ADD CONSTRAINT fk_user_shop 
FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE SET NULL;

-- 3. Products (상품) 테이블
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  price INTEGER NOT NULL CHECK (price >= 0),
  description TEXT,
  images TEXT[] DEFAULT '{}', -- 이미지 URL 리스트
  category VARCHAR(50) NOT NULL, -- [의류, 전자기기, 생활용품 등]
  seller_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL, -- 원 판매자
  resale_enabled BOOLEAN DEFAULT false, -- 대신팔기 가능 여부
  resale_fee INTEGER DEFAULT 0 CHECK (resale_fee >= 0), -- 수수료 금액
  resale_fee_percentage DECIMAL(5,2) DEFAULT 0, -- 수수료 퍼센티지 (보조 저장)
  status VARCHAR(20) DEFAULT '판매중' CHECK (status IN ('판매중', '판매완료')), -- [판매중, 판매완료]
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 4. Shop_Products (샵-상품 연결) 테이블 - 대신팔기 상품 관리
CREATE TABLE IF NOT EXISTS shop_products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shop_id UUID REFERENCES shops(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE NOT NULL,
  is_resale BOOLEAN DEFAULT true, -- true: 대신팔기 상품, false: 직접 등록 상품
  added_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(shop_id, product_id) -- 같은 상품을 중복으로 대신팔기 할 수 없음
);

-- 5. Chats (채팅방) 테이블
CREATE TABLE IF NOT EXISTS chats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participants UUID[] NOT NULL, -- 참여자 리스트
  product_id UUID REFERENCES products(id) ON DELETE SET NULL, -- 관련 상품
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 6. Messages (채팅 메시지) 테이블
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id UUID REFERENCES chats(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 7. Transactions (거래 정보) 테이블
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID REFERENCES products(id) ON DELETE SET NULL NOT NULL,
  price INTEGER NOT NULL CHECK (price >= 0), -- 상품 금액
  resale_fee INTEGER DEFAULT 0 CHECK (resale_fee >= 0), -- 수수료 금액
  buyer_id UUID REFERENCES users(id) ON DELETE SET NULL NOT NULL,
  seller_id UUID REFERENCES users(id) ON DELETE SET NULL NOT NULL,
  reseller_id UUID REFERENCES users(id) ON DELETE SET NULL, -- 대신판매자 (있을 경우)
  status VARCHAR(20) DEFAULT '거래중' CHECK (status IN ('거래중', '거래중단', '거래완료')),
  chat_id UUID REFERENCES chats(id) ON DELETE SET NULL,
  transaction_type VARCHAR(20) DEFAULT '일반거래' CHECK (transaction_type IN ('일반거래', '안전거래')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- 8. Reviews (후기) 테이블
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reviewer_id UUID REFERENCES users(id) ON DELETE SET NULL NOT NULL,
  reviewed_user_id UUID REFERENCES users(id) ON DELETE SET NULL NOT NULL, -- 리뷰 받는 사용자
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5), -- 1-5 별점
  comment TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(reviewer_id, transaction_id) -- 한 거래에 대해 한 번만 리뷰 가능
);

-- 9. Safe_Transactions (안전거래 관리) 테이블
CREATE TABLE IF NOT EXISTS safe_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE NOT NULL UNIQUE,
  deposit_amount INTEGER NOT NULL CHECK (deposit_amount >= 0), -- 입금 금액
  deposit_confirmed BOOLEAN DEFAULT false, -- 입금 확인 여부
  deposit_confirmed_at TIMESTAMP WITH TIME ZONE,
  shipping_confirmed BOOLEAN DEFAULT false, -- 배송 확인 여부
  shipping_confirmed_at TIMESTAMP WITH TIME ZONE,
  delivery_confirmed BOOLEAN DEFAULT false, -- 배송 완료 확인 여부
  delivery_confirmed_at TIMESTAMP WITH TIME ZONE,
  settlement_status VARCHAR(20) DEFAULT '대기중' CHECK (settlement_status IN ('대기중', '정산준비', '정산완료')),
  admin_notes TEXT, -- 관리자 메모
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 10. SMS_Logs (SMS 발송 로그) 테이블
CREATE TABLE IF NOT EXISTS sms_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_number TEXT NOT NULL,
  message_type VARCHAR(50) NOT NULL, -- [인증번호, 입금확인요청, 입금완료, 배송완료 등]
  message_content TEXT NOT NULL,
  is_sent BOOLEAN DEFAULT false,
  sent_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 인덱스 생성
CREATE INDEX idx_products_seller_id ON products(seller_id);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_shop_products_shop_id ON shop_products(shop_id);
CREATE INDEX idx_shop_products_product_id ON shop_products(product_id);
CREATE INDEX idx_messages_chat_id ON messages(chat_id);
CREATE INDEX idx_transactions_buyer_id ON transactions(buyer_id);
CREATE INDEX idx_transactions_seller_id ON transactions(seller_id);
CREATE INDEX idx_transactions_reseller_id ON transactions(reseller_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_reviews_transaction_id ON reviews(transaction_id);
CREATE INDEX idx_safe_transactions_transaction_id ON safe_transactions(transaction_id);

-- RLS (Row Level Security) 정책 설정
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE safe_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_logs ENABLE ROW LEVEL SECURITY;

-- Users 테이블 RLS 정책
CREATE POLICY "Users can view all profiles" ON users
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Products 테이블 RLS 정책
CREATE POLICY "Anyone can view products" ON products
  FOR SELECT USING (true);

CREATE POLICY "Users can create products" ON products
  FOR INSERT WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Sellers can update own products" ON products
  FOR UPDATE USING (auth.uid() = seller_id);

CREATE POLICY "Sellers can delete own products" ON products
  FOR DELETE USING (auth.uid() = seller_id);

-- Shops 테이블 RLS 정책
CREATE POLICY "Anyone can view shops" ON shops
  FOR SELECT USING (true);

CREATE POLICY "Users can create own shop" ON shops
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Shop owners can update own shop" ON shops
  FOR UPDATE USING (auth.uid() = owner_id);

-- Shop_Products 테이블 RLS 정책
CREATE POLICY "Anyone can view shop products" ON shop_products
  FOR SELECT USING (true);

CREATE POLICY "Shop owners can manage shop products" ON shop_products
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM shops WHERE shops.id = shop_products.shop_id AND shops.owner_id = auth.uid()
    )
  );

-- Chats 테이블 RLS 정책
CREATE POLICY "Participants can view chat" ON chats
  FOR SELECT USING (auth.uid() = ANY(participants));

CREATE POLICY "Users can create chat" ON chats
  FOR INSERT WITH CHECK (auth.uid() = ANY(participants));

-- Messages 테이블 RLS 정책
CREATE POLICY "Chat participants can view messages" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chats WHERE chats.id = messages.chat_id AND auth.uid() = ANY(chats.participants)
    )
  );

CREATE POLICY "Chat participants can send messages" ON messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM chats WHERE chats.id = messages.chat_id AND auth.uid() = ANY(chats.participants)
    )
  );

-- Transactions 테이블 RLS 정책
CREATE POLICY "Transaction participants can view" ON transactions
  FOR SELECT USING (
    auth.uid() IN (buyer_id, seller_id, reseller_id)
  );

CREATE POLICY "Users can create transactions" ON transactions
  FOR INSERT WITH CHECK (auth.uid() IN (buyer_id, seller_id));

CREATE POLICY "Transaction participants can update" ON transactions
  FOR UPDATE USING (auth.uid() IN (buyer_id, seller_id, reseller_id));

-- Reviews 테이블 RLS 정책
CREATE POLICY "Anyone can view reviews" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "Transaction participants can create reviews" ON reviews
  FOR INSERT WITH CHECK (
    auth.uid() = reviewer_id AND
    EXISTS (
      SELECT 1 FROM transactions 
      WHERE transactions.id = reviews.transaction_id 
      AND auth.uid() IN (transactions.buyer_id, transactions.seller_id, transactions.reseller_id)
    )
  );

-- Safe_Transactions 테이블 RLS 정책 (관리자만 접근)
CREATE POLICY "Only admins can manage safe transactions" ON safe_transactions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

CREATE POLICY "Transaction participants can view safe transactions" ON safe_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM transactions 
      WHERE transactions.id = safe_transactions.transaction_id 
      AND auth.uid() IN (transactions.buyer_id, transactions.seller_id, transactions.reseller_id)
    )
  );

-- SMS_Logs 테이블 RLS 정책 (관리자만 접근)
CREATE POLICY "Only admins can manage SMS logs" ON sms_logs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = '관리자'
    )
  );

-- 트리거 함수: updated_at 자동 업데이트
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc', NOW());
  RETURN NEW;
END;
$$ language 'plpgsql';

-- updated_at 트리거 생성
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shops_updated_at BEFORE UPDATE ON shops
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chats_updated_at BEFORE UPDATE ON chats
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_safe_transactions_updated_at BEFORE UPDATE ON safe_transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 트리거 함수: 사용자 생성 시 자동으로 샵 생성
CREATE OR REPLACE FUNCTION create_shop_for_user()
RETURNS TRIGGER AS $$
DECLARE
  new_shop_id UUID;
BEGIN
  -- 샵 생성
  INSERT INTO shops (owner_id, name, description, share_url)
  VALUES (
    NEW.id,
    NEW.name || '의 샵',
    NEW.name || '님의 개인 샵입니다.',
    'shop-' || REPLACE(NEW.id::TEXT, '-', '')
  )
  RETURNING id INTO new_shop_id;
  
  -- 사용자 테이블의 shop_id 업데이트
  UPDATE users SET shop_id = new_shop_id WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER create_shop_on_user_creation
  AFTER INSERT ON users
  FOR EACH ROW EXECUTE FUNCTION create_shop_for_user();

-- 트리거 함수: 수수료 자동 계산 (퍼센티지 입력 시 금액 자동 계산)
CREATE OR REPLACE FUNCTION calculate_resale_fee()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.resale_fee_percentage IS NOT NULL AND NEW.resale_fee_percentage > 0 THEN
    NEW.resale_fee = ROUND(NEW.price * NEW.resale_fee_percentage / 100);
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_resale_fee_on_product
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION calculate_resale_fee();

-- 샘플 데이터 (개발 환경용)
-- 관리자 계정 생성 예시 (실제 운영 시 적절히 수정)
-- INSERT INTO users (email, name, phone, is_verified, role) 
-- VALUES ('admin@everseconds.com', '관리자', '010-0000-0000', true, '관리자');