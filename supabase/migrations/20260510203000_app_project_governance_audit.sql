-- Internal admin: project governance audit trail for workspace reassignment / ACL remediation.

CREATE TABLE IF NOT EXISTS public.app_project_governance_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  event_type TEXT NOT NULL DEFAULT 'governance_updated',
  actor_label TEXT NOT NULL DEFAULT 'internal_ops',
  previous_state JSONB NOT NULL DEFAULT '{}'::jsonb,
  next_state JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_project_governance_audit_project_created
ON public.app_project_governance_audit (project_id, created_at DESC);

COMMENT ON TABLE public.app_project_governance_audit IS
  'Internal ops project governance changes (archive/restore, internal ops notes in JSON state).';
