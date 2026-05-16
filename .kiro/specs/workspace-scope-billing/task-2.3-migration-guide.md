# Task 2.3: NOT NULL Constraint Migration Guide

## Overview

This document provides guidance for applying the NOT NULL constraint migration for `app_generation_job.workspace_id` (Task 2.3 of workspace-scope billing spec).

**Migration File**: `supabase/migrations/20260519140000_app_generation_job_workspace_id_not_null.sql`

## Prerequisites

Before applying this migration, ensure the following tasks are completed:

### Task 2.1: Job Enqueue Code (REQUIRED)
- [ ] All job creation entry points audited
- [ ] `resolve_billing_workspace_id(...)` implemented and tested
- [ ] Code deployed to production and stable
- [ ] No regression in job creation functionality

### Task 2.2: Backfill Script (REQUIRED)
- [ ] Backfill script implemented with `--dry-run` mode
- [ ] Script executed successfully on production data
- [ ] Coverage threshold achieved (see below)
- [ ] Orphan rows handled per documented fallback rules

## Pre-Migration Validation

### 1. Coverage Threshold Check

**Required**: >99% of `app_generation_job` rows must have `workspace_id` populated.

Run this query to check coverage:

```sql
SELECT 
  COUNT(*) FILTER (WHERE workspace_id IS NOT NULL) * 100.0 / COUNT(*) AS coverage_pct,
  COUNT(*) FILTER (WHERE workspace_id IS NULL) AS null_count,
  COUNT(*) AS total_count
FROM public.app_generation_job;
```

**Pass Criteria**: `coverage_pct >= 99.0`

**If Failed**: 
- Re-run backfill script (Task 2.2)
- Investigate why backfill didn't reach threshold
- Check for orphan rows or data quality issues

### 2. Recent Jobs Check

**Required**: All jobs created in the last 24-48 hours should have `workspace_id`.

Run this query:

```sql
SELECT COUNT(*) 
FROM public.app_generation_job 
WHERE created_at >= NOW() - INTERVAL '48 hours' 
  AND workspace_id IS NULL;
```

**Pass Criteria**: Should return `0` (or very close to 0)

**If Failed**:
- Job enqueue code (Task 2.1) may not be deployed
- Check if `resolve_billing_workspace_id` is being called
- Verify no regression in job creation paths

### 3. Monitoring Check

**Required**: No alerts or errors related to workspace_id resolution.

Check the following:
- [ ] Application logs show no workspace_id resolution failures
- [ ] Job creation success rate is normal (no spike in failures)
- [ ] No increase in job creation latency
- [ ] Backfill script completed without errors

### 4. Automated Validation

The migration includes an automated validation block that will:
- Calculate coverage percentage
- Count NULL workspace_id rows
- Check recent jobs (48h window)
- **FAIL the migration** if coverage < 99%
- **WARN** if recent jobs have NULL workspace_id

This validation runs automatically when the migration is applied.

## Applying the Migration

### Development/Staging

1. **Backup database** (recommended for all environments)
2. **Run validation queries** manually (see above)
3. **Apply migration**:
   ```bash
   # Using Supabase CLI
   supabase db push
   
   # Or using psql
   psql -f supabase/migrations/20260519140000_app_generation_job_workspace_id_not_null.sql
   ```
4. **Verify constraint applied**:
   ```sql
   SELECT is_nullable
   FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name = 'app_generation_job'
     AND column_name = 'workspace_id';
   ```
   Should return `NO`.

### Production

1. **Schedule maintenance window** (optional, but recommended)
2. **Verify all prerequisites** are met (see above)
3. **Run validation queries** and document results
4. **Get approval** from team lead/SRE
5. **Apply migration** during low-traffic period
6. **Monitor** for 15-30 minutes after applying:
   - Job creation success rate
   - Application error logs
   - Database constraint violations
   - Job enqueue latency

## Post-Migration Monitoring

After applying the migration, monitor the following for **7-14 days**:

### 1. Job Creation Success Rate
- Should remain stable (no increase in failures)
- Any failures should be investigated immediately
- Check for constraint violation errors

### 2. Application Error Logs
- Watch for `NOT NULL constraint violation` errors
- Watch for workspace_id resolution failures
- Any errors indicate a bug in job enqueue code (Task 2.1)

### 3. Database Metrics
- Query constraint violations:
  ```sql
  SELECT * FROM pg_stat_database WHERE datname = current_database();
  ```
