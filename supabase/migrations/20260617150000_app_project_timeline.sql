-- NLE M1: project-scoped rough-cut timeline (tracks JSON in Postgres).

CREATE TABLE IF NOT EXISTS public.app_project_timeline (
  project_id UUID PRIMARY KEY REFERENCES public.app_project (id) ON DELETE CASCADE,
  schema_version INT NOT NULL DEFAULT 1,
  timeline_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_project_timeline_updated ON public.app_project_timeline (updated_at DESC);

COMMENT ON TABLE public.app_project_timeline IS 'Short-video NLE rough-cut: video clip trims + optional BGM track';
COMMENT ON COLUMN public.app_project_timeline.timeline_json IS 'Versioned tracks document (schema_version, tracks.video[], tracks.bgm)';

ALTER TABLE public.app_project_timeline ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_project_timeline_via_project ON public.app_project_timeline;

CREATE POLICY app_project_timeline_via_project ON public.app_project_timeline FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_project_timeline.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_project_timeline.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
);
