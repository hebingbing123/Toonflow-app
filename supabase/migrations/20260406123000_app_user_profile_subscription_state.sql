-- Subscription state fields for SaaS billing state machine baseline (§12 / §13.3).
ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS subscription_status TEXT,
ADD COLUMN IF NOT EXISTS subscription_current_period_end_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'app_user_profile_subscription_status_check'
  ) THEN
    ALTER TABLE public.app_user_profile
    ADD CONSTRAINT app_user_profile_subscription_status_check
      CHECK (
        subscription_status IS NULL OR subscription_status IN (
          'free',
          'trialing',
          'active',
          'past_due',
          'unpaid',
          'canceled',
          'incomplete',
          'incomplete_expired'
        )
      );
  END IF;
END $$;

COMMENT ON COLUMN public.app_user_profile.subscription_status IS
  'Normalized billing subscription state from provider webhooks.';
COMMENT ON COLUMN public.app_user_profile.subscription_current_period_end_at IS
  'Current subscription period end timestamp from provider webhook payload.';
