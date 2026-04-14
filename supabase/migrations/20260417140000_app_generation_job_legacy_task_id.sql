CREATE SEQUENCE IF NOT EXISTS public.app_generation_job_legacy_task_id_seq;

ALTER TABLE public.app_generation_job
ADD COLUMN IF NOT EXISTS legacy_task_id BIGINT;

ALTER TABLE public.app_generation_job
ALTER COLUMN legacy_task_id SET DEFAULT nextval('public.app_generation_job_legacy_task_id_seq');

UPDATE public.app_generation_job
SET legacy_task_id = nextval('public.app_generation_job_legacy_task_id_seq')
WHERE legacy_task_id IS NULL;

SELECT setval(
  'public.app_generation_job_legacy_task_id_seq',
  GREATEST(
    1::bigint,
    COALESCE((SELECT MAX(legacy_task_id) FROM public.app_generation_job), 0)
  ),
  true
);

ALTER TABLE public.app_generation_job
ALTER COLUMN legacy_task_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_generation_job_legacy_task_id
ON public.app_generation_job (legacy_task_id);

ALTER SEQUENCE public.app_generation_job_legacy_task_id_seq
OWNED BY public.app_generation_job.legacy_task_id;

COMMENT ON COLUMN public.app_generation_job.legacy_task_id IS 'Monotonic bigint task id for 历史 task-center compatibility; distinct from UUID primary key.';
