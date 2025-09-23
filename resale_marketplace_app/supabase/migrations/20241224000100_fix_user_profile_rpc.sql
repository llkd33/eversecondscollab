-- Drop existing function if it exists
DROP FUNCTION IF EXISTS create_user_profile_safe CASCADE;

-- RPC 함수: 안전한 사용자 프로필 생성 (RLS 우회)
-- 카카오 OAuth 콜백 후 사용자 프로필 생성을 위한 함수 (개선된 버전)
CREATE OR REPLACE FUNCTION create_user_profile_safe(
  user_id UUID,
  user_email TEXT DEFAULT NULL,
  user_name TEXT DEFAULT '',
  user_phone TEXT DEFAULT '',
  user_profile_image TEXT DEFAULT NULL,
  user_role TEXT DEFAULT '일반',
  user_is_verified BOOLEAN DEFAULT true
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- RLS 우회를 위해 SECURITY DEFINER 사용
SET search_path = public, auth -- 명시적 스키마 설정
AS $$
DECLARE
  result JSON;
  shop_id UUID;
  final_phone TEXT;
  final_email TEXT;
  final_name TEXT;
  existing_user RECORD;
BEGIN
  -- 입력 데이터 정리
  final_name := COALESCE(NULLIF(TRIM(user_name), ''), '사용자' || SUBSTRING(user_id::TEXT, 1, 8));
  final_phone := COALESCE(NULLIF(TRIM(user_phone), ''), '');
  final_email := COALESCE(NULLIF(TRIM(user_email), ''), '');
  
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
  
  -- 전화번호 중복 확인 (비어있지 않은 경우만)
  IF final_phone != '' THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE phone = final_phone AND id != user_id) THEN
      -- 전화번호가 중복되면 빈 값으로 설정
      final_phone := '';
    END IF;
  END IF;
  
  -- 이메일 중복 확인 (비어있지 않은 경우만)
  IF final_email != '' THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE email = final_email AND id != user_id) THEN
      -- 이메일이 중복되면 synthetic 이메일 생성
      final_email := 'user' || REPLACE(user_id::TEXT, '-', '') || '@everseconds.dev';
    END IF;
  END IF;
  
  -- 트랜잭션 시작
  BEGIN
    -- 사용자 프로필 생성
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
      
      -- 유니크 제약 조건 위반 시 더 자세한 정보 제공
      SELECT json_build_object(
        'success', false,
        'message', '중복 데이터로 인한 생성 실패',
        'error_detail', SQLERRM,
        'user_id', user_id,
        'action', 'error'
      ) INTO result;
      
      RETURN result;
      
    WHEN OTHERS THEN
      -- 기타 오류 처리
      ROLLBACK;
      
      -- 상세한 오류 정보 포함
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

-- 함수 실행 권한 부여 (인증된 사용자와 anon 사용자 모두)
GRANT EXECUTE ON FUNCTION create_user_profile_safe TO authenticated, anon;

-- 함수 설명 추가
COMMENT ON FUNCTION create_user_profile_safe IS '카카오 OAuth 콜백 후 안전한 사용자 프로필 생성을 위한 RPC 함수 (개선된 버전)';