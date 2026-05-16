CREATE TABLE IF NOT EXISTS public.app_workspace_audit (
  id BIGSERIAL PRIMARY KEY,
  workspace_id UUID NOT NULL REFERENCES public.app_workspace (id) ON DELETE CASCADE,
  actor_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  target_user_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_workspace_audit_workspace_created
ON public.app_workspace_audit (workspace_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_workspace_audit_actor_created
ON public.app_workspace_audit (actor_user_id, created_at DESC, id DESC);
