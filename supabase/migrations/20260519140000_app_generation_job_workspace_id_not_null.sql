-- Enforce NOT NULL constraint on app_generation_job.workspace_id
-- Related: .kiro/specs/workspace-scope-billing/ (Requirements 2.1, 2.2, 2.3, 9.3)
-- ADR: docs/plans/adr-workspace-billing-storage-model.md
-- Task: 2.3 Enforce NOT NULL (separate migration) only after backfill threshold / monitoring green

-- ============================================================================
-- PRE-MIGRATION VALIDATION CHECKS
-- ============================================================================
-- 
-- CRITICAL: This migration should ONLY be applied after the following conditions are met:
--
-- 1. BACKFILL THRESHOLD: >99% of app_generation_job rows have workspace_id populated
--    Verify with:
--      SELECT 
--        COUNT(*) FILTER (WHERE workspace_id IS NOT NULL) * 100.0 / COUNT(*) AS coverage_pct,
--        COUNT(*) FILTER (WHERE workspace_id IS NULL) AS null_count,
--        COUNT(*) AS total_count
--      FROM public.app_generation_job;
--
--    Required: coverage_pct >= 99.0
--
-- 2. MONITORING GREEN: No alerts or errors related to workspace_id resolution
--    - Check application logs for workspace_id resolution failures
--    - Verify job creation success rate is normal (no spike in failures)
--    - Confirm backfill script (Task 2.2) completed successfully
--
-- 3. RECENT JOBS: All jobs created in the last 24-48 hours have workspace_id
--    Verify with:
--      SELECT COUNT(*) 
--      FROM public.app_generation_job 
--      WHERE created_at >= NOW() - INTERVAL '48 hours' 
--        AND workspace_id IS NULL;
--
--    Required: Should return 0 (or very close to 0)
--
-- 4. PRODUCTION VALIDATION: Job enqueue code (Task 2.1) is deployed and stable
--    - resolve_billing_workspace_id(...) is implemented and tested
--    - All job creation entry points use the canonical resolution logic
--    - No regression in job creation functionality
--
-- ============================================================================
-- VALIDATION QUERY (Run this BEFORE applying migration)
-- ============================================================================
--
-- Run this query to check if the migration is safe to apply:
--
DO $$
DECLARE
  v_total_count BIGINT;
  v_null_count BIGINT;
  v_coverage_pct NUMERIC;
  v_recent_null_count BIGINT;
BEGIN
  -- Count total and null workspace_id rows
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE workspace_id IS NULL)
  INTO v_total_count, v_null_count
  FROM public.app_generation_job;
  
  -- Calculate coverage percentage
  IF v_total_count > 0 THEN
    v_coverage_pct := (v_total_count - v_null_count) * 100.0 / v_total_count;
  ELSE
    v_coverage_pct := 100.0;
  END IF;
  
  -- Count recent jobs with null workspace_id
  SELECT COUNT(*)
  INTO v_recent_null_count
  FROM public.app_generation_job
  WHERE created_at >= NOW() - INTERVAL '48 hours'
    AND workspace_id IS NULL;
  
  -- Report validation results
  RAISE NOTICE '=== PRE-MIGRATION VALIDATION RESULTS ===';
  RAISE NOTICE 'Total jobs: %', v_total_count;
  RAISE NOTICE 'Jobs with workspace_id: %', v_total_count - v_null_count;
  RAISE NOTICE 'Jobs without workspace_id: %', v_null_count;
  RAISE NOTICE 'Coverage: %.2f%%', v_coverage_pct;
  RAISE NOTICE 'Recent jobs (48h) without workspace_id: %', v_recent_null_count;
  RAISE NOTICE '';
  
  -- Check if migration is safe
  IF v_coverage_pct < 99.0 THEN
    RAISE EXCEPTION 'VALIDATION FAILED: Coverage %.2f%% is below required 99%%. Run backfill script (Task 2.2) first.', v_coverage_pct;
  END IF;
  
  IF v_recent_null_count > 0 THEN
    RAISE WARNING 'WARNING: % recent jobs (48h) have NULL workspace_id. Verify job enqueue code is deployed.', v_recent_null_count;
    -- Allow migration to proceed with warning, but operator should investigate
  END IF;
  
  RAISE NOTICE '✓ Validation passed: Coverage %.2f%% >= 99%%', v_coverage_pct;
  RAISE NOTICE '✓ Safe to apply NOT NULL constraint';
END $$;

-- ============================================================================
-- APPLY NOT NULL CONSTRAINT
-- ============================================================================
--
-- This ALTER TABLE will fail if any rows have NULL workspace_id.
-- The validation block above should catch this before we get here.
--
-- If this fails, it means:
-- 1. The validation block was skipped or ignored
-- 2. New jobs with NULL workspace_id were created between validation and constraint
-- 3. The backfill script (Task 2.2) did not complete successfully
--
-- Resolution: Run the backfill script again and re-run validation before retrying.

