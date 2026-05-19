# Workspace Billing Schema Rollback Procedures

## Overview

This document provides **consolidated rollback procedures** for the additive database schema changes introduced in **Tasks 1.1 and 1.2** of the workspace-scope billing implementation (`.kiro/specs/workspace-scope-billing/`).

**Related documents:**
- Requirements: `.kiro/specs/workspace-scope-billing/requirements.md` (Requirements 1.2, 1.3, 1.4, 8.1)
- Design: `.kiro/specs/workspace-scope-billing/design.md`
- ADR: `docs/plans/adr-workspace-billing-storage-model.md`
- Cutover runbook: `docs/plans/workspace-billing-cutover-runbook.md`
- Full rollback procedures: `docs/plans/workspace-billing-rollback-procedures.md`

## Scope and Safety

### What This Rollback Covers

This rollback procedure **only** removes database objects introduced in migrations:
- **Migration 20260519120000**: `app_workspace` billing columns and indexes (Task 1.1)
- **Migration 20260519130000**: `app_generation_job.workspace_id` column and indexes (Task 1.2)

### Critical Safety Rules

⚠️ **SAFE ROLLBACK CONDITIONS** (all must be true):

1. **Additive phase only**: Workspace-scope billing has NOT been activated in production
2. **NULL columns**: All new columns remain NULL (no workspace billing data populated)
3. **No code dependencies**: No production application code reads or writes these columns
4. **User columns intact**: `app_user_profile` billing columns remain untouched

⚠️ **DO NOT ROLLBACK IF**:

- Workspace-scope billing is activated in production
- Workspace billing data has been populated (non-NULL values exist)
- Production code depends on `workspace_id` or workspace billing columns
- After backfill has run (Task 2.2) and `workspace_id` is NOT NULL
- After cutover to workspace-scope reads (see cutover runbook)

### What This Rollback Does NOT Do

❌ **This rollback does NOT**:
- Drop or modify `app_user_profile` billing columns (they remain intact)
- Affect existing user-scope billing logic
- Remove any user data or subscription information
- Modify any tables other than `app_workspace` and `app_generation_job`

✅ **After rollback**:
- User-scope billing continues to work normally
- Jobs continue to be attributed to `owner_user_id`
- Existing quota enforcement (user-scope) remains functional
- No user-facing impact if rollback conditions are met

## Rollback Procedures

### Prerequisites

1. **Verify safety conditions** (see above)
2. **Database backup**: Take a full backup before proceeding
3. **Application state**: Ensure no active deployments are in progress
4. **Monitoring**: Have database and application monitoring ready

### Step 1: Verify Current State

Before rolling back, verify the safety conditions:

```sql
-- Check if workspace billing columns have any non-NULL values
SELECT COUNT(*) as populated_workspaces
FROM public.app_workspace
WHERE plan_tier IS NOT NULL
   OR billing_currency IS NOT NULL
   OR billing_provider IS NOT NULL
   OR billing_customer_id IS NOT NULL
   OR daily_job_quota IS NOT NULL;
-- Expected: 0 (safe to rollback)
-- If > 0: DO NOT ROLLBACK - workspace billing data exists

-- Check if workspace_id has been backfilled
SELECT COUNT(*) as backfilled_jobs
FROM public.app_generation_job
WHERE workspace_id IS NOT NULL;
-- Expected: 0 or very small number (safe to rollback)
-- If large number: DO NOT ROLLBACK - backfill has run

-- Check if workspace_id is NOT NULL constraint
SELECT is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'app_generation_job'
  AND column_name = 'workspace_id';
-- Expected: 'YES' (nullable, safe to rollback)
-- If 'NO': DO NOT ROLLBACK - NOT NULL constraint applied (Task 2.3 complete)
```

**Decision point**: If any of the above checks fail, **STOP** and use the operational rollback procedure in `workspace-billing-rollback-procedures.md` instead (disable v2 API + revert read paths without dropping columns).

### Step 2: Rollback Migration 20260519130000 (app_generation_job.workspace_id)

Execute the following SQL to remove `workspace_id` column and related indexes:

