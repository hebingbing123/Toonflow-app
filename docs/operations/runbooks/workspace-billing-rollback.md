# Workspace Billing Schema Rollback Runbook

## Overview

This runbook provides **safe rollback procedures** for the workspace-scope billing additive schema migrations (Tasks 1.1 and 1.2). The rollback is designed to remove **only** the objects introduced in these migrations, without touching existing user billing columns.

**Related specifications:**
- Requirements: `.kiro/specs/workspace-scope-billing/requirements.md`
- Design: `.kiro/specs/workspace-scope-billing/design.md`
- Tasks: `.kiro/specs/workspace-scope-billing/tasks.md`
- ADRs: `adr-workspace-billing-attribution.md`, `adr-workspace-billing-storage-model.md`

**Migrations covered:**
- `20260519120000_app_workspace_billing_columns.sql` (Task 1.1)
- `20260519130000_app_generation_job_workspace_id.sql` (Task 1.2)

---

## Safety Principles

### ✅ Safe to Rollback When:

1. **Additive phase only**: Workspace billing columns remain NULL or mostly NULL
2. **No production activation**: Workspace-scope billing (`billing_scope=workspace`) is NOT enabled in production
3. **No populated data**: `app_workspace` billing columns contain no critical production data
4. **No code dependencies**: Application code does NOT depend on `workspace_id` for critical operations
5. **Pre-backfill state**: Task 2.2 (backfill) has NOT been executed, or backfill was only in staging/dev

### ⚠️ Unsafe to Rollback When:

1. **Workspace billing activated**: Production workspaces have non-NULL `plan_tier`, `billing_customer_id`, etc.
2. **Post-backfill**: `app_generation_job.workspace_id` has been backfilled and made NOT NULL (Task 2.3)
3. **Dual-write active**: Stripe webhooks are writing to workspace billing columns (Task 4.1)
4. **API v2 enabled**: `/api/v1/me?v=2` is serving `current_workspace_billing` to production clients (Task 5.x)
5. **Quota enforcement live**: Workspace-scoped quota checks are active in production (Task 3.x)

