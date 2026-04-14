-- Video tracks and video generation jobs (历史 **`o_video`**, **`o_videoTrack`**).

-- Video master table
CREATE TABLE IF NOT EXISTS public.app_video (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  legacy_id INTEGER NOT NULL UNIQUE,
  script_id UUID REFERENCES public.app_script (id) ON DELETE SET NULL,
  file_path TEXT,
  state TEXT NOT NULL DEFAULT 'pending',
  error_reason TEXT,
  time INTEGER,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Video track (timeline segment) table
CREATE TABLE IF NOT EXISTS public.app_video_track (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  video_id UUID REFERENCES public.app_video (id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  script_id UUID REFERENCES public.app_script (id) ON DELETE SET NULL,
  legacy_id INTEGER,
  state TEXT,
  reason TEXT,
  prompt TEXT,
  select_video_id INTEGER,
  duration INTEGER,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_app_video_project ON public.app_video (project_id);

CREATE INDEX IF NOT EXISTS idx_app_video_script ON public.app_video (script_id);

CREATE INDEX IF NOT EXISTS idx_app_video_state ON public.app_video (project_id, state);

CREATE INDEX IF NOT EXISTS idx_app_video_track_video ON public.app_video_track (video_id);

CREATE INDEX IF NOT EXISTS idx_app_video_track_project ON public.app_video_track (project_id);

-- RLS on videos
ALTER TABLE public.app_video ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_video_via_project ON public.app_video;

CREATE POLICY app_video_via_project ON public.app_video FOR ALL TO authenticated USING (
  EXISTS (
    SELECT
      1
    FROM
      public.app_project p
    WHERE
      p.id = app_video.project_id
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
        p.id = app_video.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

-- RLS on video tracks
ALTER TABLE public.app_video_track ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_video_track_via_project ON public.app_video_track;

CREATE POLICY app_video_track_via_project ON public.app_video_track FOR ALL TO authenticated USING (
  EXISTS (
    SELECT
      1
    FROM
      public.app_project p
    WHERE
      p.id = app_video_track.project_id
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
        p.id = app_video_track.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

COMMENT ON TABLE public.app_video IS 'Generated videos per project/script; 历史 o_video parity';

COMMENT ON TABLE public.app_video_track IS 'Video timeline segments; 历史 o_videoTrack parity';
