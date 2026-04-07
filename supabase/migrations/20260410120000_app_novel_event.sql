-- Novel events and event-chapter relationships (legacy **`o_event`** and **`o_eventChapter`**).

-- Event master table
CREATE TABLE IF NOT EXISTS public.app_novel_event (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  legacy_id INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL DEFAULT '',
  detail TEXT NOT NULL DEFAULT '',
  create_time_ms BIGINT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Junction table: events <-> novels (many-to-many)
CREATE TABLE IF NOT EXISTS public.app_novel_event_chapter (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  event_id UUID NOT NULL REFERENCES public.app_novel_event (id) ON DELETE CASCADE,
  novel_id UUID NOT NULL REFERENCES public.app_novel (id) ON DELETE CASCADE,
  legacy_id INTEGER,
  UNIQUE (event_id, novel_id)
);

-- Indexes for event queries
CREATE INDEX IF NOT EXISTS idx_app_novel_event_project ON public.app_novel_event (project_id);

CREATE INDEX IF NOT EXISTS idx_app_novel_event_name ON public.app_novel_event (project_id, name);

-- Index for junction lookups
CREATE INDEX IF NOT EXISTS idx_app_novel_event_chapter_event ON public.app_novel_event_chapter (event_id);

CREATE INDEX IF NOT EXISTS idx_app_novel_event_chapter_novel ON public.app_novel_event_chapter (novel_id);

-- RLS on events
ALTER TABLE public.app_novel_event ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_novel_event_via_project ON public.app_novel_event;

CREATE POLICY app_novel_event_via_project ON public.app_novel_event FOR ALL TO authenticated USING (
  EXISTS (
    SELECT
      1
    FROM
      public.app_project p
    WHERE
      p.id = app_novel_event.project_id
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
        p.id = app_novel_event.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

-- RLS on junction table (cascade through event or novel, both enforce project ownership)
ALTER TABLE public.app_novel_event_chapter ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_novel_event_chapter_via_event ON public.app_novel_event_chapter;

CREATE POLICY app_novel_event_chapter_via_event ON public.app_novel_event_chapter FOR ALL TO authenticated USING (
  EXISTS (
    SELECT
      1
    FROM
      public.app_novel_event e
      INNER JOIN public.app_project p ON p.id = e.project_id
    WHERE
      e.id = app_novel_event_chapter.event_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT
        1
      FROM
        public.app_novel_event e
        INNER JOIN public.app_project p ON p.id = e.project_id
      WHERE
        e.id = app_novel_event_chapter.event_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

COMMENT ON TABLE public.app_novel_event IS 'Novel events (outline items) per project; legacy o_event parity';

COMMENT ON TABLE public.app_novel_event_chapter IS 'Junction: events <-> novel chapters; legacy o_eventChapter parity';
