# Backfill Job Workspace ID Runbook

**Related Spec**: `.kiro/specs/workspace-scope-billing/` (Task 2.2)  
**Requirements**: 2.1, 2.2, 2.3, 9.3  
**ADR**: `docs/plans/adr-workspace-billing-storage-model.md`

## Overview

This runbook describes how to backfill `workspace_id` for existing `app_generation_job` records that were created before the workspace billing migration. The backfill script is a critical step in the workspace-scope billing migration (W8.2–W8.4).

## Purpose

Before workspace billing was implemented, `app_generation_job` records did not have a `workspace_id` column. The migration added this column as nullable to allow for a safe, phased rollout:

1. **Phase 1** (Task 1.2): Add nullable `workspace_id` column
2. **Phase 2** (Task 2.2 - THIS RUNBOOK): Backfill existing NULL values
3. **Phase 3** (Task 2.3): Enforce NOT NULL constraint after backfill validation

## Resolution Strategy

The backfill script uses a **canonical resolution strategy** that mirrors the production job creation logic:

Note: this runbook belongs to the **future workspace-scope billing migration** track. The project-scope resolution order here is still aligned with the product-wide **UUID-first** convention: `project_uuid` is primary, `project_numeric_id` is legacy fallback only.

### Priority Order

1. **Project-based jobs** (highest priority):
   - Extract `project_uuid` from job payload first (preferred project scope) → resolve to project's `workspace_id`
   - If `project_uuid` is absent, try `project_numeric_id` (legacy fallback) → resolve to project's `workspace_id`

2. **Orphan jobs** (fallback):
   - Use job owner's personal workspace (guaranteed to exist via workspace foundation migration)

### Edge Cases

| Scenario | Behavior | Action Required |
|----------|----------|-----------------|
| Project deleted | Job remains NULL | Manual review needed |
| Project has NULL workspace_id | Falls back to personal workspace | Should not happen (foundation migration backfilled projects) |
| User has no personal workspace | Logged as error, job remains NULL | Should not happen (foundation migration creates personal workspaces) |
| Invalid project reference | Falls back to personal workspace | Logged as warning |
| Archived workspace | Still used for attribution | No action (historical billing reconciliation) |

## Prerequisites

1. **Database access**: Read/write access to production PostgreSQL
2. **Workspace foundation migration**: Must be complete (creates personal workspaces)
3. **Project workspace backfill**: Must be complete (projects have workspace_id)
4. **Backup**: Take database backup before running in production

## Usage

### 1. Dry-Run Mode (Recommended First Step)

Preview changes without applying them:

```bash
cd backend
DATABASE_URL=postgresql://user:pass@host/db \
  cargo run --bin backfill-job-workspace-id -- --dry-run
```

**Expected output:**
```
INFO starting workspace_id backfill dry_run=true batch_size=1000
INFO jobs with NULL workspace_id found total_jobs=5432
INFO processing batch batch_size=1000 processed=0 total=5432
INFO progress update processed=1000 updated=1000 failed=0 total=5432 progress_pct=18
...
INFO === Backfill Summary ===
INFO backfill complete mode="DRY-RUN" total_jobs=5432 processed=5432 updated=5432 failed=0
INFO Resolution methods:
INFO method stats method="project_uuid" count=4123 percentage=75
INFO method stats method="personal_workspace" count=1309 percentage=24
INFO DRY-RUN mode: no changes were applied
INFO Run without --dry-run to apply changes
```

### 2. Review Dry-Run Results

Check the resolution method distribution:

- **High `project_uuid` percentage** (>70%): Good, most jobs have project context
- **High `personal_workspace` percentage** (>50%): Review if expected (many orphan jobs)
- **Any `failed` count**: Investigate before applying

### 3. Apply Backfill

After validating dry-run results:

```bash
cd backend
DATABASE_URL=postgresql://user:pass@host/db \
  cargo run --bin backfill-job-workspace-id
```

**Expected output:**
```
INFO starting workspace_id backfill dry_run=false batch_size=1000
INFO jobs with NULL workspace_id found total_jobs=5432
INFO processing batch batch_size=1000 processed=0 total=5432
INFO progress update processed=1000 updated=1000 failed=0 total=5432 progress_pct=18
...
INFO === Backfill Summary ===
INFO backfill complete mode="APPLIED" total_jobs=5432 processed=5432 updated=5432 failed=0
INFO Resolution methods:
INFO method stats method="project_uuid" count=4123 percentage=75
INFO method stats method="personal_workspace" count=1309 percentage=24
INFO Backfill applied successfully
INFO All jobs resolved successfully - ready for Task 2.3 (enforce NOT NULL)
```

### 4. Custom Batch Size

For large datasets or constrained environments:

```bash
# Smaller batches (reduces memory usage)
cargo run --bin backfill-job-workspace-id -- --batch-size 500

# Larger batches (faster processing)
cargo run --bin backfill-job-workspace-id -- --batch-size 5000
```

## Validation

After running the backfill, validate the results:

### Quick Validation (Recommended)

Use the automated verification script:

```bash
cd scripts
DATABASE_URL=postgresql://user:pass@host/db ./verify_workspace_id_backfill.sh
```

This script runs all validation checks below and provides a summary report.

### Manual Validation Queries

#### 1. Check NULL Count

```sql
-- Should be 0 (or only failed jobs)
SELECT COUNT(*) 
FROM public.app_generation_job 
WHERE workspace_id IS NULL;
```

#### 2. Verify Resolution Distribution

