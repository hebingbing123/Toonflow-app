-- Billing webhook observability: mark informational (non-state-transition) events.
ALTER TABLE public.app_billing_webhook_event
ADD COLUMN IF NOT EXISTS is_informational_event BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.app_billing_webhook_event.is_informational_event IS
  'True when webhook event type is in provider informational whitelist (no subscription state transition).';
