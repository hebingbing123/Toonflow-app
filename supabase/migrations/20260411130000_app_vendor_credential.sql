-- Encrypted vendor API keys (secure credential storage).
-- NOTE: This is a framework; actual encryption requires KMS/Vault integration.

CREATE TABLE IF NOT EXISTS public.app_vendor_credential (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  vendor_id TEXT NOT NULL,
  -- Encrypted credential fields (encrypted at application layer before storage)
  api_key_encrypted BYTEA,
  api_secret_encrypted BYTEA,
  api_token_encrypted BYTEA,
  -- Non-sensitive metadata (plaintext)
  key_hint TEXT, -- Last 4 chars of key for identification, e.g., "...sk-1234"
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (owner_user_id, vendor_id)
);

CREATE INDEX IF NOT EXISTS idx_app_vendor_credential_user ON public.app_vendor_credential (owner_user_id);

CREATE INDEX IF NOT EXISTS idx_app_vendor_credential_vendor ON public.app_vendor_credential (owner_user_id, vendor_id);

ALTER TABLE public.app_vendor_credential ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_vendor_credential_owner ON public.app_vendor_credential;

CREATE POLICY app_vendor_credential_owner ON public.app_vendor_credential FOR ALL TO authenticated USING (
  owner_user_id = (SELECT auth.uid ())
)
WITH
  CHECK (
    owner_user_id = (SELECT auth.uid ())
  );

COMMENT ON TABLE public.app_vendor_credential IS 'Encrypted vendor API credentials per user; encryption at application layer pending KMS/Vault';
