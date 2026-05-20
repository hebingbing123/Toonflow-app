-- Per-project novel crawl credentials (encrypted at rest when OPENFLOW_VENDOR_CREDENTIAL_KEY is set).

CREATE TABLE IF NOT EXISTS public.app_project_novel_crawl_auth (
  project_id UUID PRIMARY KEY REFERENCES public.app_project (id) ON DELETE CASCADE,
  auth_mode TEXT NOT NULL DEFAULT 'none',
  cookie_encrypted BYTEA,
  username_encrypted BYTEA,
  password_encrypted BYTEA,
  login_url TEXT,
  login_username_field TEXT NOT NULL DEFAULT 'username',
  login_password_field TEXT NOT NULL DEFAULT 'password',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_project_novel_crawl_auth_mode_check CHECK (
    auth_mode IN ('none', 'cookie', 'password', 'cookie_and_password')
  )
);

CREATE INDEX IF NOT EXISTS idx_app_project_novel_crawl_auth_updated
  ON public.app_project_novel_crawl_auth (updated_at DESC);

ALTER TABLE public.app_project_novel_crawl_auth ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_project_novel_crawl_auth_via_project ON public.app_project_novel_crawl_auth;
CREATE POLICY app_project_novel_crawl_auth_via_project ON public.app_project_novel_crawl_auth
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE p.id = app_project_novel_crawl_auth.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE p.id = app_project_novel_crawl_auth.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
);

COMMENT ON TABLE public.app_project_novel_crawl_auth IS
  'Encrypted novel site crawl auth (cookie and/or form login) scoped per project.';
