-- FINAL WORKING FIX for Kakao OAuth
-- This handles all constraint issues properly

-- ==========================================
-- STEP 1: Fix constraints on users table
-- ==========================================

-- First, check what constraints exist
SELECT 
    c.conname AS constraint_name,
    c.contype AS constraint_type,
    pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
WHERE t.relname = 'users' AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Ensure id column has primary key constraint
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_pkey CASCADE;
ALTER TABLE public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);

-- Fix email constraint (remove and recreate to allow NULLs)
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_email_key CASCADE;
ALTER TABLE public.users ALTER COLUMN email DROP NOT NULL;
ALTER TABLE public.users ALTER COLUMN phone DROP NOT NULL;

-- Fix any duplicate emails before adding constraint back
WITH duplicates AS (
    SELECT 
        id,
        email,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at, id::text) as rn
    FROM public.users
    WHERE email IS NOT NULL AND email != ''
)
UPDATE public.users
SET email = 'dup_' || SUBSTRING(id::text, 1, 8) || '@temp.com'
WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
);

-- Now add back the unique constraint
ALTER TABLE public.users 
ADD CONSTRAINT users_email_key UNIQUE (email);

-- ==========================================
-- STEP 2: Clean up orphaned auth users
-- ==========================================

-- Create profiles for auth users that don't have them
WITH auth_users_without_profiles AS (
    SELECT 
        a.id,
        a.email,
        a.raw_user_meta_data,
        a.raw_app_meta_data
    FROM auth.users a
    LEFT JOIN public.users p ON p.id = a.id
    WHERE p.id IS NULL
)
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
    id,
    CASE 
        WHEN email IS NULL OR email = '' THEN 'oauth_' || SUBSTRING(id::text, 1, 8) || '@temp.com'
        WHEN email IN (SELECT email FROM public.users WHERE email IS NOT NULL) 
        THEN 'oauth_' || SUBSTRING(id::text, 1, 8) || '@temp.com'
        ELSE email
    END as email,
    COALESCE(
        raw_user_meta_data->>'name',
        raw_user_meta_data->>'full_name',
        raw_user_meta_data->'kakao_account'->'profile'->>'nickname',
        'User ' || SUBSTRING(id::TEXT, 1, 8)
    ) as name,
    NULL as phone,
    true as is_verified,
    '일반' as role,
    COALESCE((raw_app_meta_data->>'created_at')::timestamp, NOW()) as created_at,
    NOW() as updated_at
FROM auth_users_without_profiles
ON CONFLICT (id) DO UPDATE SET
    updated_at = NOW()
WHERE public.users.email IS NULL OR public.users.email = '';

-- ==========================================
-- STEP 3: Ensure all users have shops
-- ==========================================

-- Create shops for users without them
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
    COALESCE(u.name, '사용자') || '의 샵',
    COALESCE(u.name, '사용자') || '님의 개인 샵입니다.',
    'shop-' || REPLACE(u.id::TEXT, '-', ''),
    NOW(),
    NOW()
FROM public.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.shops s WHERE s.owner_id = u.id
)
ON CONFLICT (owner_id) DO NOTHING;

-- Update users with their shop_ids
UPDATE public.users u
SET 
    shop_id = s.id,
    updated_at = NOW()
FROM public.shops s
WHERE s.owner_id = u.id 
AND u.shop_id IS NULL;

-- ==========================================
-- STEP 4: Create bulletproof RPC function
-- ==========================================

DROP FUNCTION IF EXISTS create_user_profile_safe CASCADE;

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
  final_email TEXT;
  final_name TEXT;
  shop_record RECORD;
