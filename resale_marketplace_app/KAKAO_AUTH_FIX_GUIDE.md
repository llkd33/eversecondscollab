# Kakao OAuth Database Error Fix Guide

## Issue Summary
The error "Database error saving new user" occurs during Kakao OAuth login due to:
1. The `phone` column in the `users` table has a NOT NULL constraint
2. Kakao OAuth doesn't provide phone numbers, causing NULL value violations
3. The RPC function wasn't properly handling NULL phone values

## Root Cause
From the Supabase error log:
```
ERROR: null value in column "phone" of relation "users" violates not-null constraint (SQLSTATE 23502)
```

## Solution Applied

### 1. Database Migrations
Two migration files have been created:

#### A. Fix RPC Function (`supabase/migrations/20241224000100_fix_user_profile_rpc.sql`)
- Added explicit schema paths (`public`, `auth`)
- Improved error handling with detailed error messages
- Added transaction support with proper rollback
- Better handling of unique constraint violations
- Grants execution permission to both `authenticated` and `anon` roles

#### B. Fix Phone NULL Constraint (`supabase/migrations/20241224000200_fix_phone_null_constraint.sql`)
- Removes NOT NULL constraint from `phone` column
- Removes NOT NULL constraint from `email` column
- Adds check constraint to ensure at least one identifier exists
- Updates RPC function to properly handle NULL values
- Cleans up existing empty string values to NULL

### 2. Flutter App Improvements

#### Auth Service (`lib/services/auth_service.dart`)
- Enhanced error handling for RPC function calls
- Added fallback mechanism to direct database insertion
- Improved error logging with detailed messages
- Fixed Kakao OAuth to use NULL for phone instead of empty string
- Updated RPC call to properly pass NULL values

#### Login Screen (`lib/screens/auth/login_screen.dart`)
- Added specific error message handling for database errors
- Better user-friendly error messages

#### Main App (`lib/main.dart`)
- Improved deep link error handling
- Better OAuth callback error processing
- Special handling for server_error with database failures

## How to Apply the Fix

### Step 1: Apply Database Migrations (IMPORTANT: Run both in order)

1. **Option A: Using Supabase Dashboard**
   - Go to Supabase Dashboard > SQL Editor
   - First, run `supabase/migrations/20241224000100_fix_user_profile_rpc.sql`
   - Then, run `supabase/migrations/20241224000200_fix_phone_null_constraint.sql`

2. **Option B: Using Supabase CLI**
   ```bash
   supabase migration up
   ```

**CRITICAL**: Both migrations must be applied in order. The second migration fixes the NOT NULL constraint issue.

### Step 2: Verify the RPC Function

Run this SQL query in Supabase Dashboard to verify the function exists:
```sql
SELECT 
  proname AS function_name,
  pg_get_functiondef(oid) AS function_definition
FROM pg_proc 
WHERE proname = 'create_user_profile_safe';
```

### Step 3: Test the Authentication Flow

1. **Clean Test Environment**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Run the App**:
   ```bash
   flutter run
   ```

3. **Test Kakao Login**:
   - Click "카카오로 시작하기" button
   - Complete Kakao OAuth flow
   - Verify successful login and profile creation

## Troubleshooting

### If the error persists:

1. **Check Database Logs**:
   - Go to Supabase Dashboard > Logs > Postgres
   - Look for errors related to `create_user_profile_safe`

2. **Verify Tables Exist**:
   ```sql
   -- Check users table
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'users';
   
   -- Check shops table
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'shops';
   ```

3. **Check RLS Policies**:
   ```sql
   -- List all policies on users table
   SELECT * FROM pg_policies WHERE tablename = 'users';
   ```

4. **Manual Test of RPC Function**:
   ```sql
   -- Test the RPC function manually (replace with actual UUID)
   SELECT create_user_profile_safe(
     'test-uuid-here'::uuid,
     'test@example.com',
     'Test User',
     '010-1234-5678',
     null,
     '일반',
     true
   );
   ```

### Common Issues and Solutions:

1. **"function does not exist" error**:
   - Re-run the migration SQL
   - Check if you're connected to the correct database

2. **Permission denied errors**:
   - Ensure the function has `SECURITY DEFINER`
   - Check the GRANT statements were executed

3. **Unique constraint violations**:
   - The function now handles these gracefully
   - Check if there are duplicate email/phone entries

## Monitoring

After applying the fix, monitor the following:

1. **Success Rate**:
   - Check Supabase Dashboard > Authentication > Users
   - New Kakao users should appear after login

2. **Error Logs**:
   - Monitor Flutter console for any error messages
   - Check Supabase logs for database errors

3. **User Experience**:
   - Users should be redirected to home screen after successful login
   - No error dialogs should appear for normal operations

## Rollback Plan

If issues occur after applying the fix:

```sql
-- Restore original function (if needed)
DROP FUNCTION IF EXISTS create_user_profile_safe CASCADE;

-- Then re-apply the original migration:
-- supabase/migrations/20241223000100_create_user_profile_rpc.sql
```

## Contact

If you continue to experience issues:
1. Check the Flutter app logs for detailed error messages
2. Review Supabase Dashboard logs
3. Verify all environment variables are correctly set