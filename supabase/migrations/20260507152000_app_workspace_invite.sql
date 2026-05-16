CREATE TABLE IF NOT EXISTS public.app_workspace_invite (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  workspace_id UUID NOT NULL REFERENCES public.app_workspace (id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'member',
  invited_by UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  expires_at TIMESTAMPTZ NOT NULL,
  accepted_by UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_workspace_invite_role_check CHECK (role IN ('admin', 'member')),
  CONSTRAINT app_workspace_invite_status_check CHECK (status IN ('pending', 'accepted', 'revoked'))
);

CREATE INDEX IF NOT EXISTS idx_app_workspace_invite_workspace_status
ON public.app_workspace_invite (workspace_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_workspace_invite_email_status
ON public.app_workspace_invite (email, status, created_at DESC);
