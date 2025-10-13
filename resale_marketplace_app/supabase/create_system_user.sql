-- Create system user for transaction records without real buyer
-- Run this in Supabase SQL Editor

-- Insert system user if not exists
INSERT INTO auth.users (id, email, email_confirmed_at, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'system@marketplace.com',
  NOW(),
  NOW(),
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- Insert system user profile
INSERT INTO public.users (id, email, name, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'system@marketplace.com',
  '시스템',
  NOW(),
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- Verify system user exists
SELECT id, email, name FROM public.users WHERE id = '00000000-0000-0000-0000-000000000001';