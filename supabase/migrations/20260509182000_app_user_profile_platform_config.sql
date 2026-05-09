ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS platform_config JSONB DEFAULT NULL;

COMMENT ON COLUMN public.app_user_profile.platform_config IS
  'User-scoped platform configuration / feature flags for shell surfaces and ops UX.';
