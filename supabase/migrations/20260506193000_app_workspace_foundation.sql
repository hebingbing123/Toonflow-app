CREATE TABLE IF NOT EXISTS public.app_workspace (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  workspace_type TEXT NOT NULL DEFAULT 'personal',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_workspace_type_check CHECK (workspace_type IN ('personal', 'enterprise'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_workspace_personal_owner
ON public.app_workspace (owner_user_id)
WHERE workspace_type = 'personal';

CREATE TABLE IF NOT EXISTS public.app_workspace_member (
  workspace_id UUID NOT NULL REFERENCES public.app_workspace (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'owner',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, user_id),
  CONSTRAINT app_workspace_member_role_check CHECK (role IN ('owner', 'admin', 'member'))
);

ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS current_workspace_id UUID REFERENCES public.app_workspace (id) ON DELETE SET NULL;

ALTER TABLE public.app_project
ADD COLUMN IF NOT EXISTS workspace_id UUID REFERENCES public.app_workspace (id) ON DELETE SET NULL;

WITH user_scope AS (
  SELECT DISTINCT p.user_id AS owner_user_id
  FROM (
    SELECT user_id
    FROM public.app_user_profile
    UNION
    SELECT owner_user_id AS user_id
    FROM public.app_project
    WHERE owner_user_id IS NOT NULL
  ) AS p
  WHERE p.user_id IS NOT NULL
)
INSERT INTO public.app_workspace (owner_user_id, name, workspace_type)
SELECT owner_user_id, 'Personal Workspace', 'personal'
FROM user_scope
ON CONFLICT DO NOTHING;

INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
SELECT w.id, w.owner_user_id, 'owner'
FROM public.app_workspace w
WHERE w.workspace_type = 'personal'
ON CONFLICT (workspace_id, user_id) DO NOTHING;

INSERT INTO public.app_user_profile (user_id, current_workspace_id)
SELECT w.owner_user_id, w.id
FROM public.app_workspace w
WHERE w.workspace_type = 'personal'
ON CONFLICT (user_id) DO UPDATE
SET
  current_workspace_id = COALESCE(public.app_user_profile.current_workspace_id, EXCLUDED.current_workspace_id),
  updated_at = NOW();

UPDATE public.app_project p
SET workspace_id = w.id
FROM public.app_workspace w
WHERE
  p.workspace_id IS NULL
  AND p.owner_user_id = w.owner_user_id
  AND w.workspace_type = 'personal';

CREATE INDEX IF NOT EXISTS idx_app_project_workspace
ON public.app_project (workspace_id, create_time_ms DESC);

CREATE INDEX IF NOT EXISTS idx_app_user_profile_current_workspace
ON public.app_user_profile (current_workspace_id);

ALTER TABLE public.app_workspace ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_workspace_member ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_workspace_member_access ON public.app_workspace;
CREATE POLICY app_workspace_member_access ON public.app_workspace FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_workspace_member m
    WHERE
      m.workspace_id = app_workspace.id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_workspace_member m
    WHERE
      m.workspace_id = app_workspace.id
      AND m.user_id = (SELECT auth.uid ())
  )
);

DROP POLICY IF EXISTS app_workspace_member_self ON public.app_workspace_member;
CREATE POLICY app_workspace_member_self ON public.app_workspace_member FOR ALL TO authenticated USING (
  user_id = (SELECT auth.uid ())
)
WITH CHECK (user_id = (SELECT auth.uid ()));

COMMENT ON TABLE public.app_workspace IS 'Workspace root scope; personal workspaces are auto-created per user.';
COMMENT ON TABLE public.app_workspace_member IS 'Workspace membership and role map.';
COMMENT ON COLUMN public.app_user_profile.current_workspace_id IS 'Current workspace context for UI/API bootstrap.';
COMMENT ON COLUMN public.app_project.workspace_id IS 'Workspace scope for the project; owner_user_id remains the current auth gate during workspace migration.';
