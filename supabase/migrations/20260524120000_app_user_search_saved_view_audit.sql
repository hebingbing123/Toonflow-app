-- Audit trail for saved-search view sync (full PUT replace); Requirement 3.12.
CREATE TABLE IF NOT EXISTS public.app_user_search_saved_view_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  action text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_user_search_saved_view_audit_owner_created ON public.app_user_search_saved_view_audit (owner_user_id, created_at DESC);

COMMENT ON TABLE public.app_user_search_saved_view_audit IS 'Logged on successful PUT /api/v1/search/saved-views (bulk sync); details omit query/title bodies.';
