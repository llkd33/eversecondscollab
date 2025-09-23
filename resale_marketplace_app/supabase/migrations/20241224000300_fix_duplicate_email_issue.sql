-- Fix duplicate email constraint issue for OAuth users
-- This handles cases where Supabase Auth creates a user but profile creation fails

-- First, let's check and clean up any orphaned auth users without profiles
DO $$
DECLARE
    auth_user RECORD;
BEGIN
    -- Find auth users without corresponding profiles
    FOR auth_user IN 
        SELECT id, email 
        FROM auth.users 
        WHERE id NOT IN (SELECT id FROM public.users)
    LOOP
        -- Try to create a profile for orphaned auth users
        BEGIN
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
                auth_user.email,
                COALESCE(SPLIT_PART(auth_user.email, '@', 1), 'User'),
                NULL,
                true,
                '일반',
                NOW(),
                NOW()
            ) ON CONFLICT (id) DO NOTHING;
            
            RAISE NOTICE 'Created profile for orphaned auth user: %', auth_user.id;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not create profile for auth user %: %', auth_user.id, SQLERRM;
        END;
    END LOOP;
END $$;

-- Update the RPC function to better handle duplicate emails and existing auth users
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
  existing_email_user RECORD;
  auth_user RECORD;
BEGIN
  -- Get the auth user information
  SELECT * INTO auth_user FROM auth.users WHERE id = user_id;
  
  -- If no auth user exists, return error
  IF auth_user.id IS NULL THEN
    SELECT json_build_object(
      'success', false,
      'message', 'Auth user not found',
      'user_id', user_id,
      'action', 'error'
    ) INTO result;
    RETURN result;
  END IF;
  
  -- Check if profile already exists for this user ID
  SELECT * INTO existing_user FROM public.users WHERE id = user_id;
  
  IF existing_user.id IS NOT NULL THEN
    -- Profile already exists, just ensure shop exists and return success
    IF existing_user.shop_id IS NULL THEN
      -- Create shop if it doesn't exist
      INSERT INTO public.shops (
        owner_id,
        name,
        description,
        share_url,
        created_at,
        updated_at
      ) VALUES (
        user_id,
        existing_user.name || '의 샵',
        existing_user.name || '님의 개인 샵입니다.',
        'shop-' || REPLACE(user_id::TEXT, '-', ''),
        NOW(),
        NOW()
      )
      ON CONFLICT (owner_id) DO UPDATE
      SET updated_at = NOW()
      RETURNING id INTO shop_id;
      
      -- Update user's shop_id
      UPDATE public.users 
      SET shop_id = shop_id,
          updated_at = NOW()
      WHERE id = user_id;
    END IF;
    
    SELECT json_build_object(
      'success', true,
      'message', '기존 사용자 프로필 사용',
      'user_id', user_id,
      'action', 'existing',
      'shop_id', COALESCE(shop_id, existing_user.shop_id)
    ) INTO result;
    
    RETURN result;
  END IF;
  
  -- Clean and prepare input data
  final_name := COALESCE(NULLIF(TRIM(user_name), ''), '사용자' || SUBSTRING(user_id::TEXT, 1, 8));
  final_phone := NULLIF(TRIM(COALESCE(user_phone, '')), '');
  
  -- Handle email carefully
  final_email := NULLIF(TRIM(COALESCE(user_email, '')), '');
  
  -- Use auth user's email if not provided
  IF final_email IS NULL OR final_email = '' THEN
    final_email := auth_user.email;
  END IF;
  
  -- Check if email is already taken by another user
  IF final_email IS NOT NULL AND final_email != '' THEN
    SELECT * INTO existing_email_user 
    FROM public.users 
    WHERE email = final_email AND id != user_id;
    
    IF existing_email_user.id IS NOT NULL THEN
      -- Email is taken, generate a unique one
      final_email := 'kakao_' || REPLACE(user_id::TEXT, '-', '') || '@everseconds.dev';
    END IF;
  END IF;
  
  -- Check phone uniqueness
  IF final_phone IS NOT NULL AND final_phone != '' THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE phone = final_phone AND id != user_id) THEN
      final_phone := NULL;
    END IF;
  END IF;
  
  -- Create user profile
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
    
    -- Create shop
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
    
    -- Update user's shop_id
    UPDATE public.users 
    SET shop_id = shop_id,
        updated_at = NOW()
    WHERE id = user_id;
    
    SELECT json_build_object(
      'success', true,
      'message', '사용자 프로필 생성 완료',
      'user_id', user_id,
      'shop_id', shop_id,
      'action', 'created'
    ) INTO result;
    
    RETURN result;
    
  EXCEPTION
    WHEN unique_violation THEN
      -- Handle unique constraint violations
      IF SQLERRM LIKE '%users_email_key%' THEN
        -- Email conflict - try with synthetic email
        BEGIN
          final_email := 'kakao_' || REPLACE(user_id::TEXT, '-', '') || '@everseconds.dev';
          
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
          
          -- Create shop
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
          
          -- Update user's shop_id
          UPDATE public.users 
          SET shop_id = shop_id,
              updated_at = NOW()
          WHERE id = user_id;
          
          SELECT json_build_object(
            'success', true,
            'message', '사용자 프로필 생성 완료 (synthetic email)',
            'user_id', user_id,
            'shop_id', shop_id,
            'action', 'created'
          ) INTO result;
          
          RETURN result;
        EXCEPTION WHEN OTHERS THEN
          SELECT json_build_object(
            'success', false,
            'message', '프로필 생성 실패 (email 충돌 후 재시도 실패)',
            'error_detail', SQLERRM,
            'user_id', user_id,
            'action', 'error'
          ) INTO result;
          RETURN result;
        END;
      ELSE
        SELECT json_build_object(
          'success', false,
          'message', '중복 데이터로 인한 생성 실패',
          'error_detail', SQLERRM,
          'user_id', user_id,
          'action', 'error'
        ) INTO result;
        RETURN result;
      END IF;
      
    WHEN OTHERS THEN
      SELECT json_build_object(
        'success', false,
        'message', '사용자 프로필 생성 중 오류',
        'error_detail', SQLERRM,
        'error_state', SQLSTATE,
        'user_id', user_id,
        'action', 'error'
      ) INTO result;
      
      RETURN result;
  END;
  
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_user_profile_safe TO authenticated, anon, service_role;