```sql
-- Rollback migration: 20260519130000_app_generation_job_workspace_id.sql
-- Removes workspace attribution from jobs (reverts to user-scope only)

BEGIN;

-- Drop indexes for workspace-scoped job aggregation
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_daily;
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_status;
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_created;

-- Drop workspace_id column (CASCADE not needed - no dependent objects)
ALTER TABLE public.app_generation_job 
  DROP COLUMN IF EXISTS workspace_id;

COMMIT;
```

**Verification after Step 2**:

```sql
-- Verify workspace_id column is removed
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'app_generation_job'
  AND column_name = 'workspace_id';
-- Expected: 0 rows (column removed)

-- Verify indexes are removed
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'app_generation_job'
  AND indexname LIKE '%workspace%';
-- Expected: 0 rows (indexes removed)

-- Verify job creation still works (user-scope)
-- Test by creating a job through the application
-- Verify owner_user_id is set correctly
```

### Step 3: Rollback Migration 20260519120000 (app_workspace billing columns)

Execute the following SQL to remove workspace billing columns and indexes:

```sql
-- Rollback migration: 20260519120000_app_workspace_billing_columns.sql
-- Removes workspace-level billing storage (reverts to user-scope only)

BEGIN;

-- Drop indexes for billing operations
DROP INDEX IF EXISTS public.idx_app_workspace_billing_customer;
DROP INDEX IF EXISTS public.idx_app_workspace_plan_tier;

-- Drop billing columns (order matters: drop constrained columns first)
ALTER TABLE public.app_workspace 
  DROP COLUMN IF EXISTS daily_job_quota,
  DROP COLUMN IF EXISTS billing_customer_id,
  DROP COLUMN IF EXISTS billing_provider,
  DROP COLUMN IF EXISTS billing_currency,
  DROP COLUMN IF EXISTS plan_tier;

COMMIT;
```

**Verification after Step 3**:

```sql
-- Verify billing columns are removed
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'app_workspace'
  AND column_name IN ('plan_tier', 'billing_currency', 'billing_provider', 
                      'billing_customer_id', 'daily_job_quota');
-- Expected: 0 rows (columns removed)

-- Verify indexes are removed
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'app_workspace'
  AND (indexname LIKE '%billing%' OR indexname LIKE '%plan_tier%');
-- Expected: 0 rows (indexes removed)

-- Verify app_workspace table still functional
SELECT id, name, workspace_type, created_at
FROM public.app_workspace
LIMIT 1;
-- Expected: Query succeeds, returns workspace data
```

### Step 4: Verify User-Scope Billing Intact

Verify that user-scope billing columns remain untouched:

```sql
-- Verify app_user_profile billing columns are intact
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'app_user_profile'
  AND column_name IN ('plan_tier', 'daily_job_quota', 'subscription_status',
                      'subscription_state', 'billing_provider', 'billing_customer_id')
ORDER BY column_name;
-- Expected: All user billing columns present and unchanged

-- Verify user-scope billing data is intact
SELECT COUNT(*) as users_with_billing
FROM public.app_user_profile
WHERE plan_tier IS NOT NULL;
-- Expected: Same count as before rollback (no data loss)

-- Test user-scope quota enforcement
-- Create a job as a user and verify quota checks work
-- Verify jobs_today count is based on owner_user_id
```

### Step 5: Application Verification

After database rollback, verify application behavior:

1. **Backend tests**: Run full test suite
   ```bash
   cd backend
   cargo test
   ```

2. **Refactor checks**: Ensure all checks pass
   ```bash
   yarn refactor:check
   ```

3. **Job creation**: Test job creation through API
   - Verify jobs are created successfully
   - Verify `owner_user_id` is set correctly
   - Verify user-scope quota enforcement works

4. **Billing webhooks**: Test Stripe webhook processing
   - Verify webhooks update `app_user_profile` correctly
   - Verify no errors referencing workspace billing columns

5. **API endpoints**: Test `/api/v1/me` and related endpoints
   - Verify user billing information is returned correctly
   - Verify no errors referencing workspace billing fields

## Rollback Impact Assessment

### Database Impact

- **Tables modified**: `app_workspace`, `app_generation_job`
- **Columns removed**: 5 columns from `app_workspace`, 1 column from `app_generation_job`
- **Indexes removed**: 5 indexes total
- **Data loss**: None (columns were NULL)
- **Foreign keys**: `workspace_id` FK removed (no cascade impact)