```sql
-- Check workspace distribution
SELECT 
  w.workspace_type,
  COUNT(*) as job_count
FROM public.app_generation_job j
INNER JOIN public.app_workspace w ON w.id = j.workspace_id
GROUP BY w.workspace_type
ORDER BY job_count DESC;
```

Expected results:
- Most jobs should be in `personal` workspaces (if no enterprise workspaces exist yet)
- Distribution should match your user base

#### 3. Spot-Check Project-Based Jobs

```sql
-- Verify project-based jobs resolved correctly
SELECT 
  j.id as job_id,
  j.workspace_id as job_workspace_id,
  p.workspace_id as project_workspace_id,
  j.payload->>'project_uuid' as payload_project_uuid
FROM public.app_generation_job j
INNER JOIN public.app_project p ON p.id::text = j.payload->>'project_uuid'
WHERE j.workspace_id IS NOT NULL
LIMIT 10;
```

Expected: `job_workspace_id` should match `project_workspace_id`

#### 4. Check Orphan Jobs

```sql
-- Verify orphan jobs resolved to personal workspace
SELECT 
  j.id as job_id,
  j.owner_user_id,
  j.workspace_id,
  w.workspace_type,
  w.owner_user_id as workspace_owner
FROM public.app_generation_job j
INNER JOIN public.app_workspace w ON w.id = j.workspace_id
WHERE j.payload->>'project_uuid' IS NULL
  AND j.payload->>'project_numeric_id' IS NULL
  AND j.workspace_id IS NOT NULL
LIMIT 10;
```

Expected: 
- `workspace_type` = `'personal'`
- `j.owner_user_id` = `w.owner_user_id`

## Troubleshooting

### Failed Jobs (workspace_id still NULL)

If some jobs failed to resolve:

```sql
-- Find failed jobs
SELECT 
  id,
  owner_user_id,
  kind,
  payload->>'project_uuid' as project_uuid,
  payload->>'project_numeric_id' as project_numeric_id,
  created_at
FROM public.app_generation_job
WHERE workspace_id IS NULL
ORDER BY created_at DESC
LIMIT 20;
```

**Common causes:**

1. **Deleted project**: Project was deleted after job creation
   - **Solution**: Manually set to user's personal workspace
   
2. **User has no personal workspace**: Should not happen
   - **Solution**: Run workspace foundation migration again
   
3. **Invalid project reference**: Payload has malformed UUID/ID
   - **Solution**: Manually set to user's personal workspace

**Manual fix for failed jobs:**

```sql
-- Set failed jobs to owner's personal workspace
UPDATE public.app_generation_job j
SET workspace_id = (
  SELECT w.id
  FROM public.app_workspace w
  WHERE w.owner_user_id = j.owner_user_id
    AND w.workspace_type = 'personal'
  LIMIT 1
)
WHERE j.workspace_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.app_workspace w
    WHERE w.owner_user_id = j.owner_user_id
      AND w.workspace_type = 'personal'
  );
```

### Performance Issues

If backfill is slow:

1. **Check indexes**: Ensure indexes exist (created by migration 20260519130000)
   ```sql
   SELECT indexname 
   FROM pg_indexes 
   WHERE tablename = 'app_generation_job' 
     AND indexname LIKE '%workspace%';
   ```

2. **Reduce batch size**: Use `--batch-size 100` for constrained environments

3. **Monitor locks**: Check for blocking queries
   ```sql
   SELECT * FROM pg_stat_activity 
   WHERE state = 'active' 
     AND query LIKE '%app_generation_job%';
   ```

### Idempotency

The script is **idempotent** - it only updates jobs where `workspace_id IS NULL`. You can safely:

- Run multiple times
- Resume after interruption
- Re-run after fixing failed jobs

## Rollback

If you need to rollback the backfill (before Task 2.3 NOT NULL enforcement):

```sql
-- WARNING: This removes all workspace_id values
-- Only use if backfill results are incorrect and need to be re-run

UPDATE public.app_generation_job
SET workspace_id = NULL
WHERE workspace_id IS NOT NULL;
```

**Note**: After Task 2.3 (NOT NULL constraint), rollback requires dropping the constraint first.

## Next Steps

After successful backfill:

1. **Validate results** (see Validation section above)
2. **Monitor for 24-48 hours**: Ensure no issues with workspace attribution
3. **Proceed to Task 2.3**: Enforce NOT NULL constraint
   ```sql
   -- Task 2.3 migration (separate migration file)
   ALTER TABLE public.app_generation_job
   ALTER COLUMN workspace_id SET NOT NULL;
   ```

## Monitoring

After backfill, monitor these metrics:

- **New jobs with NULL workspace_id**: Should be 0 (job creation now sets workspace_id)
- **Workspace quota enforcement**: Should work correctly with backfilled data
- **Billing reconciliation**: Historical jobs now attributable to workspaces

## References

- **Spec**: `.kiro/specs/workspace-scope-billing/`
- **ADR**: `docs/plans/adr-workspace-billing-storage-model.md`
- **Migration**: `supabase/migrations/20260519130000_app_generation_job_workspace_id.sql`
- **Job creation logic**: `backend/src/jobs/enqueue.rs`
- **Workspace resolution**: `backend/src/jobs/billing_workspace.rs`
- **Verification script**: `scripts/verify_workspace_id_backfill.sh`

## Support

For issues or questions:

1. Check logs: Script uses `tracing` with structured logging
2. Review failed jobs query (see Troubleshooting section)
3. Consult workspace billing spec: `.kiro/specs/workspace-scope-billing/`