**If any unsafe condition exists, use the [Read-Path Rollback](#read-path-rollback-operational) procedure instead.**

---

## Pre-Rollback Checklist

Before executing rollback, verify the following:

- [ ] **Confirm rollback authority**: Obtain sign-off from engineering lead and product owner
- [ ] **Check production state**: Verify workspace billing is NOT activated in production
- [ ] **Audit data population**: Run [Data Audit Queries](#data-audit-queries) to check for populated workspace billing data
- [ ] **Review application dependencies**: Confirm no production code paths depend on `workspace_id` column
- [ ] **Backup database**: Take a full database backup or snapshot before proceeding
- [ ] **Notify stakeholders**: Alert backend team, SRE, and product about planned rollback
- [ ] **Prepare monitoring**: Set up alerts for job creation failures and quota enforcement errors
- [ ] **Schedule maintenance window**: If possible, perform rollback during low-traffic period

---

## Data Audit Queries

Run these queries to assess rollback safety:

### Check workspace billing column population

```sql
-- Count workspaces with non-NULL billing columns
SELECT 
  COUNT(*) FILTER (WHERE plan_tier IS NOT NULL) AS workspaces_with_plan,
  COUNT(*) FILTER (WHERE billing_customer_id IS NOT NULL) AS workspaces_with_customer,
  COUNT(*) FILTER (WHERE daily_job_quota IS NOT NULL) AS workspaces_with_quota,
  COUNT(*) AS total_workspaces
FROM public.app_workspace;
```

**Safe to rollback if**: All counts (except `total_workspaces`) are 0 or very small (staging/dev only).

### Check workspace_id backfill status

```sql
-- Count jobs with workspace_id populated
SELECT 
  COUNT(*) FILTER (WHERE workspace_id IS NOT NULL) AS jobs_with_workspace,
  COUNT(*) FILTER (WHERE workspace_id IS NULL) AS jobs_without_workspace,
  COUNT(*) AS total_jobs,
  ROUND(100.0 * COUNT(*) FILTER (WHERE workspace_id IS NOT NULL) / NULLIF(COUNT(*), 0), 2) AS backfill_percentage
FROM public.app_generation_job;
```

**Safe to rollback if**: `backfill_percentage` is 0% or very low (< 5% and only staging/dev jobs).

### Check recent job creation patterns

```sql
-- Check if recent jobs have workspace_id (indicates active backfill or enforcement)
SELECT 
  COUNT(*) FILTER (WHERE workspace_id IS NOT NULL) AS recent_jobs_with_workspace,
  COUNT(*) AS total_recent_jobs
FROM public.app_generation_job
WHERE created_at >= NOW() - INTERVAL '24 hours';
```

**Safe to rollback if**: `recent_jobs_with_workspace` is 0 (no recent jobs using workspace attribution).

### Identify workspaces with billing data (for backup)

```sql
-- List workspaces with populated billing data (for backup before rollback)
SELECT 
  id,
  name,
  workspace_type,
  plan_tier,
  billing_currency,
  billing_provider,
  billing_customer_id,
  daily_job_quota
FROM public.app_workspace
WHERE plan_tier IS NOT NULL
   OR billing_customer_id IS NOT NULL
   OR daily_job_quota IS NOT NULL;
```

**Action**: Export this data to CSV before rollback if any rows exist.

---

## Rollback Procedure: Schema Objects

### Step 1: Drop app_generation_job workspace indexes

Drop the indexes created for workspace-scoped job aggregation:

```sql
-- Drop workspace job aggregation indexes
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_daily;
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_status;
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_created;
```

**Verification:**

```sql
-- Verify indexes are dropped
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'app_generation_job' 
  AND indexname LIKE '%workspace%';
```

**Expected result**: No rows returned.

### Step 2: Drop app_generation_job.workspace_id column

Remove the workspace attribution column from jobs:

```sql
-- Drop workspace_id column (includes foreign key constraint)
ALTER TABLE public.app_generation_job 
  DROP COLUMN IF EXISTS workspace_id;
```

**Verification:**

```sql
-- Verify column is dropped
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'app_generation_job' 
  AND column_name = 'workspace_id';
```

**Expected result**: No rows returned.

### Step 3: Drop app_workspace billing indexes

Drop the indexes created for workspace billing lookups:

```sql
-- Drop workspace billing indexes
DROP INDEX IF EXISTS public.idx_app_workspace_billing_customer;
DROP INDEX IF EXISTS public.idx_app_workspace_plan_tier;
```

**Verification:**

```sql
-- Verify indexes are dropped
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'app_workspace' 
  AND indexname IN ('idx_app_workspace_billing_customer', 'idx_app_workspace_plan_tier');
```

**Expected result**: No rows returned.

### Step 4: Drop app_workspace billing columns

Remove the workspace billing columns (in reverse order of dependencies):

```sql
-- Drop workspace billing columns
ALTER TABLE public.app_workspace 
  DROP COLUMN IF EXISTS daily_job_quota,
  DROP COLUMN IF EXISTS billing_customer_id,
  DROP COLUMN IF EXISTS billing_provider,
  DROP COLUMN IF EXISTS billing_currency,
  DROP COLUMN IF EXISTS plan_tier;
```

**Verification:**

```sql
-- Verify columns are dropped
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'app_workspace' 
  AND column_name IN ('plan_tier', 'billing_currency', 'billing_provider', 
                      'billing_customer_id', 'daily_job_quota');
```

**Expected result**: No rows returned.

### Step 5: Verify user billing columns remain intact

**Critical safety check**: Ensure existing user billing columns were NOT affected:

```sql
-- Verify user billing columns still exist
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'app_user_profile' 
  AND column_name IN ('plan_tier', 'daily_job_quota', 'subscription_status', 
                      'subscription_state', 'stripe_customer_id')
ORDER BY column_name;
```

**Expected result**: All user billing columns present and unchanged.

---

## Post-Rollback Verification

### Application Health Checks

1. **Job creation**: Verify jobs can still be created successfully
   ```bash
   # Test job creation via API (adjust endpoint as needed)
   curl -X POST https://your-api/api/v1/jobs \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"project_uuid": "...", "job_type": "..."}'
   ```

2. **Quota enforcement**: Verify user-scope quota checks still work
   - Create jobs up to user's daily quota
   - Verify quota denial after limit reached
   - Check logs for quota enforcement events

3. **Billing webhooks**: Verify Stripe webhooks still update user profiles
   - Trigger test webhook (staging)
   - Verify `app_user_profile` updated correctly
   - Check `app_billing_webhook_event` for successful processing

### Database Integrity Checks

```sql
-- Verify no orphaned foreign key references
SELECT COUNT(*) 
FROM information_schema.table_constraints 
WHERE constraint_type = 'FOREIGN KEY' 
  AND constraint_name LIKE '%workspace_id%';
```

**Expected result**: 0 (no workspace_id foreign keys remain).

```sql
-- Verify app_generation_job structure is valid
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'app_generation_job'
ORDER BY ordinal_position;
```

**Expected result**: Standard job columns present, no `workspace_id`.

### Backend Service Checks

1. **Restart backend services**: Ensure no cached schema references
   ```bash
   # Restart backend (adjust for your deployment)
   kubectl rollout restart deployment/backend
   # OR
   systemctl restart openflow-backend
   ```

2. **Check application logs**: Monitor for errors related to missing columns
   ```bash
   # Check for workspace_id or billing column errors
   kubectl logs -l app=backend --tail=100 | grep -i "workspace_id\|billing"
   ```

3. **Run backend tests**: Verify test suite passes
   ```bash
   cd backend
   cargo test
   ```

### Monitoring and Alerts

Monitor these metrics for 24-48 hours post-rollback:

- **Job creation rate**: Should remain stable
- **Job failure rate**: Should not increase
- **Quota denial rate**: Should remain stable (user-scope)
- **API error rate**: Should not increase
- **Database query errors**: Should remain at baseline

---

## Read-Path Rollback (Operational)

**Use this procedure when schema rollback is unsafe** (post-activation, post-backfill).

This approach **disables workspace-scope billing reads** without dropping database columns.

### Step 1: Disable API v2 responses

**Backend code change** (example location: `backend/src/app/handlers/me.rs`):

```rust
// Temporarily force all /me requests to v1 response
// Comment out or feature-flag v2 routing
pub async fn get_me_handler(
    // ... existing params
) -> Result<Json<MeResponse>, ApiError> {
    // ROLLBACK: Force v1 response regardless of query param
    // let version = query.v.unwrap_or(1);
    let version = 1; // Force v1 during rollback
    
    match version {
        1 => get_me_v1(user_id, db).await,
        // 2 => get_me_v2(user_id, db).await, // Disabled during rollback
        _ => Err(ApiError::BadRequest("Invalid version".into())),
    }
}
```

**Deploy**: Roll out backend change to disable v2 responses.

### Step 2: Revert quota enforcement to user-scope

**Backend code change** (example location: `backend/src/metering/quota.rs`):

```rust
// Force user-scope quota enforcement during rollback
pub async fn get_effective_billing_context(
    user_id: Uuid,
    workspace_id: Option<Uuid>,
    db: &PgPool,
) -> Result<BillingContext, QuotaError> {
    // ROLLBACK: Always use user-scope billing
    // let scope = determine_billing_scope(user_id, workspace_id, db).await?;
    let scope = BillingScope::User; // Force user-scope during rollback
    
    match scope {
        BillingScope::User => load_user_billing_context(user_id, db).await,
        // BillingScope::Workspace => load_workspace_billing_context(...), // Disabled
    }
}
```

**Deploy**: Roll out backend change to revert quota logic.

### Step 3: Disable webhook dual-write

**Backend code change** (example location: `backend/src/billing/webhooks.rs`):

```rust
// Disable workspace billing updates during rollback
pub async fn handle_stripe_webhook(
    event: StripeEvent,
    db: &PgPool,
) -> Result<(), WebhookError> {
    // Update user profile (existing logic)
    update_user_billing_profile(&event, db).await?;
    
    // ROLLBACK: Disable workspace billing updates
    // update_workspace_billing(&event, db).await?; // Disabled during rollback
    
    Ok(())
}
```

**Deploy**: Roll out backend change to stop workspace billing writes.

### Step 4: Verify read-path rollback

1. **Test /me endpoint**: Verify only v1 responses returned
   ```bash
   # Should return v1 format even with v=2
   curl https://your-api/api/v1/me?v=2 -H "Authorization: Bearer $TOKEN"
   ```

2. **Test quota enforcement**: Verify user-scope limits enforced
   - Check quota uses `app_user_profile.daily_job_quota`
   - Verify `jobs_today` counts by `owner_user_id`, not `workspace_id`

3. **Test webhook processing**: Verify only user profile updated
   - Trigger test webhook
   - Verify `app_user_profile` updated
   - Verify `app_workspace` billing columns unchanged

### Step 5: Monitor and communicate

- **Monitor**: Watch for errors, quota issues, billing discrepancies
- **Communicate**: Notify stakeholders that workspace billing is disabled
- **Document**: Record rollback reason and timeline for re-activation

---

## Rollback Decision Matrix

| Condition | Schema Rollback | Read-Path Rollback | Notes |
|-----------|----------------|-------------------|-------|
| Pre-backfill, no production data | ✅ Safe | ✅ Safe | Prefer schema rollback (cleaner) |
| Post-backfill, < 50% coverage | ⚠️ Risky | ✅ Safe | Use read-path rollback |
| Post-backfill, > 50% coverage | ❌ Unsafe | ✅ Safe | Must use read-path rollback |
| Workspace billing activated | ❌ Unsafe | ✅ Safe | Must use read-path rollback |
| Dual-write active | ❌ Unsafe | ✅ Safe | Must use read-path rollback |
| API v2 serving production | ❌ Unsafe | ✅ Safe | Must use read-path rollback |
| Critical billing data in workspace columns | ❌ Unsafe | ✅ Safe | Export data, use read-path rollback |

---

## Rollback Impact Assessment

### What is Removed (Schema Rollback)

**Database objects:**
- `app_workspace.plan_tier` column
- `app_workspace.billing_currency` column
- `app_workspace.billing_provider` column
- `app_workspace.billing_customer_id` column
- `app_workspace.daily_job_quota` column
- `app_generation_job.workspace_id` column
- 5 indexes for workspace billing and job aggregation

**Functionality:**
- Workspace-scoped billing attribution
- Workspace-scoped quota enforcement
- Workspace-level job aggregation
- `/api/v1/me` v2 responses (if implemented)

### What is Preserved

**Database objects:**
- All `app_user_profile` billing columns (unchanged)
- All `app_generation_job` columns except `workspace_id`
- All `app_workspace` columns except billing columns
- All existing indexes and constraints

**Functionality:**
- User-scope billing (existing behavior)
- User-scope quota enforcement
- Job creation and processing
- Stripe webhook processing (user profile updates)
- `/api/v1/me` v1 responses

### Rollback Side Effects

1. **Loss of workspace attribution**: Jobs created during workspace billing period lose `workspace_id` reference
2. **Quota enforcement reverts**: All quota checks use user-scope aggregates
3. **Billing reconciliation gaps**: Workspace billing data (if any) is lost unless exported
4. **API compatibility**: Clients expecting v2 responses will receive v1 (or errors if v2 forced)
5. **Monitoring gaps**: Workspace-scoped metrics and dashboards will break

---

## Re-Activation After Rollback

If workspace billing needs to be re-activated after rollback:

1. **Re-apply migrations**: Run migrations 1.1 and 1.2 again (idempotent)
2. **Re-run backfill**: Execute Task 2.2 backfill script with `--dry-run` first
3. **Re-enable code paths**: Remove rollback code changes (v2 API, quota, webhooks)
4. **Validate dual-write**: Run shadow period validation (Task 4.3)
5. **Re-enable v2 API**: Gradually roll out v2 responses to clients
6. **Monitor closely**: Watch for quota issues, billing discrepancies, job attribution errors

---

## Emergency Contacts

**Escalation path for rollback issues:**

1. **Backend team lead**: [Contact info]
2. **SRE on-call**: [Contact info]
3. **Database admin**: [Contact info]
4. **Product owner**: [Contact info]

**Incident response:**
- Create incident ticket: [Ticket system link]
- Join incident channel: [Slack/Teams channel]
- Follow incident runbook: [Link to incident response docs]

---

## Appendix: Rollback SQL Script

**Complete rollback script** (use with caution, verify safety first):

```sql
-- ============================================================================
-- Workspace Billing Schema Rollback Script
-- ============================================================================
-- WARNING: Only execute this script if rollback safety conditions are met!
-- See "Safety Principles" section in workspace-billing-rollback-runbook.md
-- ============================================================================

BEGIN;

-- Step 1: Drop app_generation_job workspace indexes
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_daily;
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_status;
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_created;

-- Step 2: Drop app_generation_job.workspace_id column
ALTER TABLE public.app_generation_job 
  DROP COLUMN IF EXISTS workspace_id;

-- Step 3: Drop app_workspace billing indexes
DROP INDEX IF EXISTS public.idx_app_workspace_billing_customer;
DROP INDEX IF EXISTS public.idx_app_workspace_plan_tier;

-- Step 4: Drop app_workspace billing columns
ALTER TABLE public.app_workspace 
  DROP COLUMN IF EXISTS daily_job_quota,
  DROP COLUMN IF EXISTS billing_customer_id,
  DROP COLUMN IF EXISTS billing_provider,
  DROP COLUMN IF EXISTS billing_currency,
  DROP COLUMN IF EXISTS plan_tier;

-- Verification queries (run after COMMIT)
-- Uncomment to run verification in same transaction (will rollback if errors)
/*
DO $$
DECLARE
  workspace_cols INTEGER;
  job_cols INTEGER;
  workspace_indexes INTEGER;
  job_indexes INTEGER;
BEGIN
  -- Check workspace billing columns are gone
  SELECT COUNT(*) INTO workspace_cols
  FROM information_schema.columns 
  WHERE table_schema = 'public' 
    AND table_name = 'app_workspace' 
    AND column_name IN ('plan_tier', 'billing_currency', 'billing_provider', 
                        'billing_customer_id', 'daily_job_quota');
  
  -- Check job workspace_id column is gone
  SELECT COUNT(*) INTO job_cols
  FROM information_schema.columns 
  WHERE table_schema = 'public' 
    AND table_name = 'app_generation_job' 
    AND column_name = 'workspace_id';
  
  -- Check workspace billing indexes are gone
  SELECT COUNT(*) INTO workspace_indexes
  FROM pg_indexes 
  WHERE tablename = 'app_workspace' 
    AND indexname IN ('idx_app_workspace_billing_customer', 'idx_app_workspace_plan_tier');
  
  -- Check job workspace indexes are gone
  SELECT COUNT(*) INTO job_indexes
  FROM pg_indexes 
  WHERE tablename = 'app_generation_job' 
    AND indexname LIKE '%workspace%';
  
  -- Raise error if any objects remain
  IF workspace_cols > 0 OR job_cols > 0 OR workspace_indexes > 0 OR job_indexes > 0 THEN
    RAISE EXCEPTION 'Rollback verification failed: workspace_cols=%, job_cols=%, workspace_indexes=%, job_indexes=%',
      workspace_cols, job_cols, workspace_indexes, job_indexes;
  END IF;
  
  RAISE NOTICE 'Rollback verification passed: all workspace billing objects removed';
END $$;
*/

-- COMMIT only after manual verification
-- COMMIT;

-- Or rollback if issues found
-- ROLLBACK;
```

**Usage:**

```bash
# Dry-run (in transaction, will rollback)
psql -d your_database -f rollback_workspace_billing.sql

# Execute (after verification)
# Uncomment COMMIT in script, then:
psql -d your_database -f rollback_workspace_billing.sql
```

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-05-19 | 1.0 | AI Agent | Initial rollback runbook for Tasks 1.1–1.2 |

**Related documents:**
- Migration 1.1: `supabase/migrations/20260519120000_app_workspace_billing_columns.sql`
- Migration 1.2: `supabase/migrations/20260519130000_app_generation_job_workspace_id.sql`
- Requirements: `.kiro/specs/workspace-scope-billing/requirements.md`
- Design: `.kiro/specs/workspace-scope-billing/design.md`
- Tasks: `.kiro/specs/workspace-scope-billing/tasks.md`