### Application Impact

- **User-scope billing**: No impact (continues to work normally)
- **Job attribution**: Reverts to `owner_user_id` only
- **Quota enforcement**: Reverts to user-scope aggregates
- **API responses**: No impact if v2 API not deployed
- **Webhooks**: No impact if dual-write not deployed

### Monitoring After Rollback

Monitor the following for 24-48 hours after rollback:

1. **Job creation rate**: Should remain stable
2. **Quota enforcement**: Should work correctly (user-scope)
3. **Billing webhooks**: Should process successfully
4. **Database errors**: No errors referencing dropped columns
5. **Application errors**: No errors in backend logs
6. **User reports**: No user-facing issues

## Troubleshooting

### Issue: "Column does not exist" errors after rollback

**Cause**: Application code still references dropped columns

**Resolution**:
1. Identify code referencing `workspace_id` or workspace billing columns
2. Deploy code that removes these references
3. Verify application tests pass
4. Redeploy application

### Issue: Rollback fails due to non-NULL values

**Cause**: Workspace billing data has been populated

**Resolution**:
1. **DO NOT** force drop columns with data
2. Use operational rollback procedure instead (see `workspace-billing-rollback-procedures.md`)
3. Disable v2 API and revert read paths
4. Keep columns for audit and future re-activation

### Issue: Foreign key constraint errors

**Cause**: Unexpected dependencies on `workspace_id`

**Resolution**:
1. Identify dependent objects:
   ```sql
   SELECT conname, conrelid::regclass
   FROM pg_constraint
   WHERE confrelid = 'public.app_generation_job'::regclass
     AND conkey @> ARRAY[(SELECT attnum FROM pg_attribute 
                          WHERE attrelid = 'public.app_generation_job'::regclass 
                          AND attname = 'workspace_id')];
   ```
2. Drop dependent constraints first
3. Retry rollback
4. Document unexpected dependencies

### Issue: Tests fail after rollback

**Cause**: Tests reference workspace billing features

**Resolution**:
1. Update tests to remove workspace billing references
2. Ensure tests use user-scope billing paths
3. Run full test suite to verify
4. Update test documentation

## Post-Rollback Checklist

After completing rollback, verify:

- [ ] All SQL verification queries pass
- [ ] `yarn refactor:check` passes
- [ ] Backend tests pass (`cargo test`)
- [ ] Job creation works through API
- [ ] User-scope quota enforcement works
- [ ] Billing webhooks process successfully
- [ ] No database errors in logs
- [ ] No application errors in logs
- [ ] Monitoring shows normal behavior
- [ ] User-facing features work correctly

## Re-applying Migrations

If you need to re-apply the migrations after rollback:

1. **Verify prerequisites**: Ensure all safety conditions are met
2. **Run migrations**: Apply migrations in order
   ```bash
   # Migration 1.1: workspace billing columns
   psql -f supabase/migrations/20260519120000_app_workspace_billing_columns.sql
   
   # Migration 1.2: workspace_id column
   psql -f supabase/migrations/20260519130000_app_generation_job_workspace_id.sql
   ```
3. **Verify**: Run verification queries from migration files
4. **Test**: Run full test suite and refactor checks

## Related Documentation

- **Cutover runbook**: `docs/plans/workspace-billing-cutover-runbook.md` - Full cutover procedures
- **Operational rollback**: `docs/plans/workspace-billing-rollback-procedures.md` - Rollback after activation
- **ADR**: `docs/plans/adr-workspace-billing-storage-model.md` - Storage model decisions
- **Requirements**: `.kiro/specs/workspace-scope-billing/requirements.md` - Full requirements
- **Design**: `.kiro/specs/workspace-scope-billing/design.md` - Architecture and design

## Approval and Sign-off

Before executing this rollback in production:

- [ ] Database backup completed and verified
- [ ] Safety conditions verified (all columns NULL)
- [ ] Application deployment paused
- [ ] Monitoring and alerting ready
- [ ] Rollback approved by: _________________ (Date: _________)
- [ ] Post-rollback verification completed by: _________________ (Date: _________)

---

**Document version**: 1.0  
**Last updated**: 2026-05-19  
**Owner**: Backend team  
**Related spec**: `.kiro/specs/workspace-scope-billing/`
