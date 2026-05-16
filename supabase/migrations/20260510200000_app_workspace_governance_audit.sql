-- Internal admin: workspace governance audit trail (archive / restore + ops metadata).

CREATE TABLE IF NOT EXISTS public.app_workspace_governance_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  workspace_id UUID NOT NULL REFERENCES public.app_workspace (id) ON DELETE CASCADE,
  event_type TEXT NOT NULL DEFAULT 'governance_updated',
  actor_label TEXT NOT NULL DEFAULT 'internal_ops',
  previous_state JSONB NOT NULL DEFAULT '{}'::jsonb,
  next_state JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_workspace_governance_audit_workspace_created
ON public.app_workspace_governance_audit (workspace_id, created_at DESC);

COMMENT ON TABLE public.app_workspace_governance_audit IS
  'Internal ops workspace governance changes (archive/restore, internal ops notes in JSON state).';
