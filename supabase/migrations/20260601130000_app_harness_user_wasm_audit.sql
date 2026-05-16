-- Harness user WASM audit events (validate / persist / revoke / invoke + alert signals).
CREATE TABLE IF NOT EXISTS public.app_harness_user_wasm_audit (
  id BIGSERIAL PRIMARY KEY,
  event TEXT NOT NULL,
  user_id UUID NOT NULL,
  workspace_id UUID NULL,
  wasm_id UUID NULL,
  wasm_sha256 TEXT NULL,
  request_id TEXT NULL,
  outcome TEXT NOT NULL DEFAULT 'success',
  error_code TEXT NULL,
  signal_name TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_harness_user_wasm_audit_created
ON public.app_harness_user_wasm_audit (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_harness_user_wasm_audit_signal_created
ON public.app_harness_user_wasm_audit (signal_name, created_at DESC)
WHERE signal_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_app_harness_user_wasm_audit_event_created
ON public.app_harness_user_wasm_audit (event, created_at DESC);
