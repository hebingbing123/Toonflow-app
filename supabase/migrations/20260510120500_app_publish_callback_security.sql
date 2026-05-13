-- M.1: Platform callback security validation (signature/timestamp/nonce)

-- Table for tracking nonces to prevent replay attacks
CREATE TABLE IF NOT EXISTS public.app_publish_callback_nonce (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nonce TEXT NOT NULL,
  platform_id TEXT NOT NULL,
  -- Timestamp from the callback request
  callback_timestamp TIMESTAMPTZ NOT NULL,
  -- When this nonce record was created
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Nonces expire after the timestamp validation window
  expires_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT app_publish_callback_nonce_unique UNIQUE (nonce, platform_id)
);

-- Index for efficient nonce lookup during validation
CREATE INDEX IF NOT EXISTS idx_app_publish_callback_nonce_lookup 
  ON public.app_publish_callback_nonce (nonce, platform_id, expires_at);

-- Index for cleanup of expired nonces
CREATE INDEX IF NOT EXISTS idx_app_publish_callback_nonce_cleanup 
  ON public.app_publish_callback_nonce (expires_at);

-- Table for storing platform-specific callback secrets
CREATE TABLE IF NOT EXISTS public.app_publish_platform_secret (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_id TEXT NOT NULL UNIQUE,
  -- HMAC-SHA256 secret key for signature validation
  secret_key TEXT NOT NULL,
  -- Whether this secret is currently active
  is_active BOOLEAN NOT NULL DEFAULT true,
  -- Optional: key rotation support
  rotated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_publish_platform_secret_active 
  ON public.app_publish_platform_secret (platform_id, is_active)
  WHERE is_active = true;

-- Table for callback audit log (security events)
CREATE TABLE IF NOT EXISTS public.app_publish_callback_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_id TEXT NOT NULL,
  callback_id TEXT,
  -- Validation result: valid, invalid_signature, invalid_timestamp, replay_attack, missing_headers
  validation_status TEXT NOT NULL,
  -- Request headers (sanitized)
  request_headers JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- Request body hash for audit
  body_hash TEXT,
  -- Error details if validation failed
  error_details TEXT,
  -- IP address (if available)
  source_ip TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_publish_callback_audit_platform 
  ON public.app_publish_callback_audit (platform_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_publish_callback_audit_status 
  ON public.app_publish_callback_audit (validation_status, created_at DESC);

-- RLS: callback tables are service-level, not user-facing
-- Only backend service should access these tables
ALTER TABLE public.app_publish_callback_nonce ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_publish_platform_secret ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_publish_callback_audit ENABLE ROW LEVEL SECURITY;

-- Service role can access all records
DROP POLICY IF EXISTS app_publish_callback_nonce_service ON public.app_publish_callback_nonce;
CREATE POLICY app_publish_callback_nonce_service ON public.app_publish_callback_nonce
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS app_publish_platform_secret_service ON public.app_publish_platform_secret;
CREATE POLICY app_publish_platform_secret_service ON public.app_publish_platform_secret
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS app_publish_callback_audit_service ON public.app_publish_callback_audit;
CREATE POLICY app_publish_callback_audit_service ON public.app_publish_callback_audit
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Authenticated users cannot access callback security tables
DROP POLICY IF EXISTS app_publish_callback_nonce_no_user ON public.app_publish_callback_nonce;
CREATE POLICY app_publish_callback_nonce_no_user ON public.app_publish_callback_nonce
  FOR ALL TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS app_publish_platform_secret_no_user ON public.app_publish_platform_secret;
CREATE POLICY app_publish_platform_secret_no_user ON public.app_publish_platform_secret
  FOR ALL TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS app_publish_callback_audit_no_user ON public.app_publish_callback_audit;
CREATE POLICY app_publish_callback_audit_no_user ON public.app_publish_callback_audit
  FOR ALL TO authenticated USING (false) WITH CHECK (false);

COMMENT ON TABLE public.app_publish_callback_nonce IS 'Nonce tracking for platform callback replay attack prevention (M.1)';
COMMENT ON TABLE public.app_publish_platform_secret IS 'Platform-specific HMAC secrets for callback signature validation (M.1)';
COMMENT ON TABLE public.app_publish_callback_audit IS 'Security audit log for platform callback validation (M.1)';

-- Function to cleanup expired nonces (should be called periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_callback_nonces()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.app_publish_callback_nonce
  WHERE expires_at <= NOW();
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION cleanup_expired_callback_nonces IS 'Cleanup expired nonces (M.1) - should be called periodically via cron';
