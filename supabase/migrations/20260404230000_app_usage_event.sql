-- Fair-use / metering append log (plan §12.3). Server inserts; users may read own rows via RLS.
CREATE TABLE IF NOT EXISTS public.app_usage_event (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  source_job_id UUID,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW ()
);

CREATE INDEX IF NOT EXISTS idx_app_usage_event_user_created ON public.app_usage_event (user_id, created_at DESC);

COMMENT ON TABLE public.app_usage_event IS 'Append-only usage events (e.g. generation_job.succeeded); backend is source of truth';

ALTER TABLE public.app_usage_event ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_usage_event_own_select ON public.app_usage_event;
CREATE POLICY app_usage_event_own_select ON public.app_usage_event FOR SELECT TO authenticated USING (
  user_id = (SELECT auth.uid ())
);
