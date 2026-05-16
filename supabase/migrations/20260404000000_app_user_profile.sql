-- SaaS profile baseline (plan §12.0 / §12.3). user_id aligns with auth.users.id on Supabase; no FK so self-hosted Postgres still applies.
CREATE TABLE IF NOT EXISTS public.app_user_profile (
  user_id UUID PRIMARY KEY,
  plan_tier TEXT NOT NULL DEFAULT 'free',
  billing_currency TEXT,
  billing_provider TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.app_user_profile IS 'Per-user plan; JWT sub maps to user_id';
