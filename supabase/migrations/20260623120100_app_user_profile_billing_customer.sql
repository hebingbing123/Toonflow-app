-- Provider customer id for Stripe Customer Portal / recurring billing.

ALTER TABLE public.app_user_profile
  ADD COLUMN IF NOT EXISTS billing_customer_id TEXT,
  ADD COLUMN IF NOT EXISTS billing_provider TEXT;

CREATE INDEX IF NOT EXISTS idx_app_user_profile_billing_customer
  ON public.app_user_profile (billing_customer_id)
  WHERE billing_customer_id IS NOT NULL;

COMMENT ON COLUMN public.app_user_profile.billing_customer_id IS
  'External billing customer id (e.g. Stripe cus_xxx).';
COMMENT ON COLUMN public.app_user_profile.billing_provider IS
  'Primary self-serve billing provider for this user (stripe, alipay, bitpay).';
