-- WP‑C: persisted user WASM upload stubs (**Postgres BYTEA**, per owner; Harness HTTP).
CREATE TABLE IF NOT EXISTS public.app_harness_user_wasm (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  wasm_sha256 BYTEA NOT NULL,
  wasm_bytes BYTEA NOT NULL,
  size_bytes BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
  CONSTRAINT app_harness_user_wasm_size_chk CHECK (
    size_bytes >= 1
    AND size_bytes = octet_length (wasm_bytes)
  ),
  CONSTRAINT app_harness_user_wasm_sha_len_chk CHECK (octet_length (wasm_sha256) = 32)
);

CREATE INDEX IF NOT EXISTS idx_app_harness_user_wasm_owner_created ON public.app_harness_user_wasm (
  owner_user_id,
  created_at DESC
);

COMMENT ON TABLE public.app_harness_user_wasm IS 'Harness WP‑C: persisted user WASM modules (**stub** row per upload; `wasm_bytes` for future execution paths)';

ALTER TABLE public.app_harness_user_wasm ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_harness_user_wasm_own ON public.app_harness_user_wasm;

CREATE POLICY app_harness_user_wasm_own ON public.app_harness_user_wasm FOR ALL TO authenticated USING (owner_user_id = (SELECT auth.uid ()))
WITH
  CHECK (owner_user_id = (SELECT auth.uid ()));