ALTER TABLE public.app_generation_job
  ALTER COLUMN workspace_id SET NOT NULL;

-- Update column comment to reflect NOT NULL enforcement
COMMENT ON COLUMN public.app_generation_job.workspace_id IS 
  'Workspace attribution for billing and quota enforcement. NOT NULL enforced after backfill (Task 2.2). Used for workspace-scoped jobs_today aggregates when billing_scope=workspace. Foreign key to app_workspace with CASCADE delete (if workspace deleted, jobs are deleted). Every job must be attributed to a workspace for billing purposes.';

-- ============================================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================================
--
-- Verify the constraint was applied successfully:
--
DO $$
DECLARE
  v_is_nullable TEXT;
BEGIN
  SELECT is_nullable
  INTO v_is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'app_generation_job'
    AND column_name = 'workspace_id';
  
  IF v_is_nullable = 'NO' THEN
    RAISE NOTICE '✓ NOT NULL constraint successfully applied to workspace_id';
  ELSE
    RAISE EXCEPTION 'VERIFICATION FAILED: workspace_id is still nullable';
  END IF;
END $$;

-- ============================================================================
-- ROLLBACK GUIDANCE
-- ============================================================================
--
-- To rollback this migration (remove NOT NULL constraint):
--
--   ALTER TABLE public.app_generation_job
--     ALTER COLUMN workspace_id DROP NOT NULL;
--
--   COMMENT ON COLUMN public.app_generation_job.workspace_id IS 
--     'Workspace attribution for billing and quota enforcement. NULL during migration = not yet backfilled. Used for workspace-scoped jobs_today aggregates when billing_scope=workspace. Foreign key to app_workspace with CASCADE delete.';
--
-- Rollback scenarios:
--
-- 1. IMMEDIATE ROLLBACK (within hours of applying):
--    - Safe if no production issues detected
--    - Allows re-running backfill if coverage drops
--    - Job creation will continue to work (code handles NULL during transition)
--
-- 2. DELAYED ROLLBACK (days/weeks after applying):
--    - Generally NOT RECOMMENDED once workspace-scope billing is active
--    - May cause billing attribution issues for new jobs
--    - Should only be done as part of full workspace-scope billing rollback
--    - Follow the read-path rollback procedure in docs/plans/ runbook
--
-- 3. EMERGENCY ROLLBACK (production incident):
--    - If job creation is failing due to workspace_id constraint violations
--    - Indicates job enqueue code (Task 2.1) has a bug or regression
--    - Rollback constraint immediately to restore service
--    - Fix job enqueue code and re-apply constraint after validation
--
-- Rollback verification:
-- After rollback, verify:
--   1. Job creation works (with or without workspace_id)
--   2. No constraint violation errors in application logs
--   3. Backfill script can be re-run to populate missing workspace_id values
--   4. Application code handles NULL workspace_id gracefully during transition
--
-- ============================================================================
-- MONITORING RECOMMENDATIONS
-- ============================================================================
--
-- After applying this migration, monitor:
--
-- 1. Job creation success rate
--    - Should remain stable (no increase in failures)
--    - Any failures should be investigated immediately
--
-- 2. Application error logs
--    - Watch for constraint violation errors
--    - Watch for workspace_id resolution failures
--
-- 3. Database constraint violations
--    - Query: SELECT * FROM pg_stat_database WHERE datname = current_database();
--    - Look for increased deadlocks or constraint violations
--
-- 4. Job enqueue latency
--    - Should remain stable (constraint check is fast)
--    - Any increase may indicate index issues
--
-- 5. Workspace-scoped quota enforcement
--    - Verify jobs_today counts are accurate
--    - Verify quota limits are enforced correctly
--    - Compare with user-scope counts during dual-write period
--
-- Recommended monitoring period: 7-14 days after applying constraint
-- before proceeding to next phase (read-path cutover).
--
-- ============================================================================
-- RELATED TASKS AND DOCUMENTATION
-- ============================================================================
--
-- Prerequisites (must be completed before this migration):
-- - Task 2.1: Audit job creation entry points, implement resolve_billing_workspace_id
-- - Task 2.2: Backfill script with --dry-run, >99% coverage achieved
--
-- Next steps (after this migration):
-- - Task 3.x: Metering & quota using workspace_id
-- - Task 5.x: GET /api/v1/me v2 with workspace billing
-- - Task 9.x: Cutover & runbook for read-path migration
--
-- Related documentation:
-- - Requirements: .kiro/specs/workspace-scope-billing/requirements.md
-- - Design: .kiro/specs/workspace-scope-billing/design.md
-- - Tasks: .kiro/specs/workspace-scope-billing/tasks.md
-- - ADR: docs/plans/adr-workspace-billing-storage-model.md
-- - Runbook: docs/plans/ (to be created in Task 9.1)
--
-- ============================================================================
