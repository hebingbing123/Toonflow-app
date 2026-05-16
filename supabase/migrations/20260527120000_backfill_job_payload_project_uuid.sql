-- Backfill project_uuid into app_generation_job payloads
-- Related: .kiro/specs/platform-completion-phase2/ H3.5 (Requirements 2.1–2.5, 12.1–12.10)
-- Analysis: .tmp/H3.5_migration_evaluation.md
--
-- PURPOSE:
--   Enrich existing job payloads that have project_numeric_id but are missing project_uuid.
--   This is a safe, additive migration that prepares for eventual D-batch numeric_id column
--   removal while maintaining full backward compatibility during the transition period.
--
-- SAFETY:
--   ✅ Additive only — adds data, does not remove anything
--   ✅ Idempotent — can be run multiple times safely (WHERE NOT (payload ? 'project_uuid'))
--   ✅ Non-breaking — backend code already handles both UUID and numeric
--   ✅ No schema changes — only updates JSONB payload content
--   ✅ Preserves existing data — does not overwrite existing project_uuid values
--
-- SCOPE:
--   Only updates jobs where:
--     1. payload contains 'project_numeric_id'
--     2. payload does NOT contain 'project_uuid'
--     3. The referenced project still exists in app_project
--   Jobs referencing deleted/orphaned projects are skipped (no project to resolve UUID from).
--
-- ROLLBACK:
--   This migration is safe to leave in place — it only adds data.
--   If needed, the added project_uuid fields can be removed with:
--     UPDATE public.app_generation_job
--     SET payload = payload - 'project_uuid'
--     WHERE payload ? 'project_uuid'
--       AND payload ? 'project_numeric_id';
--   (Only removes project_uuid from jobs that also have project_numeric_id, i.e. backfilled rows)

DO $$
DECLARE
  v_updated_count   INTEGER := 0;
  v_total_updated   INTEGER := 0;
  v_batch_size      INTEGER := 500;
  v_total_candidates INTEGER;
  v_batch_num       INTEGER := 0;
  v_orphaned_count  INTEGER;
  v_coverage_pct    NUMERIC;
  v_total_with_project INTEGER;
  v_with_uuid       INTEGER;
BEGIN
  -- Count total candidates for backfill
  SELECT COUNT(*)
  INTO v_total_candidates
  FROM public.app_generation_job j
  WHERE j.payload ? 'project_numeric_id'
    AND NOT (j.payload ? 'project_uuid');

  RAISE NOTICE '=== H3.5 Job Payload project_uuid Backfill ===';
  RAISE NOTICE 'Total jobs needing project_uuid enrichment: %', v_total_candidates;

  IF v_total_candidates = 0 THEN
    RAISE NOTICE 'No jobs to backfill — all project-scoped jobs already have project_uuid.';
  ELSE
    -- Process in batches to avoid long-running transactions on large datasets
    LOOP
      WITH batch AS (
        SELECT j.id, p.id AS project_uuid_val
        FROM public.app_generation_job j
        INNER JOIN public.app_project p
          ON p.numeric_id = (j.payload ->> 'project_numeric_id')::integer
        WHERE j.payload ? 'project_numeric_id'
          AND NOT (j.payload ? 'project_uuid')
        LIMIT v_batch_size
        FOR UPDATE OF j SKIP LOCKED
      )
      UPDATE public.app_generation_job j
      SET
        payload    = jsonb_set(
                       j.payload,
                       '{project_uuid}',
                       to_jsonb(batch.project_uuid_val::text)
                     ),
        updated_at = NOW()
      FROM batch
      WHERE j.id = batch.id;

      GET DIAGNOSTICS v_updated_count = ROW_COUNT;
      v_total_updated := v_total_updated + v_updated_count;

      EXIT WHEN v_updated_count = 0;

      v_batch_num := v_batch_num + 1;
      RAISE NOTICE 'Batch %: Updated % job payloads (running total: %)',
        v_batch_num, v_updated_count, v_total_updated;
    END LOOP;

    RAISE NOTICE 'Backfill loop complete. Total updated: %', v_total_updated;
  END IF;

  -- Count orphaned jobs (numeric_id present but project no longer exists)
  SELECT COUNT(*)
  INTO v_orphaned_count
  FROM public.app_generation_job j
  WHERE j.payload ? 'project_numeric_id'
    AND NOT (j.payload ? 'project_uuid')
    AND NOT EXISTS (
      SELECT 1
      FROM public.app_project p
      WHERE p.numeric_id = (j.payload ->> 'project_numeric_id')::integer
    );

  IF v_orphaned_count > 0 THEN
    RAISE NOTICE 'Orphaned jobs (project deleted): % — these cannot be backfilled and are expected.', v_orphaned_count;
  END IF;

  -- Final coverage report
  SELECT
    COUNT(*) FILTER (WHERE payload ? 'project_numeric_id' OR payload ? 'project_uuid'),
    COUNT(*) FILTER (WHERE payload ? 'project_uuid')
  INTO v_total_with_project, v_with_uuid
  FROM public.app_generation_job;

  IF v_total_with_project > 0 THEN
    v_coverage_pct := (v_with_uuid * 100.0) / v_total_with_project;
    RAISE NOTICE 'Coverage: %.2f%% of project-scoped jobs now have project_uuid (%/% jobs)',
      v_coverage_pct, v_with_uuid, v_total_with_project;
  ELSE
    RAISE NOTICE 'No project-scoped jobs found in table.';
  END IF;

  RAISE NOTICE '=== Backfill complete ===';
END $$;

-- Update table comment to document the backfill
COMMENT ON TABLE public.app_generation_job IS
  'Async generation jobs; Rust API uses service user via JWT sub. '
  'Payload enriched with project_uuid via H3.5 backfill migration to prepare for '
  'D-batch numeric_id column removal. See .tmp/H3.5_migration_evaluation.md.';
