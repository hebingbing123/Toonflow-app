CREATE TABLE IF NOT EXISTS public.app_content_compliance_report (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type text NOT NULL CHECK (
    target_type IN ('project', 'script', 'storyboard', 'asset', 'novel', 'user')
  ),
  target_id uuid NOT NULL,
  workspace_id uuid NULL REFERENCES public.app_workspace(id) ON DELETE SET NULL,
  project_id uuid NULL REFERENCES public.app_project(id) ON DELETE SET NULL,
  category text NOT NULL CHECK (
    category IN ('copyright', 'safety', 'harassment', 'adult', 'violence', 'spam', 'other')
  ),
  severity text NOT NULL CHECK (
    severity IN ('low', 'medium', 'high', 'critical')
  ) DEFAULT 'medium',
  status text NOT NULL CHECK (
    status IN ('pending', 'claimed', 'resolved', 'dismissed')
  ) DEFAULT 'pending',
  detail text NULL,
  snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  claimed_by_label text NULL,
  claimed_at timestamptz NULL,
  resolution_label text NULL,
  resolution_note text NULL,
  resolved_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_content_compliance_report_status_created
  ON public.app_content_compliance_report(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_content_compliance_report_workspace_status
  ON public.app_content_compliance_report(workspace_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_content_compliance_report_project_status
  ON public.app_content_compliance_report(project_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_content_compliance_report_reporter
  ON public.app_content_compliance_report(reporter_user_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.set_app_content_compliance_report_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_content_compliance_report_updated_at
  ON public.app_content_compliance_report;

CREATE TRIGGER trg_app_content_compliance_report_updated_at
BEFORE UPDATE ON public.app_content_compliance_report
FOR EACH ROW
EXECUTE FUNCTION public.set_app_content_compliance_report_updated_at();
