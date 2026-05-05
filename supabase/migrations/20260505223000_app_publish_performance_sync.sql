-- G5 foundation: publish performance snapshots + sync cursor/retry state.

CREATE TABLE IF NOT EXISTS public.app_publish_performance_snapshot (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  draft_id UUID REFERENCES public.app_publish_draft (id) ON DELETE SET NULL,
  target_id UUID REFERENCES public.app_publish_target (id) ON DELETE SET NULL,
  platform_id TEXT NOT NULL,
  external_video_id TEXT,
  metric_window TEXT NOT NULL DEFAULT 'lifetime',
  views BIGINT,
  likes BIGINT,
  comments BIGINT,
  shares BIGINT,
  completion_rate NUMERIC(6, 3),
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_publish_perf_project_time ON public.app_publish_performance_snapshot (project_id, synced_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_publish_perf_target_time ON public.app_publish_performance_snapshot (target_id, synced_at DESC);

CREATE TABLE IF NOT EXISTS public.app_publish_metric_sync_cursor (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  target_id UUID NOT NULL REFERENCES public.app_publish_target (id) ON DELETE CASCADE,
  platform_id TEXT NOT NULL,
  cursor_token TEXT,
  status TEXT NOT NULL DEFAULT 'idle',
  retry_count INT NOT NULL DEFAULT 0,
  next_retry_at TIMESTAMPTZ,
  last_error TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  last_synced_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_publish_metric_sync_cursor_status_check CHECK (
    status IN ('idle', 'running', 'failed', 'retrying')
  ),
  CONSTRAINT app_publish_metric_sync_cursor_unique UNIQUE (project_id, target_id)
);

CREATE INDEX IF NOT EXISTS idx_app_publish_metric_sync_retry ON public.app_publish_metric_sync_cursor (status, next_retry_at);

-- RLS
ALTER TABLE public.app_publish_performance_snapshot ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_publish_perf_via_project ON public.app_publish_performance_snapshot;
CREATE POLICY app_publish_perf_via_project ON public.app_publish_performance_snapshot FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE p.id = app_publish_performance_snapshot.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
) WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE p.id = app_publish_performance_snapshot.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
);

ALTER TABLE public.app_publish_metric_sync_cursor ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_publish_metric_cursor_via_project ON public.app_publish_metric_sync_cursor;
CREATE POLICY app_publish_metric_cursor_via_project ON public.app_publish_metric_sync_cursor FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE p.id = app_publish_metric_sync_cursor.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
) WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE p.id = app_publish_metric_sync_cursor.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
);

COMMENT ON TABLE public.app_publish_performance_snapshot IS 'Per-target platform performance snapshots for publish analytics (G5).';
COMMENT ON TABLE public.app_publish_metric_sync_cursor IS 'Per-target sync cursor/retry state for platform metrics pulling (G5).';
