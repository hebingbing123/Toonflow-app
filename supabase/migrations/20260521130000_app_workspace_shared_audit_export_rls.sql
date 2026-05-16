-- Row level security for workspace shared audit export history (PostgREST / authenticated SQL).
-- The API server typically connects with a role that bypasses RLS; policies protect direct DB access.

ALTER TABLE public.app_workspace_shared_audit_export ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_workspace_shared_audit_export_select_member ON public.app_workspace_shared_audit_export;
CREATE POLICY app_workspace_shared_audit_export_select_member ON public.app_workspace_shared_audit_export FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_workspace_member m
    WHERE
      m.workspace_id = app_workspace_shared_audit_export.workspace_id
      AND m.user_id = (SELECT auth.uid ())
  )
);

DROP POLICY IF EXISTS app_workspace_shared_audit_export_insert_self ON public.app_workspace_shared_audit_export;
CREATE POLICY app_workspace_shared_audit_export_insert_self ON public.app_workspace_shared_audit_export FOR INSERT TO authenticated WITH CHECK (
  actor_user_id = (SELECT auth.uid ())
  AND EXISTS (
    SELECT 1
    FROM public.app_workspace_member m
    WHERE
      m.workspace_id = app_workspace_shared_audit_export.workspace_id
      AND m.user_id = (SELECT auth.uid ())
  )
);

COMMENT ON POLICY app_workspace_shared_audit_export_select_member ON public.app_workspace_shared_audit_export IS
  'Workspace members may read export history for workspaces they belong to.';

COMMENT ON POLICY app_workspace_shared_audit_export_insert_self ON public.app_workspace_shared_audit_export IS
  'Members may insert rows only as themselves for workspaces they belong to.';
