# Security: Credential Rotation Guide

## ⚠️ IMMEDIATE ACTION REQUIRED

The following Supabase credentials were found hardcoded in the repository and **MUST BE ROTATED**:

- **Project URL**: `https://ewhurbwdqiemeuwdtpeg.supabase.co`
- **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (exposed)

## Why Rotate Credentials?

Even though these credentials have been removed from the code, they:
1. ✅ Are visible in git commit history (until history is cleaned)
2. ✅ May have been copied by developers who cloned the repo
3. ✅ Could be discovered through code search tools
4. ✅ Pose a security risk if the anon key has elevated permissions

## Step-by-Step Rotation Process

### Phase 1: Prepare New Project (Recommended for Production)

If this is a production system, consider migrating to a new Supabase project:

1. **Create New Supabase Project**
   - Go to https://app.supabase.com/
   - Create new project with a different name
   - Note the new credentials

2. **Migrate Database Schema**
   ```bash
   # Export from old project
   supabase db dump > schema_backup.sql

   # Import to new project
   psql "postgres://postgres:[password]@[new-db-host]:5432/postgres" < schema_backup.sql
   ```

3. **Migrate Storage Buckets**
   - Manually recreate storage buckets
   - Use Supabase Storage API to copy files

4. **Update All Deployments**
   - Update environment variables in production
   - Update CI/CD secrets
   - Rebuild and deploy both Flutter and Web apps

### Phase 2: Rotate Keys in Current Project (Faster, Less Secure)

If you want to keep the same project:

⚠️ **Warning**: Project URL cannot be changed, only the anon key can be rotated.

1. **Generate New Anon Key**
   ```bash
   # Go to Supabase Dashboard
   # Settings → API → Project API keys → Generate new anon key
   ```

2. **Update RLS Policies**
   - Ensure Row Level Security is enabled on all tables
   - Verify policies don't rely on old key structure

3. **Rolling Update Process**
   ```
   a. Deploy new credentials to Flutter app (users update gradually)
   b. Keep old key active for 30 days (grace period)
   c. Deploy new credentials to web app
   d. Monitor error logs for old key usage
   e. After 30 days, revoke old anon key
   ```

### Phase 3: Update Codebase

1. **Flutter App** ✅ Already Fixed
   - Credentials removed from `lib/config/supabase_config.dart`
   - Now uses `--dart-define` flags
   - See `resale_marketplace_app/ENV_CONFIG.md`

2. **Web App**
   ```bash
   # Update .env.local with new credentials
   cd resale_marketplace_web
   cp .env.example .env.local
   # Edit .env.local with new values
   ```

3. **CI/CD Pipelines**
   - GitHub Actions: Update secrets in Settings → Secrets
   - Vercel: Update environment variables in project settings
   - Other platforms: Update according to their documentation

### Phase 4: Verify Security

1. **Check RLS Policies**
   ```sql
   -- Verify all tables have RLS enabled
   SELECT schemaname, tablename, rowsecurity
   FROM pg_tables
   WHERE schemaname = 'public' AND rowsecurity = false;

   -- Should return no rows
   ```

2. **Test Anonymous Access**
   - Use new anon key to test API access
   - Verify only public data is accessible
   - Confirm authenticated endpoints require login

3. **Monitor Auth Logs**
   ```sql
   -- Check for unusual auth patterns
   SELECT created_at, email, raw_user_meta_data
   FROM auth.users
   ORDER BY created_at DESC
   LIMIT 100;
   ```

## Security Checklist

After rotation, verify:

- [ ] Old anon key revoked (after grace period)
- [ ] New credentials in CI/CD secrets
- [ ] Flutter app rebuilt with new credentials
- [ ] Web app deployed with new environment variables
- [ ] All developers notified to pull latest code
- [ ] `.env.local` files updated on all developer machines
- [ ] RLS policies tested and working
- [ ] Monitoring set up for suspicious activity
- [ ] Documentation updated with new setup process

## Prevention: Best Practices

### ✅ DO:
- Use environment variables (`--dart-define`, `.env.local`)
- Store secrets in CI/CD secret management
- Enable RLS on all database tables
- Use service role key only in secure backend environments
- Rotate keys every 90 days
- Monitor Supabase auth logs regularly

### ❌ DON'T:
- Hardcode credentials in source files
- Commit `.env`, `.env.local`, or similar files
- Share credentials via email, Slack, or chat
- Use the same credentials across environments (dev/staging/prod)
- Give anon key elevated permissions beyond public data access
- Disable RLS without explicit security review

## Additional Resources

- [Supabase Security Best Practices](https://supabase.com/docs/guides/auth/managing-user-data#security-considerations)
- [Row Level Security (RLS)](https://supabase.com/docs/guides/auth/row-level-security)
- [Managing API Keys](https://supabase.com/docs/guides/api/api-keys)

## Support

If credentials are compromised:
1. Immediately revoke exposed keys in Supabase Dashboard
2. Review auth logs for unauthorized access
3. Contact Supabase support if data breach suspected
4. Follow incident response procedures

---

**Last Updated**: 2025-10-14
**Status**: 🔴 ACTION REQUIRED - Credentials must be rotated before production launch
