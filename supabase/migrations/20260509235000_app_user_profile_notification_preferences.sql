ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS notification_preferences JSONB NOT NULL DEFAULT '{"mutedNotificationTypes":[]}'::jsonb;
