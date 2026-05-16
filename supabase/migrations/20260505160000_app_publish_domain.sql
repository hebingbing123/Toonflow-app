-- Publish domain (short-video-space E1–E3): profiles, drafts, targets, jobs, attempts.
-- Rust API owns HTTP; RLS aligns with project ownership.

CREATE TABLE IF NOT EXISTS public.app_publish_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'default',
  target_market TEXT,
  default_platforms TEXT[],
  title_style TEXT,
  tag_strategy TEXT,
  bio_template TEXT,
  schedule_strategy TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_publish_profile_name_unique UNIQUE (project_id, name)
);

CREATE INDEX IF NOT EXISTS idx_app_publish_profile_project ON public.app_publish_profile (project_id);

CREATE TABLE IF NOT EXISTS public.app_publish_draft (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  profile_id UUID REFERENCES public.app_publish_profile (id) ON DELETE SET NULL,
  script_id UUID REFERENCES public.app_script (id) ON DELETE SET NULL,
  video_asset_key TEXT,
  cover_asset_key TEXT,
  title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  platform_copy JSONB NOT NULL DEFAULT '{}'::jsonb,
  scheduled_at TIMESTAMPTZ,
  draft_status TEXT NOT NULL DEFAULT 'editing',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_publish_draft_status_check CHECK (
    draft_status IN ('editing', 'ready', 'archived')
  )
);

CREATE INDEX IF NOT EXISTS idx_app_publish_draft_project ON public.app_publish_draft (project_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.app_publish_target (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  draft_id UUID NOT NULL REFERENCES public.app_publish_draft (id) ON DELETE CASCADE,
  platform_id TEXT NOT NULL,
  automation_mode TEXT NOT NULL,
  extra JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_publish_target_automation_check CHECK (
    automation_mode IN ('full_auto', 'semi_auto', 'manual_assisted')
  ),
  CONSTRAINT app_publish_target_draft_platform_unique UNIQUE (draft_id, platform_id)
);

CREATE INDEX IF NOT EXISTS idx_app_publish_target_draft ON public.app_publish_target (draft_id);

CREATE TABLE IF NOT EXISTS public.app_publish_job (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  draft_id UUID NOT NULL REFERENCES public.app_publish_draft (id) ON DELETE CASCADE,
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'queued',
  semi_auto_ack_at TIMESTAMPTZ,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  error_message TEXT,
  error_details JSONB,
  claimed_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_publish_job_status_check CHECK (
    status IN (
      'queued',
      'validating',
      'awaiting_confirmation',
      'uploading',
      'platform_processing',
      'succeeded',
      'partial_failed',
      'failed',
      'retrying',
      'cancelled'
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_app_publish_job_owner_created ON public.app_publish_job (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_publish_job_project ON public.app_publish_job (project_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_publish_job_queue ON public.app_publish_job (status, created_at)
WHERE
  status IN ('queued', 'retrying');

CREATE TABLE IF NOT EXISTS public.app_publish_attempt (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  job_id UUID NOT NULL REFERENCES public.app_publish_job (id) ON DELETE CASCADE,
  target_id UUID NOT NULL REFERENCES public.app_publish_target (id) ON DELETE CASCADE,
  attempt_no INT NOT NULL DEFAULT 1,
  status TEXT NOT NULL,
  detail JSONB NOT NULL DEFAULT '{}'::jsonb,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_publish_attempt_job ON public.app_publish_attempt (job_id, created_at);

-- RLS
ALTER TABLE public.app_publish_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_publish_profile_via_project ON public.app_publish_profile;

CREATE POLICY app_publish_profile_via_project ON public.app_publish_profile FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE
      p.id = app_publish_profile.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_project p
      WHERE
        p.id = app_publish_profile.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

ALTER TABLE public.app_publish_draft ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_publish_draft_via_project ON public.app_publish_draft;

CREATE POLICY app_publish_draft_via_project ON public.app_publish_draft FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE
      p.id = app_publish_draft.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_project p
      WHERE
        p.id = app_publish_draft.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

ALTER TABLE public.app_publish_target ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_publish_target_via_draft ON public.app_publish_target;

CREATE POLICY app_publish_target_via_draft ON public.app_publish_target FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_publish_draft d
    INNER JOIN public.app_project p ON p.id = d.project_id
    WHERE
      d.id = app_publish_target.draft_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_publish_draft d
      INNER JOIN public.app_project p ON p.id = d.project_id
      WHERE
        d.id = app_publish_target.draft_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

ALTER TABLE public.app_publish_job ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_publish_job_own ON public.app_publish_job;

CREATE POLICY app_publish_job_own ON public.app_publish_job FOR ALL TO authenticated USING (
  owner_user_id = (SELECT auth.uid ())
)
WITH
  CHECK (owner_user_id = (SELECT auth.uid ()));

ALTER TABLE public.app_publish_attempt ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_publish_attempt_via_job ON public.app_publish_attempt;

CREATE POLICY app_publish_attempt_via_job ON public.app_publish_attempt FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_publish_job j
    WHERE
      j.id = app_publish_attempt.job_id
      AND j.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_publish_job j
      WHERE
        j.id = app_publish_attempt.job_id
        AND j.owner_user_id = (SELECT auth.uid ())
    )
  );

COMMENT ON TABLE public.app_publish_profile IS 'Per-project publish defaults (distro preferences; E1 / 需求 5.2a)';
COMMENT ON TABLE public.app_publish_draft IS 'Publish draft / 发布单 (E2 / 需求 5.2b)';
COMMENT ON TABLE public.app_publish_target IS 'Per-platform row for a draft (E3)';
COMMENT ON TABLE public.app_publish_job IS 'Publish job queue + state machine (E3/E5)';
COMMENT ON TABLE public.app_publish_attempt IS 'Per-target attempt audit (E3; G 节将扩展回流)';
