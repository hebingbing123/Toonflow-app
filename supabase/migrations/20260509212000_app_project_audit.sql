CREATE TABLE IF NOT EXISTS public.app_project_audit (
  id BIGSERIAL PRIMARY KEY,
  project_id UUID NOT NULL,
  workspace_id UUID NOT NULL,
  project_numeric_id INTEGER,
  actor_user_id UUID NOT NULL,
  action TEXT NOT NULL,
  target_user_id UUID,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_project_audit_project_created_at
  ON public.app_project_audit (project_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_project_audit_workspace_created_at
  ON public.app_project_audit (workspace_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_project_audit_actor_created_at
  ON public.app_project_audit (actor_user_id, created_at DESC, id DESC);
