-- Diagnostic Queries for Kakao OAuth Issues

-- 1. Check for orphaned auth users (auth users without profiles)
SELECT 
    a.id as auth_id,
    a.email as auth_email,
    a.created_at as auth_created,
    a.raw_app_meta_data->>'provider' as provider,
    p.id as profile_id
FROM auth.users a
LEFT JOIN public.users p ON p.id = a.id
WHERE p.id IS NULL
ORDER BY a.created_at DESC;

-- 2. Check for duplicate emails
SELECT 
    email,
    COUNT(*) as count,
    STRING_AGG(id::text, ', ') as user_ids
FROM public.users
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;

-- 3. Check auth users with duplicate emails
SELECT 
    email,
    COUNT(*) as count,
    STRING_AGG(id::text, ', ') as auth_user_ids
FROM auth.users
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;

-- 4. Find mismatched emails between auth and profile
SELECT 
    a.id,
    a.email as auth_email,
    p.email as profile_email,
    a.raw_app_meta_data->>'provider' as provider
FROM auth.users a
JOIN public.users p ON p.id = a.id
WHERE a.email != p.email OR (a.email IS NULL AND p.email IS NOT NULL) OR (a.email IS NOT NULL AND p.email IS NULL);

-- 5. Check users without shops
SELECT 
    u.id,
    u.name,
    u.email,
    u.shop_id,
    s.id as shop_exists
FROM public.users u
LEFT JOIN public.shops s ON s.owner_id = u.id
WHERE u.shop_id IS NULL OR s.id IS NULL;

-- 6. Find the specific user causing the issue (replace with actual email if known)
-- SELECT * FROM auth.users WHERE email = 'problematic@email.com';
-- SELECT * FROM public.users WHERE email = 'problematic@email.com';

-- 7. Check column constraints
SELECT 
    column_name,
    is_nullable,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'users'
    AND column_name IN ('email', 'phone', 'id')
ORDER BY ordinal_position;

-- 8. List all unique constraints on users table
SELECT 
    con.conname AS constraint_name,
    pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_namespace nsp ON nsp.oid = con.connamespace
JOIN pg_class cls ON cls.oid = con.conrelid
WHERE nsp.nspname = 'public'
    AND cls.relname = 'users'
    AND con.contype IN ('u', 'p');  -- unique and primary key constraints