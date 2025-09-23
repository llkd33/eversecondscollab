-- SIMPLE STEP-BY-STEP FIX for Kakao OAuth
-- Run each step separately in Supabase SQL Editor

-- ==========================================
-- STEP 1: Check current situation
-- ==========================================
-- Run this to see the problem:
SELECT 
    'Duplicate emails:' as issue,
    email, 
    COUNT(*) as count 
FROM public.users 
WHERE email IS NOT NULL
GROUP BY email 
HAVING COUNT(*) > 1;

-- See orphaned auth users:
SELECT 
    a.id,
    a.email,
    'No profile' as status
FROM auth.users a
LEFT JOIN public.users p ON p.id = a.id
WHERE p.id IS NULL;

-- ==========================================
-- STEP 2: Fix duplicate emails
-- ==========================================
-- First, backup the constraint name
SELECT conname 
FROM pg_constraint 
WHERE conrelid = 'public.users'::regclass 
AND contype = 'u' 
AND conname LIKE '%email%';

-- Remove the email unique constraint
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_email_key;

-- Make email nullable
ALTER TABLE public.users ALTER COLUMN email DROP NOT NULL;
ALTER TABLE public.users ALTER COLUMN phone DROP NOT NULL;

-- Fix duplicates by renaming newer ones
WITH duplicates AS (
    SELECT 
        id,
        email,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at) as rn
    FROM public.users
    WHERE email IS NOT NULL
)
UPDATE public.users
SET email = 'dup_' || id::text || '@temp.com'
WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
);

-- Re-add the unique constraint
ALTER TABLE public.users 
ADD CONSTRAINT users_email_key UNIQUE (email);

-- ==========================================
-- STEP 3: Create profiles for orphaned auth users
-- ==========================================
INSERT INTO public.users (
    id,
    email,
    name,
    phone,
    is_verified,
    role,
    created_at,
    updated_at
)
SELECT 
    a.id,
    CASE 
        WHEN a.email IN (SELECT email FROM public.users WHERE email IS NOT NULL) 
        THEN 'oauth_' || a.id::text || '@temp.com'
        ELSE a.email
    END as email,
    COALESCE(
        a.raw_user_meta_data->>'name',
        a.raw_user_meta_data->'kakao_account'->'profile'->>'nickname',
        'User ' || SUBSTRING(a.id::TEXT, 1, 8)
    ) as name,
    NULL as phone,
    true as is_verified,
    '일반' as role,
    NOW() as created_at,
    NOW() as updated_at
FROM auth.users a
LEFT JOIN public.users p ON p.id = a.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- ==========================================
-- STEP 4: Create shops for users without shops
-- ==========================================
INSERT INTO public.shops (
    owner_id,
    name,
    description,
    share_url,
    created_at,
    updated_at
)
SELECT 
    u.id,
    u.name || '의 샵',
    u.name || '님의 개인 샵입니다.',
    'shop-' || REPLACE(u.id::TEXT, '-', ''),
    NOW(),
    NOW()
FROM public.users u
LEFT JOIN public.shops s ON s.owner_id = u.id
WHERE s.id IS NULL
ON CONFLICT (owner_id) DO NOTHING;

-- Update users with their shop_ids
UPDATE public.users u
SET shop_id = s.id
FROM public.shops s
WHERE s.owner_id = u.id AND u.shop_id IS NULL;

-- ==========================================
-- STEP 5: Update the RPC function (FINAL)
-- ==========================================
CREATE OR REPLACE FUNCTION create_user_profile_safe(
  user_id UUID,
  user_email TEXT DEFAULT NULL,
  user_name TEXT DEFAULT '',
  user_phone TEXT DEFAULT NULL,
  user_profile_image TEXT DEFAULT NULL,
  user_role TEXT DEFAULT '일반',
  user_is_verified BOOLEAN DEFAULT true
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  result JSON;
  existing_user RECORD;
BEGIN
  -- Check if profile already exists
  SELECT * INTO existing_user FROM public.users WHERE id = user_id;
  
  IF existing_user.id IS NOT NULL THEN
    RETURN json_build_object(
      'success', true,
      'message', 'User profile already exists',
      'user_id', user_id,
      'action', 'existing'
    );
  END IF;
  
  -- Try to create the profile
  BEGIN
    INSERT INTO public.users (
      id, email, name, phone, is_verified, profile_image, role, created_at, updated_at
    ) VALUES (
      user_id,
      user_email,
      COALESCE(NULLIF(user_name, ''), 'User'),
      user_phone,
      user_is_verified,
      user_profile_image,
      user_role,
      NOW(),
      NOW()
    );
    
    RETURN json_build_object(
      'success', true,
      'message', 'Profile created successfully',
      'user_id', user_id,
      'action', 'created'
    );
    
  EXCEPTION WHEN unique_violation THEN
    -- If email conflict, try with a unique email
    BEGIN
      INSERT INTO public.users (
        id, email, name, phone, is_verified, profile_image, role, created_at, updated_at
      ) VALUES (
        user_id,
        'oauth_' || user_id::text || '@temp.com',
        COALESCE(NULLIF(user_name, ''), 'User'),
        user_phone,
        user_is_verified,
        user_profile_image,
        user_role,
        NOW(),
        NOW()
      );
      
      RETURN json_build_object(
        'success', true,
        'message', 'Profile created with alternate email',
        'user_id', user_id,
        'action', 'created'
      );
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object(
        'success', false,
        'message', SQLERRM,
        'user_id', user_id,
        'action', 'error'
      );
    END;
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION create_user_profile_safe TO authenticated, anon, service_role;

-- ==========================================
-- STEP 6: Final verification
-- ==========================================
SELECT 
    'Auth users without profiles:' as check_type,
    COUNT(*) as count
FROM auth.users a
LEFT JOIN public.users p ON p.id = a.id
WHERE p.id IS NULL

UNION ALL

SELECT 
    'Users without shops:' as check_type,
    COUNT(*) as count
FROM public.users u
LEFT JOIN public.shops s ON s.owner_id = u.id
WHERE s.id IS NULL

UNION ALL

SELECT 
    'Duplicate emails:' as check_type,
    COUNT(*) as count
FROM (
    SELECT email FROM public.users 
    WHERE email IS NOT NULL 
    GROUP BY email 
    HAVING COUNT(*) > 1
) x;

-- All should be 0!