-- Final forward cleanup for drifted environments that may still carry legacy_* identifiers.
-- This migration is intentionally idempotent: each step runs only when the legacy object exists.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.schemata
    WHERE schema_name = 'legacy_staging'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.schemata
    WHERE schema_name = 'import_staging'
  ) THEN
    EXECUTE 'ALTER SCHEMA legacy_staging RENAME TO import_staging';
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.legacy_user_map') IS NOT NULL
     AND to_regclass('public.import_user_map') IS NULL THEN
    EXECUTE 'ALTER TABLE public.legacy_user_map RENAME TO import_user_map';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'import_user_map'
      AND column_name = 'legacy_user_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.import_user_map RENAME COLUMN legacy_user_id TO import_user_id';
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'app_generation_job'
      AND column_name = 'legacy_task_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.app_generation_job RENAME COLUMN legacy_task_id TO numeric_task_id';
  END IF;

  IF to_regclass('public.idx_app_generation_job_legacy_task_id') IS NOT NULL THEN
    EXECUTE 'ALTER INDEX public.idx_app_generation_job_legacy_task_id RENAME TO idx_app_generation_job_numeric_task_id';
  END IF;

  IF to_regclass('public.app_generation_job_legacy_task_id_seq') IS NOT NULL THEN
    EXECUTE 'ALTER SEQUENCE public.app_generation_job_legacy_task_id_seq RENAME TO app_generation_job_numeric_task_id_seq';
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.app_generation_job_numeric_task_id_seq') IS NOT NULL THEN
    EXECUTE 'ALTER SEQUENCE public.app_generation_job_numeric_task_id_seq OWNED BY public.app_generation_job.numeric_task_id';
    EXECUTE 'ALTER TABLE public.app_generation_job ALTER COLUMN numeric_task_id SET DEFAULT nextval(''public.app_generation_job_numeric_task_id_seq'')';
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE proname = 'promote_legacy_from_staging'
      AND pg_function_is_visible(oid)
  ) THEN
    EXECUTE 'DROP FUNCTION IF EXISTS public.promote_legacy_from_staging()';
  END IF;
END;
$$;
