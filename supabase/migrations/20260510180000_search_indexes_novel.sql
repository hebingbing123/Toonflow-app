-- Global search: full-text indexes for novel chapters and novel outline events.

ALTER TABLE public.app_novel
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(
    to_tsvector(
      'simple',
      COALESCE(NULLIF(trim(chapter), ''), '') || ' ' || COALESCE(NULLIF(trim(reel), ''), '')
    ),
    'A'
  )
  || setweight(
    to_tsvector(
      'simple',
      COALESCE(chapter_data, '') || ' ' || COALESCE(event, '') || ' ' || COALESCE(error_reason, '')
    ),
    'B'
  )
) STORED;

CREATE INDEX IF NOT EXISTS idx_app_novel_search
ON public.app_novel USING GIN (search_vector);

COMMENT ON COLUMN public.app_novel.search_vector IS
  'Full-text search: chapter title/reel (A) + body/event/error (B)';

ALTER TABLE public.app_novel_event
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('simple', COALESCE(name, '')), 'A')
  || setweight(to_tsvector('simple', COALESCE(detail, '')), 'B')
) STORED;

CREATE INDEX IF NOT EXISTS idx_app_novel_event_search
ON public.app_novel_event USING GIN (search_vector);

COMMENT ON COLUMN public.app_novel_event.search_vector IS
  'Full-text search: event name (A) + detail (B)';
