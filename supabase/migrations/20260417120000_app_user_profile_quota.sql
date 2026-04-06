-- Per-user daily job quota override (§12.0 / §12.3).
-- NULL means "use tier default from server config".
-- Positive integer overrides the tier default for this specific user (e.g. for beta testers or enterprise).

ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS daily_job_quota INTEGER
  CONSTRAINT app_user_profile_daily_job_quota_positive CHECK (daily_job_quota IS NULL OR daily_job_quota > 0);

COMMENT ON COLUMN public.app_user_profile.daily_job_quota IS
  'Per-user daily generation job cap override. NULL = use plan_tier default from server env.';
