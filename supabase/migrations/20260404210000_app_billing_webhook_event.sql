-- Billing provider webhooks: idempotent ingest (§12 / §13). Server-only; not for PostgREST clients.
CREATE TABLE IF NOT EXISTS public.app_billing_webhook_event (
  id BIGSERIAL PRIMARY KEY,
  provider_event_id TEXT NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
  CONSTRAINT app_billing_webhook_event_provider_event_id_key UNIQUE (provider_event_id)
);

CREATE INDEX IF NOT EXISTS idx_app_billing_webhook_event_created ON public.app_billing_webhook_event (created_at DESC);

COMMENT ON TABLE public.app_billing_webhook_event IS 'Signed billing webhooks; dedupe by provider_event_id (JSON body id)';
