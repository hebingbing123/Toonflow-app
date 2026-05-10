ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS notification_preferences_meta JSONB NOT NULL DEFAULT '{}'::jsonb;
