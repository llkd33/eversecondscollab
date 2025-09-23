-- EMERGENCY FIX for Kakao OAuth duplicate email issue (CORRECTED)
-- Run this IMMEDIATELY in Supabase SQL Editor

-- Step 1: Remove the unique constraint on email temporarily
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_email_key;

-- Step 2: Allow NULL values for email and phone
ALTER TABLE public.users ALTER COLUMN email DROP NOT NULL;
ALTER TABLE public.users ALTER COLUMN phone DROP NOT NULL;

-- Step 3: Find and fix any existing duplicate emails
UPDATE public.users u1
SET email = 'dup_' || u1.id::text || '@temp.com'
WHERE u1.email IN (
    SELECT email 
    FROM public.users 
    WHERE email IS NOT NULL 
    GROUP BY email 
    HAVING COUNT(*) > 1
)
AND u1.created_at > (
    SELECT MIN(created_at) 
    FROM public.users u2 
    WHERE u2.email = u1.email
);

-- Step 4: Re-add the unique constraint (but allow NULLs)
ALTER TABLE public.users ADD CONSTRAINT users_email_key UNIQUE (email);

-- Step 5: Create or replace the improved RPC function
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
  shop_id UUID;
  final_phone TEXT;
  final_email TEXT;
  final_name TEXT;
  existing_user RECORD;
  auth_user RECORD;
  conflict_count INT := 0;
BEGIN
  -- Check if profile already exists
  SELECT * INTO existing_user FROM public.users WHERE id = user_id;
  
  IF existing_user.id IS NOT NULL THEN
    -- Profile exists, ensure shop exists
    IF existing_user.shop_id IS NULL THEN
      INSERT INTO public.shops (
        owner_id,
        name,
        description,
        share_url,
        created_at,
        updated_at
      ) VALUES (
        user_id,
        COALESCE(existing_user.name, '사용자') || '의 샵',
        COALESCE(existing_user.name, '사용자') || '님의 개인 샵입니다.',
        'shop-' || REPLACE(user_id::TEXT, '-', ''),
        NOW(),
        NOW()
      )
      ON CONFLICT (owner_id) DO UPDATE
      SET updated_at = NOW()
      RETURNING id INTO shop_id;
      
      UPDATE public.users 
      SET shop_id = shop_id,
          updated_at = NOW()
      WHERE id = user_id;
    ELSE
      shop_id := existing_user.shop_id;
    END IF;
    
    RETURN json_build_object(
      'success', true,
      'message', '기존 사용자 프로필 사용',
      'user_id', user_id,
      'shop_id', shop_id,
      'action', 'existing'
    );
  END IF;
  
  -- Prepare data
  final_name := COALESCE(NULLIF(TRIM(user_name), ''), '사용자' || SUBSTRING(user_id::TEXT, 1, 8));
  final_phone := NULLIF(TRIM(COALESCE(user_phone, '')), '');
  final_email := NULLIF(TRIM(COALESCE(user_email, '')), '');
  
  -- Check for email conflicts
  IF final_email IS NOT NULL THEN
    SELECT COUNT(*) INTO conflict_count 
    FROM public.users 
    WHERE email = final_email AND id != user_id;
    
    IF conflict_count > 0 THEN
      -- Email conflict, generate unique email
      final_email := 'kakao_' || REPLACE(user_id::TEXT, '-', '') || '@oauth.local';
    END IF;
  END IF;
  
  -- Create user profile with retry logic
  <<retry_loop>>
  FOR i IN 1..3 LOOP
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
        final_phone,
        user_is_verified,
        user_profile_image,
        user_role,
        NOW(),
        NOW()
      );
      
      -- Success, create shop
      INSERT INTO public.shops (
        owner_id,
        name,
        description,
        share_url,
        created_at,
        updated_at
      ) VALUES (
        user_id,
        final_name || '의 샵',
        final_name || '님의 개인 샵입니다.',
        'shop-' || REPLACE(user_id::TEXT, '-', ''),
        NOW(),
        NOW()
      )
      ON CONFLICT (owner_id) DO UPDATE
      SET updated_at = NOW()
      RETURNING id INTO shop_id;
      
      UPDATE public.users 
      SET shop_id = shop_id,
          updated_at = NOW()
      WHERE id = user_id;
      
      RETURN json_build_object(
        'success', true,
        'message', '사용자 프로필 생성 완료',
        'user_id', user_id,
        'shop_id', shop_id,
        'action', 'created'
      );
      
    EXCEPTION 
      WHEN unique_violation THEN
        -- Retry with different email
        IF i < 3 THEN
          final_email := 'kakao_' || REPLACE(user_id::TEXT, '-', '') || '_' || i || '@oauth.local';
          CONTINUE retry_loop;
        ELSE
          RETURN json_build_object(
            'success', false,
            'message', 'Failed after 3 attempts',
            'error_detail', SQLERRM,
            'user_id', user_id,
            'action', 'error'
          );
        END IF;
      WHEN OTHERS THEN
        RETURN json_build_object(
          'success', false,
          'message', 'Unexpected error',
          'error_detail', SQLERRM,
          'user_id', user_id,
          'action', 'error'
        );
    END;
  END LOOP;
  
