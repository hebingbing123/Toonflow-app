-- Outbound webhook configuration audit (Phase 2 Requirement 4.13).
CREATE TABLE IF NOT EXISTS public.app_outbound_webhook_config_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  webhook_id uuid REFERENCES public.app_outbound_webhook (id) ON DELETE SET NULL,
  action text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_outbound_webhook_config_audit_owner_created ON public.app_outbound_webhook_config_audit (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_outbound_webhook_config_audit_webhook_created ON public.app_outbound_webhook_config_audit (webhook_id, created_at DESC)
WHERE
  webhook_id IS NOT NULL;

COMMENT ON TABLE public.app_outbound_webhook_config_audit IS 'User-facing config changes for outbound webhooks (create/patch/delete/test); secrets are never stored in details.';
