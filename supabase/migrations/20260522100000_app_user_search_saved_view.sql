-- Server-side persisted global search saved views (cross-device sync); complements local SharedPreferences cache.

CREATE TABLE IF NOT EXISTS public.app_user_search_saved_view (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  client_view_id text NOT NULL,
  workspace_id uuid REFERENCES public.app_workspace (id) ON DELETE SET NULL,
  title text NOT NULL,
  query text NOT NULL DEFAULT '',
  workspace_name text NULL,
  pinned boolean NOT NULL DEFAULT false,
  result_types jsonb NOT NULL DEFAULT '[]'::jsonb,
  time_from timestamptz NULL,
  time_to timestamptz NULL,
  use_count integer NOT NULL DEFAULT 0,
  last_used_at timestamptz NULL,
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT app_user_search_saved_view_owner_client UNIQUE (owner_user_id, client_view_id),
  CONSTRAINT app_user_search_saved_view_client_len CHECK (char_length(client_view_id) <= 128),
  CONSTRAINT app_user_search_saved_view_title_len CHECK (char_length(title) <= 200),
  CONSTRAINT app_user_search_saved_view_query_len CHECK (char_length(query) <= 2000)
);

CREATE INDEX IF NOT EXISTS idx_app_user_search_saved_view_owner_updated
ON public.app_user_search_saved_view (owner_user_id, updated_at DESC);

COMMENT ON TABLE public.app_user_search_saved_view IS
  'User-owned saved global search views for cross-device sync (GET/PUT /api/v1/search/saved-views).';

ALTER TABLE public.app_user_search_saved_view ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_user_search_saved_view_own ON public.app_user_search_saved_view;
CREATE POLICY app_user_search_saved_view_own ON public.app_user_search_saved_view FOR ALL TO authenticated USING (
  owner_user_id = (SELECT auth.uid ())
)
WITH CHECK (
  owner_user_id = (SELECT auth.uid ())
);
