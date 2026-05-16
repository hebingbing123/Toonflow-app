ALTER TABLE public.app_workspace
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_app_workspace_archived
ON public.app_workspace (archived_at)
WHERE archived_at IS NOT NULL;

COMMENT ON COLUMN public.app_workspace.archived_at IS 'Enterprise workspace archive timestamp; NULL = active. Personal workspaces stay NULL.';
