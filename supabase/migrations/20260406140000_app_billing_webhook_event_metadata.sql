-- Billing webhook metadata for audit/debugging (provider/type/timestamp).
ALTER TABLE public.app_billing_webhook_event
ADD COLUMN IF NOT EXISTS provider TEXT,
ADD COLUMN IF NOT EXISTS raw_event_id TEXT,
ADD COLUMN IF NOT EXISTS event_type TEXT,
ADD COLUMN IF NOT EXISTS event_created_at TIMESTAMPTZ;

COMMENT ON COLUMN public.app_billing_webhook_event.provider IS
  'Normalized provider name (e.g. stripe, alipay) when known.';
COMMENT ON COLUMN public.app_billing_webhook_event.raw_event_id IS
  'Raw provider event id from JSON body (before namespacing).';
COMMENT ON COLUMN public.app_billing_webhook_event.event_type IS
  'Provider event type / topic from webhook payload (best-effort).';
COMMENT ON COLUMN public.app_billing_webhook_event.event_created_at IS
  'Provider event created timestamp from webhook payload (best-effort).';
