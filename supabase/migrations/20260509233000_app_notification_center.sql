CREATE TABLE IF NOT EXISTS public.app_notification (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  workspace_id UUID NULL,
  project_id UUID NULL,
  project_numeric_id INTEGER NULL,
  job_id UUID NULL,
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  link_path TEXT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  file_path TEXT NULL,
  changed_at TIMESTAMPTZ NULL,
  read_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_notification_user_created
ON public.app_notification (user_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_notification_user_read
ON public.app_notification (user_id, read_at, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_notification_user_type
ON public.app_notification (user_id, notification_type, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_notification_workspace
ON public.app_notification (workspace_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_notification_project
ON public.app_notification (project_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_notification_job
ON public.app_notification (job_id, created_at DESC, id DESC);
