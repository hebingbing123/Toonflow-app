-- NLE M4a: timeline revision history + optimistic revision counter.

ALTER TABLE public.app_project_timeline
  ADD COLUMN IF NOT EXISTS revision INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.app_project_timeline.revision IS 'Monotonic revision; incremented on each successful PUT/restore';

CREATE TABLE IF NOT EXISTS public.app_project_timeline_revision (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  revision INT NOT NULL,
  timeline_json JSONB NOT NULL,
  schema_version INT NOT NULL,
  created_by UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_project_timeline_revision_project_revision_unique UNIQUE (project_id, revision)
);

CREATE INDEX IF NOT EXISTS idx_app_project_timeline_revision_project_rev_desc ON public.app_project_timeline_revision (project_id, revision DESC);

COMMENT ON TABLE public.app_project_timeline_revision IS 'Snapshot history for short-video NLE timeline (last 20 per project)';

ALTER TABLE public.app_project_timeline_revision ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_project_timeline_revision_via_project ON public.app_project_timeline_revision;

CREATE POLICY app_project_timeline_revision_via_project ON public.app_project_timeline_revision FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_project_timeline_revision.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_project_timeline_revision.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
);
