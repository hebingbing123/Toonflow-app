-- Platform / internal-ops: soft-archive projects without deleting rows.

ALTER TABLE public.app_project
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_app_project_archived_at
ON public.app_project (archived_at)
WHERE archived_at IS NOT NULL;

COMMENT ON COLUMN public.app_project.archived_at IS
  'NULL = active; set by internal admin governance to hide project from member APIs and block mutations.';
