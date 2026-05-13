CREATE TABLE IF NOT EXISTS public.app_content_compliance_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.app_content_compliance_report(id) ON DELETE CASCADE,
  actor_user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_label text NOT NULL,
  action text NOT NULL CHECK (
    action IN ('reported', 'claimed', 'resolved', 'dismissed', 'disposition_applied')
  ),
  from_status text NULL CHECK (
    from_status IN ('pending', 'claimed', 'resolved', 'dismissed')
  ),
  to_status text NULL CHECK (
    to_status IN ('pending', 'claimed', 'resolved', 'dismissed')
  ),
  disposition text NULL CHECK (
    disposition IN ('none', 'archive_project', 'suspend_user')
  ),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_content_compliance_audit_report_created
  ON public.app_content_compliance_audit (report_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_content_compliance_audit_actor_created
  ON public.app_content_compliance_audit (actor_user_id, created_at DESC, id DESC);

COMMENT ON TABLE public.app_content_compliance_audit IS
  'Immutable audit trail for content compliance report lifecycle and internal dispositions.';
