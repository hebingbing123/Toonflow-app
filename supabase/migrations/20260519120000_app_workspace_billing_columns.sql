-- Workspace-scope billing storage (Option A: nullable columns on app_workspace)
-- Related: .kiro/specs/workspace-scope-billing/ (Requirements 1.2, 1.3, 1.4, 8.1)
-- ADR: docs/plans/adr-workspace-billing-storage-model.md
-- Task: 1.1 Create migration: workspace billing storage per ADR

-- Add nullable billing columns to app_workspace table
-- These columns remain NULL until workspace-scope billing is activated
-- NULL semantics: "not applicable" or "use user-scope billing"
-- Non-NULL values indicate workspace-scope billing is active for this workspace

ALTER TABLE public.app_workspace
  ADD COLUMN IF NOT EXISTS plan_tier TEXT,
  ADD COLUMN IF NOT EXISTS billing_currency TEXT,
  ADD COLUMN IF NOT EXISTS billing_provider TEXT,
  ADD COLUMN IF NOT EXISTS billing_customer_id TEXT,
  ADD COLUMN IF NOT EXISTS daily_job_quota INTEGER
    CONSTRAINT app_workspace_daily_job_quota_positive 
    CHECK (daily_job_quota IS NULL OR daily_job_quota > 0);

-- Index for Stripe customer lookups (sparse index for non-NULL values only)
CREATE INDEX IF NOT EXISTS idx_app_workspace_billing_customer
  ON public.app_workspace (billing_customer_id)
  WHERE billing_customer_id IS NOT NULL;

-- Index for billing operations filtering by plan tier
CREATE INDEX IF NOT EXISTS idx_app_workspace_plan_tier
  ON public.app_workspace (plan_tier)
  WHERE plan_tier IS NOT NULL;

-- Comments documenting the nullable semantics and workspace-scope billing model
COMMENT ON COLUMN public.app_workspace.plan_tier IS 
  'Workspace-level plan tier when billing_scope=workspace. NULL = use user-scope billing (app_user_profile.plan_tier). Mirrors app_user_profile.plan_tier structure for workspace-attributed subscriptions.';

COMMENT ON COLUMN public.app_workspace.billing_currency IS 
  'Workspace billing currency (e.g. USD, EUR). NULL = not applicable or use user-scope billing.';

COMMENT ON COLUMN public.app_workspace.billing_provider IS 
  'Workspace billing provider identifier (e.g. stripe, paddle). NULL = not applicable or use user-scope billing.';

COMMENT ON COLUMN public.app_workspace.billing_customer_id IS 
  'External billing provider customer ID for this workspace (e.g. Stripe customer ID). NULL = not applicable or use user-scope billing. Used for webhook reconciliation and subscription management.';

COMMENT ON COLUMN public.app_workspace.daily_job_quota IS 
  'Workspace-level daily job quota override. NULL = use plan_tier default from server config. Positive integer overrides the tier default for this workspace. Mirrors app_user_profile.daily_job_quota structure.';

-- Rollback guidance (for phase 1 additive-only migration):
-- To rollback this migration (before workspace-scope billing is activated):
--   DROP INDEX IF EXISTS public.idx_app_workspace_billing_customer;
--   DROP INDEX IF EXISTS public.idx_app_workspace_plan_tier;
--   ALTER TABLE public.app_workspace DROP COLUMN IF EXISTS daily_job_quota;
--   ALTER TABLE public.app_workspace DROP COLUMN IF EXISTS billing_customer_id;
--   ALTER TABLE public.app_workspace DROP COLUMN IF EXISTS billing_provider;
--   ALTER TABLE public.app_workspace DROP COLUMN IF EXISTS billing_currency;
--   ALTER TABLE public.app_workspace DROP COLUMN IF EXISTS plan_tier;
--
-- WARNING: Do NOT rollback after workspace-scope billing is activated in production
-- and workspace billing data has been populated. Rollback is only safe during
-- the additive schema phase when all columns remain NULL.
--
-- For operational rollback after activation, use the read-path rollback procedure
-- documented in docs/plans/ runbook (disable v2 API + revert to user-scope reads
-- without dropping columns).