- Look for increased deadlocks or constraint violations

### 4. Job Enqueue Latency
- Should remain stable (constraint check is fast)
- Any increase may indicate index issues

### 5. Workspace-Scoped Quota Enforcement
- Verify `jobs_today` counts are accurate
- Verify quota limits are enforced correctly
- Compare with user-scope counts during dual-write period

## Rollback Procedures

### Immediate Rollback (within hours)

If issues are detected immediately after applying:

```sql
-- Remove NOT NULL constraint
ALTER TABLE public.app_generation_job
  ALTER COLUMN workspace_id DROP NOT NULL;

-- Update column comment
COMMENT ON COLUMN public.app_generation_job.workspace_id IS 
  'Workspace attribution for billing and quota enforcement. NULL during migration = not yet backfilled. Used for workspace-scoped jobs_today aggregates when billing_scope=workspace. Foreign key to app_workspace with CASCADE delete.';
```

**Safe if**:
- No production issues detected
- Allows re-running backfill if coverage drops
- Job creation will continue to work

### Emergency Rollback (production incident)

If job creation is failing due to constraint violations:

1. **Rollback constraint immediately** (use SQL above)
2. **Restore service** (verify job creation works)
3. **Investigate root cause**:
   - Bug in job enqueue code (Task 2.1)?
   - Regression in workspace_id resolution?
   - Edge case not handled by backfill?
4. **Fix issue** and re-validate
5. **Re-apply constraint** after validation

### Delayed Rollback (NOT RECOMMENDED)

Rolling back days/weeks after applying is **NOT RECOMMENDED** because:
- May cause billing attribution issues for new jobs
- Workspace-scope billing may already be active
- Should only be done as part of full workspace-scope billing rollback
- Follow the read-path rollback procedure in docs/plans/ runbook

## Troubleshooting

### Migration Fails: Coverage < 99%

**Error**: `VALIDATION FAILED: Coverage X.XX% is below required 99%`

**Resolution**:
1. Re-run backfill script (Task 2.2) with `--dry-run` first
2. Investigate why backfill didn't reach threshold
3. Check for orphan rows or data quality issues
4. Fix backfill script if needed
5. Re-run backfill and re-validate

### Migration Fails: Constraint Violation

**Error**: `ERROR: column "workspace_id" contains null values`

**Resolution**:
1. The validation block should have caught this
2. New jobs with NULL workspace_id were created between validation and constraint
3. Run validation queries manually to identify NULL rows
4. Backfill missing rows
5. Re-apply migration

### Job Creation Fails After Migration

**Error**: `NOT NULL constraint violation on workspace_id`

**Resolution**:
1. **Immediate**: Rollback constraint (see above)
2. **Investigate**: Bug in job enqueue code (Task 2.1)
3. **Fix**: Update `resolve_billing_workspace_id` logic
4. **Test**: Verify fix in staging
5. **Re-apply**: Migration after validation

## Success Criteria

The migration is considered successful when:

- [ ] Migration applied without errors
- [ ] Validation block passed (coverage >= 99%)
- [ ] Post-migration verification passed (is_nullable = NO)
- [ ] Job creation success rate remains stable for 24-48 hours
- [ ] No constraint violation errors in application logs
- [ ] Workspace-scoped quota enforcement works correctly
- [ ] Monitoring shows no issues for 7-14 days

## Next Steps

After this migration is successfully applied and monitored:

1. **Task 3.x**: Implement metering & quota using workspace_id
2. **Task 5.x**: Implement GET /api/v1/me v2 with workspace billing
3. **Task 9.x**: Create cutover & runbook for read-path migration

## Related Documentation

- **Requirements**: `.kiro/specs/workspace-scope-billing/requirements.md`
- **Design**: `.kiro/specs/workspace-scope-billing/design.md`
- **Tasks**: `.kiro/specs/workspace-scope-billing/tasks.md`
- **ADR**: `docs/plans/adr-workspace-billing-storage-model.md`
- **Migration File**: `supabase/migrations/20260519140000_app_generation_job_workspace_id_not_null.sql`

## Questions or Issues

If you encounter issues not covered in this guide:

1. Check the migration file comments (comprehensive troubleshooting included)
2. Review the requirements and design documents
3. Consult with the team lead or SRE
4. Document the issue and resolution for future reference

---

**Document Version**: 1.0  
**Last Updated**: 2026-05-19  
**Author**: AI Agent (Task 2.3 Implementation)  
**Status**: Ready for Review