END;
$$;

-- Step 6: Grant permissions
GRANT EXECUTE ON FUNCTION create_user_profile_safe TO authenticated, anon, service_role;

-- Step 7: Clean up orphaned auth users without profiles
DO $$
DECLARE
    auth_user RECORD;
    profile_created BOOLEAN;
BEGIN
    FOR auth_user IN 
        SELECT a.id, a.email, a.raw_user_meta_data
        FROM auth.users a
        LEFT JOIN public.users p ON p.id = a.id
        WHERE p.id IS NULL
    LOOP
        BEGIN
            -- Try to create profile for orphaned auth user
            INSERT INTO public.users (
                id,
                email,
                name,
                phone,
                is_verified,
                role,
                created_at,
                updated_at
            ) VALUES (
                auth_user.id,
                COALESCE(auth_user.email, 'orphan_' || auth_user.id::text || '@temp.com'),
                COALESCE(
                    auth_user.raw_user_meta_data->>'name',
                    auth_user.raw_user_meta_data->>'full_name',
                    'User ' || SUBSTRING(auth_user.id::TEXT, 1, 8)
                ),
                NULL,
                true,
                '일반',
                NOW(),
                NOW()
            ) ON CONFLICT (id) DO NOTHING;
            
            -- Also create shop
            INSERT INTO public.shops (
                owner_id,
                name,
                description,
                share_url,
                created_at,
                updated_at
            ) VALUES (
                auth_user.id,
                'User ' || SUBSTRING(auth_user.id::TEXT, 1, 8) || '의 샵',
                '개인 샵입니다.',
                'shop-' || REPLACE(auth_user.id::TEXT, '-', ''),
                NOW(),
                NOW()
            ) ON CONFLICT (owner_id) DO NOTHING;
            
            -- Update user with shop_id
            UPDATE public.users u
            SET shop_id = s.id
            FROM public.shops s
            WHERE u.id = auth_user.id AND s.owner_id = auth_user.id AND u.shop_id IS NULL;
            
            RAISE NOTICE 'Created profile for orphaned auth user: %', auth_user.id;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not create profile for %: %', auth_user.id, SQLERRM;
        END;
    END LOOP;
END $$;

-- Step 8: Verify the fix
SELECT 
    'Auth users without profiles:' as check_type,
    COUNT(*) as count
FROM auth.users a
LEFT JOIN public.users p ON p.id = a.id
WHERE p.id IS NULL

UNION ALL

SELECT 
    'Duplicate emails in users table:' as check_type,
    COUNT(DISTINCT email) as count
FROM (
    SELECT email 
    FROM public.users 
    WHERE email IS NOT NULL 
    GROUP BY email 
    HAVING COUNT(*) > 1
) dup

UNION ALL

SELECT 
    'Users without shops:' as check_type,
    COUNT(*) as count
FROM public.users u
LEFT JOIN public.shops s ON s.owner_id = u.id
WHERE s.id IS NULL;

-- If everything is 0, the fix worked!