BEGIN
  -- Check if user profile already exists
  SELECT * INTO existing_user 
  FROM public.users 
  WHERE id = user_id;
  
  IF existing_user.id IS NOT NULL THEN
    -- User exists, make sure they have a shop
    SELECT * INTO shop_record
    FROM public.shops
    WHERE owner_id = user_id;
    
    IF shop_record.id IS NULL THEN
      -- Create shop
      INSERT INTO public.shops (owner_id, name, description, share_url, created_at, updated_at)
      VALUES (
        user_id,
        COALESCE(existing_user.name, '사용자') || '의 샵',
        COALESCE(existing_user.name, '사용자') || '님의 개인 샵입니다.',
        'shop-' || REPLACE(user_id::TEXT, '-', ''),
        NOW(),
        NOW()
      )
      ON CONFLICT (owner_id) DO UPDATE SET updated_at = NOW()
      RETURNING * INTO shop_record;
      
      -- Update user's shop_id
      UPDATE public.users 
      SET shop_id = shop_record.id, updated_at = NOW()
      WHERE id = user_id;
    END IF;
    
    RETURN json_build_object(
      'success', true,
      'message', 'Existing user profile found',
      'user_id', user_id,
      'shop_id', COALESCE(shop_record.id, existing_user.shop_id),
      'action', 'existing'
    );
  END IF;
  
  -- Prepare email (handle conflicts)
  final_email := NULLIF(TRIM(COALESCE(user_email, '')), '');
  IF final_email IS NOT NULL THEN
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM public.users WHERE email = final_email AND id != user_id) THEN
      final_email := 'oauth_' || REPLACE(user_id::TEXT, '-', '') || '@temp.com';
    END IF;
  END IF;
  
  -- Prepare name
  final_name := COALESCE(NULLIF(TRIM(user_name), ''), '사용자' || SUBSTRING(user_id::TEXT, 1, 8));
  
  -- Create the user profile
  BEGIN
    INSERT INTO public.users (
      id,
      email,
      name,
      phone,
      is_verified,
      profile_image,
      role,
      created_at,
      updated_at
    ) VALUES (
      user_id,
      final_email,
      final_name,
      NULLIF(TRIM(COALESCE(user_phone, '')), ''),
      user_is_verified,
      user_profile_image,
      user_role,
      NOW(),
      NOW()
    );
    
    -- Create shop for new user
    INSERT INTO public.shops (owner_id, name, description, share_url, created_at, updated_at)
    VALUES (
      user_id,
      final_name || '의 샵',
      final_name || '님의 개인 샵입니다.',
      'shop-' || REPLACE(user_id::TEXT, '-', ''),
      NOW(),
      NOW()
    )
    ON CONFLICT (owner_id) DO UPDATE SET updated_at = NOW()
    RETURNING * INTO shop_record;
    
    -- Update user's shop_id
    UPDATE public.users 
    SET shop_id = shop_record.id, updated_at = NOW()
    WHERE id = user_id;
    
    RETURN json_build_object(
      'success', true,
      'message', 'User profile created successfully',
      'user_id', user_id,
      'shop_id', shop_record.id,
      'action', 'created'
    );
    
  EXCEPTION 
    WHEN unique_violation THEN
      -- This shouldn't happen with our checks, but handle it anyway
      RETURN json_build_object(
        'success', false,
        'message', 'Unique constraint violation: ' || SQLERRM,
        'user_id', user_id,
        'action', 'error'
      );
    WHEN OTHERS THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Unexpected error: ' || SQLERRM,
        'user_id', user_id,
        'action', 'error'
      );
  END;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_user_profile_safe TO authenticated, anon, service_role;

-- ==========================================
-- STEP 5: Final verification
-- ==========================================

-- Check the results
WITH checks AS (
    SELECT 
        'Auth users without profiles' as check_type,
        COUNT(*) as count
    FROM auth.users a
    LEFT JOIN public.users p ON p.id = a.id
    WHERE p.id IS NULL
    
    UNION ALL
    
    SELECT 
        'Users without shops' as check_type,
        COUNT(*) as count
    FROM public.users u
    LEFT JOIN public.shops s ON s.owner_id = u.id
    WHERE s.id IS NULL
    
    UNION ALL
    
    SELECT 
        'Duplicate emails' as check_type,
        COUNT(*) as count
    FROM (
        SELECT email 
        FROM public.users 
        WHERE email IS NOT NULL 
        GROUP BY email 
        HAVING COUNT(*) > 1
    ) dup
    
    UNION ALL
    
    SELECT 
        'Users with NULL id (should be 0)' as check_type,
        COUNT(*) as count
    FROM public.users
    WHERE id IS NULL
)
SELECT * FROM checks
ORDER BY check_type;

-- All counts should be 0 for success!