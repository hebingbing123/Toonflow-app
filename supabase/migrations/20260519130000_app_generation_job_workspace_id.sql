-- Add workspace_id to app_generation_job for workspace-scope billing attribution
-- Related: .kiro/specs/workspace-scope-billing/ (Requirements 1.2, 1.3, 1.4, 8.1)
-- ADR: docs/plans/adr-workspace-billing-storage-model.md
-- Task: 1.2 Add migration for app_generation_job.workspace_id (nullable first) + index for aggregation

-- Add nullable workspace_id column to app_generation_job table
-- Column starts nullable to allow backfill (Task 2.2)
-- Will be made NOT NULL in a later migration (Task 2.3) after backfill is complete
-- NULL semantics during migration: "not yet backfilled" or "created before workspace attribution"

ALTER TABLE public.app_generation_job
  ADD COLUMN IF NOT EXISTS workspace_id UUID
    REFERENCES public.app_workspace (id) ON DELETE CASCADE;

-- Index for workspace-scoped job aggregation queries
-- Used for jobs_today counts by workspace when billing_scope=workspace
-- Supports efficient queries like:
--   SELECT COUNT(*) FROM app_generation_job 
--   WHERE workspace_id = ? AND created_at >= ?
CREATE INDEX IF NOT EXISTS idx_app_generation_job_workspace_created
  ON public.app_generation_job (workspace_id, created_at DESC)
  WHERE workspace_id IS NOT NULL;

-- Composite index for workspace + status queries (e.g., active jobs per workspace)
-- Supports queries filtering by workspace and status:
--   SELECT * FROM app_generation_job 
--   WHERE workspace_id = ? AND status IN ('queued', 'running')
CREATE INDEX IF NOT EXISTS idx_app_generation_job_workspace_status
  ON public.app_generation_job (workspace_id, status, created_at DESC)
  WHERE workspace_id IS NOT NULL;

-- Index for daily job quota enforcement (UTC day boundary)
-- Optimized for queries like:
--   SELECT COUNT(*) FROM app_generation_job
--   WHERE workspace_id = ? 
--     AND created_at >= date_trunc('day', NOW() AT TIME ZONE 'UTC')
--     AND created_at < date_trunc('day', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 day'
-- Note: Uses partial index (WHERE workspace_id IS NOT NULL) for efficiency
-- during migration period when many rows have NULL workspace_id
CREATE INDEX IF NOT EXISTS idx_app_generation_job_workspace_daily
  ON public.app_generation_job (workspace_id, created_at)
  WHERE workspace_id IS NOT NULL
    AND created_at >= date_trunc('day', NOW() AT TIME ZONE 'UTC');

-- Comments documenting the nullable semantics and workspace billing attribution
COMMENT ON COLUMN public.app_generation_job.workspace_id IS 
  'Workspace attribution for billing and quota enforcement. NULL during migration = not yet backfilled. After backfill (Task 2.2) and enforcement (Task 2.3), this becomes NOT NULL. Used for workspace-scoped jobs_today aggregates when billing_scope=workspace. Foreign key to app_workspace with CASCADE delete (if workspace deleted, jobs are deleted).';

-- Rollback guidance (for phase 1 additive-only migration):
-- To rollback this migration (before workspace-scope billing is activated):
--   DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_daily;
--   DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_status;
--   DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_created;
--   ALTER TABLE public.app_generation_job DROP COLUMN IF EXISTS workspace_id;
--
-- WARNING: Do NOT rollback after workspace-scope billing is activated in production
-- and workspace_id has been backfilled and made NOT NULL. Rollback is only safe during
-- the additive schema phase when the column remains nullable and mostly NULL.
--
-- For operational rollback after activation, use the read-path rollback procedure
-- documented in docs/plans/ runbook (disable v2 API + revert to user-scope reads
-- without dropping columns). The workspace_id column should be retained for audit
-- and future re-activation.
--
-- Rollback impact:
-- - Removes workspace attribution from jobs (reverts to user-scope only)
-- - Removes indexes used for workspace-scoped quota queries
-- - Does NOT affect existing user-scope billing logic (owner_user_id remains)
-- - Safe only if no production code depends on workspace_id column
--
-- Rollback verification:
-- After rollback, verify:
--   1. Job creation still works (uses owner_user_id for attribution)
--   2. User-scope quota enforcement still works
--   3. No application errors referencing workspace_id column
--   4. Backend tests pass (may need to update tests that reference workspace_id)
