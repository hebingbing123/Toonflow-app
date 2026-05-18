-- User-scoped API keys for external automation / integrations.

CREATE TABLE IF NOT EXISTS public.app_api_key (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  public_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  scope TEXT NOT NULL CHECK (scope IN ('read_only', 'read_write')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
  secret_hash TEXT NOT NULL,
  key_hint TEXT NOT NULL,
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  rotated_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ,
  last_used_path TEXT,
  last_used_method TEXT,
  last_used_ip TEXT,
  last_used_user_agent TEXT,
  use_count BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (public_id)
);

CREATE INDEX IF NOT EXISTS idx_app_api_key_owner_created
  ON public.app_api_key (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_api_key_owner_status
  ON public.app_api_key (owner_user_id, status, created_at DESC);

ALTER TABLE public.app_api_key ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_api_key_owner ON public.app_api_key;

CREATE POLICY app_api_key_owner
ON public.app_api_key
FOR ALL
TO authenticated
USING (owner_user_id = (SELECT auth.uid()))
WITH CHECK (owner_user_id = (SELECT auth.uid()));

CREATE TABLE IF NOT EXISTS public.app_api_key_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  api_key_id UUID NOT NULL REFERENCES public.app_api_key (id) ON DELETE CASCADE,
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  actor_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('created', 'rotated', 'revoked', 'activated', 'deleted')),
  event_summary TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_api_key_audit_owner_created
  ON public.app_api_key_audit (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_api_key_audit_key_created
  ON public.app_api_key_audit (api_key_id, created_at DESC);

ALTER TABLE public.app_api_key_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_api_key_audit_owner ON public.app_api_key_audit;

CREATE POLICY app_api_key_audit_owner
ON public.app_api_key_audit
FOR ALL
TO authenticated
USING (owner_user_id = (SELECT auth.uid()))
WITH CHECK (owner_user_id = (SELECT auth.uid()));

COMMENT ON TABLE public.app_api_key IS 'User-scoped API keys for OpenFlow REST integrations; secret plaintext is shown only once and stored as HMAC hash.';
COMMENT ON TABLE public.app_api_key_audit IS 'Management audit trail for API key lifecycle events.';
