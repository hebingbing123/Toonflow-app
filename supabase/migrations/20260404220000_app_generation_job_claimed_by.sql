-- Which worker instance claimed a running job (multi-instance observability; FOR UPDATE SKIP LOCKED already coordinates claims).
ALTER TABLE public.app_generation_job
ADD COLUMN IF NOT EXISTS claimed_by TEXT;

COMMENT ON COLUMN public.app_generation_job.claimed_by IS 'Set when status becomes running (WORKER_ID env); retained after terminal states for audit';
