-- HEALTH-002–005: RLS for user-facing tables (project health check remediation).
-- Backend uses DATABASE_URL (postgres/service_role) and is unaffected; protects PostgREST + authenticated.

-- app_user_profile (HEALTH-002)
ALTER TABLE public.app_user_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_user_profile_self ON public.app_user_profile;
CREATE POLICY app_user_profile_self ON public.app_user_profile
  FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- app_notification (HEALTH-003): read/mark-read by owner; inserts via backend only
ALTER TABLE public.app_notification ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_notification_owner_select ON public.app_notification;
CREATE POLICY app_notification_owner_select ON public.app_notification
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS app_notification_owner_update ON public.app_notification;
CREATE POLICY app_notification_owner_update ON public.app_notification
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- app_project_member (HEALTH-004): workspace members via project scope
ALTER TABLE public.app_project_member ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_project_member_via_workspace ON public.app_project_member;
CREATE POLICY app_project_member_via_workspace ON public.app_project_member
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.app_project p
      INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
      WHERE p.id = app_project_member.project_id
        AND m.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_project p
      INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
      WHERE p.id = app_project_member.project_id
        AND m.user_id = (SELECT auth.uid())
    )
  );

-- app_workspace_invite (HEALTH-005)
ALTER TABLE public.app_workspace_invite ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_workspace_invite_admin ON public.app_workspace_invite;
CREATE POLICY app_workspace_invite_admin ON public.app_workspace_invite
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.app_workspace_member m
      WHERE m.workspace_id = app_workspace_invite.workspace_id
        AND m.user_id = (SELECT auth.uid())
        AND m.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_workspace_member m
      WHERE m.workspace_id = app_workspace_invite.workspace_id
        AND m.user_id = (SELECT auth.uid())
        AND m.role = 'admin'
    )
  );

DROP POLICY IF EXISTS app_workspace_invite_invitee_read ON public.app_workspace_invite;
CREATE POLICY app_workspace_invite_invitee_read ON public.app_workspace_invite
  FOR SELECT TO authenticated
  USING (
    status = 'pending'
    AND lower(email) = lower(COALESCE((SELECT auth.jwt () ->> 'email'), ''))
  );

COMMENT ON POLICY app_user_profile_self ON public.app_user_profile IS 'HEALTH-002: owner-only profile';
COMMENT ON POLICY app_notification_owner_select ON public.app_notification IS 'HEALTH-003: owner read';
COMMENT ON POLICY app_project_member_via_workspace ON public.app_project_member IS 'HEALTH-004: workspace member via project';
COMMENT ON POLICY app_workspace_invite_admin ON public.app_workspace_invite IS 'HEALTH-005: workspace admin manages invites';
