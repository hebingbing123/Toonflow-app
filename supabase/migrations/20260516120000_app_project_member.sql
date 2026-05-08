CREATE TABLE IF NOT EXISTS public.app_project_member (
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (project_id, user_id),
  CONSTRAINT app_project_member_role_check CHECK (role IN ('editor', 'viewer'))
);

CREATE INDEX IF NOT EXISTS idx_app_project_member_user
ON public.app_project_member (user_id, project_id);

COMMENT ON TABLE public.app_project_member IS 'Optional per-project ACL rows for workspace members; editor can mutate, viewer is read-only.';
