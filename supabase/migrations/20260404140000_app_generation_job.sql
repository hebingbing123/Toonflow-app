-- Long-running generation tasks (DB source of truth; WS may notify). MVP: insert + list by owner.

CREATE TABLE IF NOT EXISTS public.app_generation_job (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  result JSONB,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_generation_job_status_check CHECK (
    status IN ('queued', 'running', 'succeeded', 'failed')
  )
);

CREATE INDEX IF NOT EXISTS idx_app_generation_job_owner_created ON public.app_generation_job (owner_user_id, created_at DESC);

ALTER TABLE public.app_generation_job ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_generation_job_own ON public.app_generation_job;
CREATE POLICY app_generation_job_own ON public.app_generation_job FOR ALL TO authenticated USING (
  owner_user_id = (SELECT auth.uid ())
)
WITH
  CHECK (owner_user_id = (SELECT auth.uid ()));

COMMENT ON TABLE public.app_generation_job IS 'Async generation jobs; Rust API uses service user via JWT sub';