-- Update function comment
COMMENT ON FUNCTION create_user_profile_safe IS 'OAuth 사용자 프로필 생성 - 중복 이메일 처리 개선';

-- Create a helper function to clean up duplicate auth users
CREATE OR REPLACE FUNCTION cleanup_duplicate_auth_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    duplicate_record RECORD;
BEGIN
    -- Find users with duplicate emails (keep the one with a profile)
    FOR duplicate_record IN 
        WITH duplicates AS (
            SELECT 
                a.id,
                a.email,
                p.id as profile_id,
                ROW_NUMBER() OVER (PARTITION BY a.email ORDER BY p.id DESC NULLS LAST, a.created_at ASC) as rn
            FROM auth.users a
            LEFT JOIN public.users p ON p.id = a.id
            WHERE a.email IS NOT NULL
        )
        SELECT id, email, profile_id
        FROM duplicates
        WHERE rn > 1 AND profile_id IS NULL
    LOOP
        -- Delete auth users without profiles that have duplicate emails
        DELETE FROM auth.users WHERE id = duplicate_record.id;
        RAISE NOTICE 'Deleted duplicate auth user without profile: % (%)', duplicate_record.id, duplicate_record.email;
    END LOOP;
END;
$$;

-- Clean up existing duplicates (optional - run manually if needed)
-- SELECT cleanup_duplicate_auth_users();