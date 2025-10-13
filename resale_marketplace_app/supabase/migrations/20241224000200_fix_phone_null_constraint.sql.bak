-- Fix the phone column to allow NULL values
-- This is needed because Kakao OAuth doesn't provide phone numbers
ALTER TABLE public.users 
ALTER COLUMN phone DROP NOT NULL;

-- Also update the email column to allow NULL (for users who don't provide email via OAuth)
ALTER TABLE public.users 
ALTER COLUMN email DROP NOT NULL;

-- Add a check constraint to ensure at least one identifier exists (email or phone)
ALTER TABLE public.users 
ADD CONSTRAINT users_has_identifier_check 
CHECK (email IS NOT NULL OR phone IS NOT NULL OR id IS NOT NULL);

-- Update the create_user_profile_safe function to handle NULL values properly
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
BEGIN
  -- 입력 데이터 정리 (빈 문자열을 NULL로 변환)
  final_name := COALESCE(NULLIF(TRIM(user_name), ''), '사용자' || SUBSTRING(user_id::TEXT, 1, 8));
  final_phone := NULLIF(TRIM(COALESCE(user_phone, '')), '');
  final_email := NULLIF(TRIM(COALESCE(user_email, '')), '');
  
  -- 이미 존재하는 사용자인지 확인
  SELECT * INTO existing_user FROM public.users WHERE id = user_id;
  
  IF existing_user.id IS NOT NULL THEN
    -- 기존 사용자 정보 반환
    SELECT json_build_object(
      'success', true,
      'message', '기존 사용자 프로필 사용',
      'user_id', user_id,
      'action', 'existing'
    ) INTO result;
    
    RETURN result;
  END IF;
  
  -- 전화번호 중복 확인 (NULL이 아니고 비어있지 않은 경우만)
  IF final_phone IS NOT NULL AND final_phone != '' THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE phone = final_phone AND id != user_id) THEN
      -- 전화번호가 중복되면 NULL로 설정
      final_phone := NULL;
    END IF;
  END IF;
  
  -- 이메일 중복 확인 (NULL이 아니고 비어있지 않은 경우만)
  IF final_email IS NOT NULL AND final_email != '' THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE email = final_email AND id != user_id) THEN
      -- 이메일이 중복되면 synthetic 이메일 생성
      final_email := 'user' || REPLACE(user_id::TEXT, '-', '') || '@everseconds.dev';
    END IF;
  END IF;
  
  -- 트랜잭션 시작
  BEGIN
    -- 사용자 프로필 생성 (NULL 값 허용)
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
      final_email,  -- Can be NULL
      final_name,   -- Never NULL
      final_phone,  -- Can be NULL
      user_is_verified,
      user_profile_image,
      user_role,
      NOW(),
      NOW()
    );
    
    -- 샵 생성 (트리거가 있지만 명시적으로 처리)
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
    
    -- 사용자 테이블의 shop_id 업데이트
    UPDATE public.users 
    SET shop_id = shop_id,
        updated_at = NOW()
    WHERE id = user_id;
    
    -- 성공 결과 반환
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
      -- 중복 키 오류 처리
      ROLLBACK;
      
      SELECT json_build_object(
        'success', false,
        'message', '중복 데이터로 인한 생성 실패',
        'error_detail', SQLERRM,
        'error_state', SQLSTATE,
        'user_id', user_id,
        'action', 'error'
      ) INTO result;
      
      RETURN result;
      
    WHEN OTHERS THEN
      -- 기타 오류 처리
      ROLLBACK;
      
      SELECT json_build_object(
        'success', false,
        'message', '사용자 프로필 생성 중 오류 발생',
        'error_detail', SQLERRM,
        'error_state', SQLSTATE,
        'user_id', user_id,
        'action', 'error'
      ) INTO result;
      
      RETURN result;
  END;
  
END;
$$;

-- 권한 재부여
GRANT EXECUTE ON FUNCTION create_user_profile_safe TO authenticated, anon, service_role;

-- 함수 설명 업데이트
COMMENT ON FUNCTION create_user_profile_safe IS '카카오 OAuth 콜백 후 안전한 사용자 프로필 생성 (NULL phone 허용)';

-- 기존 데이터 검증 (phone이 빈 문자열인 경우 NULL로 업데이트)
UPDATE public.users 
SET phone = NULL 
WHERE phone = '' OR phone = ' ';

-- 기존 데이터 검증 (email이 빈 문자열인 경우 NULL로 업데이트)
UPDATE public.users 
SET email = NULL 
WHERE email = '' OR email = ' ';