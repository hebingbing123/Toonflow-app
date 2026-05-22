-- Resumable whole-book import sessions (content-hash keyed, per project).

CREATE TABLE IF NOT EXISTS public.app_novel_whole_book_import_session (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  content_hash TEXT NOT NULL,
  source_display_name TEXT NOT NULL DEFAULT '',
  batch_tag TEXT NOT NULL,
  next_list_index INTEGER NOT NULL DEFAULT 0,
  total_chapters INTEGER NOT NULL,
  intake_status TEXT NOT NULL DEFAULT 'admitted',
  intake_source_url TEXT,
  intake_note_base TEXT,
  status TEXT NOT NULL DEFAULT 'in_progress',
  updated_at_ms BIGINT NOT NULL,
  created_at_ms BIGINT NOT NULL,
  CONSTRAINT app_novel_whole_book_import_session_status_chk CHECK (
    status IN ('in_progress', 'completed')
  ),
  CONSTRAINT app_novel_whole_book_import_session_unique_project_hash UNIQUE (project_id, content_hash)
);

CREATE INDEX IF NOT EXISTS idx_app_novel_whole_book_import_session_project_status
ON public.app_novel_whole_book_import_session (project_id, status, updated_at_ms DESC);

ALTER TABLE public.app_novel_whole_book_import_session ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_novel_whole_book_import_session_via_project ON public.app_novel_whole_book_import_session;

CREATE POLICY app_novel_whole_book_import_session_via_project ON public.app_novel_whole_book_import_session FOR ALL TO authenticated USING (
  EXISTS (
    SELECT
      1
    FROM
      public.app_project p
    WHERE
      p.id = app_novel_whole_book_import_session.project_id
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
        p.id = app_novel_whole_book_import_session.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
  )
  );

COMMENT ON TABLE public.app_novel_whole_book_import_session IS 'Client whole-book import progress keyed by decoded text content_hash';
