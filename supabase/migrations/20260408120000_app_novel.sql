-- Novel chapters per project (历史 **`o_novel`**); events / outline links are separate milestones.

CREATE TABLE IF NOT EXISTS public.app_novel (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  legacy_id INTEGER NOT NULL UNIQUE,
  chapter_index INTEGER NOT NULL DEFAULT 0,
  reel TEXT,
  chapter TEXT NOT NULL DEFAULT '',
  chapter_data TEXT NOT NULL DEFAULT '',
  event TEXT,
  event_state INTEGER NOT NULL DEFAULT 0,
  error_reason TEXT,
  create_time_ms BIGINT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_novel_project ON public.app_novel (project_id);

CREATE INDEX IF NOT EXISTS idx_app_novel_project_chapter ON public.app_novel (project_id, chapter_index);

ALTER TABLE public.app_novel ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_novel_via_project ON public.app_novel;

CREATE POLICY app_novel_via_project ON public.app_novel FOR ALL TO authenticated USING (
  EXISTS (
    SELECT
      1
    FROM
      public.app_project p
    WHERE
      p.id = app_novel.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT
        1
      FROM
        public.app_project p
      WHERE
        p.id = app_novel.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

COMMENT ON TABLE public.app_novel IS 'Novel source chapters per project; 历史 o_novel parity (subset without event pipeline)';
