-- Cancelled status + optional idempotency key per owner (dedupe POST /api/v1/jobs).

ALTER TABLE public.app_generation_job DROP CONSTRAINT IF EXISTS app_generation_job_status_check;

ALTER TABLE public.app_generation_job
ADD CONSTRAINT app_generation_job_status_check CHECK (
  status IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')
);

ALTER TABLE public.app_generation_job
ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS app_generation_job_owner_idem ON public.app_generation_job (owner_user_id, idempotency_key)
WHERE
  idempotency_key IS NOT NULL;

COMMENT ON COLUMN public.app_generation_job.idempotency_key IS 'Optional; unique per owner when set (HTTP Idempotency-Key)';
