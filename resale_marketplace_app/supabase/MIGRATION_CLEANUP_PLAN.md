# 🗄️ Database Migration Cleanup Plan

## Current State

The `supabase/` directory contains several emergency fix SQL files that were created during development. These need to be consolidated and cleaned up for production.

## Emergency Files to Review

```
supabase/
├── emergency_fix.sql
├── emergency_fix_corrected.sql
├── simple_fix_steps.sql
├── final_working_fix.sql
├── quick_chat_fix.sql
├── quick_messages_fix.sql
├── complete_chat_fix.sql
├── fix_chat_system.sql
├── fix_transaction_account_holder.sql
├── fix_missing_account_columns.sql
└── create_system_user.sql
```

## Action Items

### 1. Archive Emergency Fixes
Move emergency SQL files to an archive folder:
```bash
mkdir -p supabase/archive/emergency_fixes
mv supabase/emergency_*.sql supabase/archive/emergency_fixes/
mv supabase/quick_*.sql supabase/archive/emergency_fixes/
mv supabase/fix_*.sql supabase/archive/emergency_fixes/
mv supabase/complete_*.sql supabase/archive/emergency_fixes/
mv supabase/final_*.sql supabase/archive/emergency_fixes/
mv supabase/simple_*.sql supabase/archive/emergency_fixes/
mv supabase/create_system_user.sql supabase/archive/emergency_fixes/
```

### 2. Review Deleted Migrations

The following migrations appear in git changes as deleted:
- `20240101_add_performance_indexes.sql`
- `20241224000200_fix_phone_null_constraint.sql`
- `20241224000400_add_products_seller_fk.sql`
- `20241224000500_add_shops_owner_fk.sql`

**Action**: Check if these need to be restored or if their changes were consolidated into newer migrations.

### 3. Verify Migration Integrity

Run this to verify all migrations have been applied:
```sql
SELECT * FROM supabase_migrations.schema_migrations
ORDER BY version DESC
LIMIT 20;
```

### 4. Create Consolidated Migration (if needed)

If emergency fixes contain important changes not in migrations:
```bash
# Create new consolidated migration
touch supabase/migrations/$(date +%Y%m%d%H%M%S)_consolidate_emergency_fixes.sql
```

### 5. Update .gitignore

Ensure emergency fix files are ignored:
```gitignore
# Emergency SQL fixes (should be consolidated into proper migrations)
supabase/*fix*.sql
supabase/emergency*.sql
supabase/quick*.sql
supabase/simple*.sql
supabase/complete*.sql
supabase/final*.sql
```

## Migration Best Practices Going Forward

### ✅ DO:
1. Create proper timestamped migrations in `migrations/` folder
2. Use descriptive names: `YYYYMMDDHHMMSS_description.sql`
3. Test migrations on staging before production
4. Never delete migration files - create rollback migrations instead
5. Document each migration with comments
6. Keep migrations idempotent (safe to run multiple times)

### ❌ DON'T:
1. Create ad-hoc SQL files in root `supabase/` folder
2. Delete migration files from git history
3. Modify existing migrations after deployment
4. Skip testing migrations
5. Commit emergency fixes without consolidation

## Rollback Strategy

If you need to rollback a migration:
```sql
-- Create a new rollback migration
-- Example: 20250105120000_rollback_feature_x.sql

-- Revert changes (example)
DROP TABLE IF EXISTS feature_x;
DROP FUNCTION IF EXISTS get_feature_x();
```

## Verification Checklist

- [ ] All emergency SQL files archived
- [ ] No orphaned changes (all fixes in proper migrations)
- [ ] Migration table matches filesystem
- [ ] .gitignore updated
- [ ] Staging environment tested
- [ ] Documentation updated
- [ ] Team notified of changes

## Timeline

- **Immediate**: Archive emergency files
- **This Week**: Verify migration integrity
- **Before Next Deploy**: Consolidate any missing changes
- **Ongoing**: Follow migration best practices

## Notes

- Keep archived files for reference (6 months minimum)
- Document any critical fixes in project wiki
- Consider setting up migration linting/validation in CI/CD
