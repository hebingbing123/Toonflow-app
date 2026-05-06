ALTER TABLE public.app_project
ADD COLUMN IF NOT EXISTS project_brief JSONB,
ADD COLUMN IF NOT EXISTS brand_bible JSONB;

COMMENT ON COLUMN public.app_project.project_brief IS
  'Structured project brief used by onboarding, dashboard readiness, and upstream adaptation guidance.';

COMMENT ON COLUMN public.app_project.brand_bible IS
  'Project-level brand bible basics for tone, motifs, and continuity constraints.';
