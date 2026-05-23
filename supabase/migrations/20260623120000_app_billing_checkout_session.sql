-- Checkout sessions for self-serve plan purchases (Alipay / Stripe / BitPay).

CREATE TABLE IF NOT EXISTS public.app_billing_checkout_session (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  plan_tier TEXT NOT NULL,
  provider TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CNY',
  amount_cents BIGINT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  provider_trade_no TEXT,
  provider_session_id TEXT,
  pay_url TEXT,
  period_days INT NOT NULL DEFAULT 30,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  expires_at TIMESTAMPTZ NOT NULL,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_billing_checkout_session_status_check
    CHECK (status IN ('pending', 'paid', 'failed', 'expired', 'canceled'))
);

CREATE INDEX IF NOT EXISTS idx_app_billing_checkout_session_user
  ON public.app_billing_checkout_session (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_billing_checkout_session_provider_trade
  ON public.app_billing_checkout_session (provider_trade_no)
  WHERE provider_trade_no IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_billing_checkout_session_provider_session
  ON public.app_billing_checkout_session (provider, provider_session_id)
  WHERE provider_session_id IS NOT NULL;

COMMENT ON TABLE public.app_billing_checkout_session IS
  'Self-serve checkout sessions; provider callbacks resolve plan_tier before profile upsert.';
