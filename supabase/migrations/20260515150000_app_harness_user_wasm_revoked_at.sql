-- WP‑C: soft-revoke stored user WASM (audit retention; hidden from list / cap).

ALTER TABLE public.app_harness_user_wasm
  ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ NULL;

COMMENT ON COLUMN public.app_harness_user_wasm.revoked_at IS 'When set, the module is revoked (omitted from list; does not count toward per-user stored row cap).';

CREATE INDEX IF NOT EXISTS idx_app_harness_user_wasm_owner_active_created ON public.app_harness_user_wasm (
  owner_user_id,
  created_at DESC
)
WHERE
  revoked_at IS NULL;
