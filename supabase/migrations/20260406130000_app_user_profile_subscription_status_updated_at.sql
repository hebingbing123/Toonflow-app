-- Preserve subscription status ordering by provider event time.
ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS subscription_status_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN public.app_user_profile.subscription_status_updated_at IS
  'Provider event timestamp used to guard subscription_status updates from out-of-order webhooks.';
