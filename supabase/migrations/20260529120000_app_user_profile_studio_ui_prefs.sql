-- Studio UI preferences (pinned projects, etc.) per user profile.
ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS studio_ui_prefs JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.app_user_profile.studio_ui_prefs IS
  'Per-user Studio shell UI prefs (e.g. pinned_project_ids UUID strings).';
