-- Storyboards + promote function v2 (adds third upsert pass).

CREATE TABLE IF NOT EXISTS public.app_storyboard (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  script_id UUID NOT NULL REFERENCES public.app_script (id) ON DELETE CASCADE,
  legacy_id INTEGER NOT NULL UNIQUE,
  legacy_script_id INTEGER,
  prompt TEXT,
  file_path TEXT,
  duration TEXT,
  state TEXT,
  track_id INTEGER,
  reason TEXT,
  track TEXT,
  video_desc TEXT,
  should_generate_image INTEGER,
  legacy_project_id INTEGER,
  flow_id INTEGER,
  sb_index INTEGER,
  create_time_ms BIGINT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_storyboard_script ON public.app_storyboard (script_id);

ALTER TABLE public.app_storyboard ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_storyboard_via_script ON public.app_storyboard;
CREATE POLICY app_storyboard_via_script ON public.app_storyboard FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_script sc
    JOIN public.app_project p ON p.id = sc.project_id
    WHERE
      sc.id = app_storyboard.script_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_script sc
      JOIN public.app_project p ON p.id = sc.project_id
      WHERE
        sc.id = app_storyboard.script_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

COMMENT ON TABLE public.app_storyboard IS 'Storyboards; promoted from o_storyboard';

DROP FUNCTION IF EXISTS public.promote_legacy_from_staging ();

CREATE OR REPLACE FUNCTION public.promote_legacy_from_staging ()
RETURNS TABLE (
  projects_upserted bigint,
  scripts_upserted bigint,
  storyboards_upserted bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p_count bigint;
  s_count bigint;
  b_count bigint;
BEGIN
  INSERT INTO public.app_project (
    legacy_id,
    name,
    intro,
    project_type,
    image_model,
    image_quality,
    video_model,
    art_style,
    director_manual,
    mode,
    video_ratio,
    legacy_user_id,
    create_time_ms,
    owner_user_id,
    metadata
  )
  SELECT
    (s.payload ->> 'id')::integer,
    s.payload ->> 'name',
    s.payload ->> 'intro',
    s.payload ->> 'projectType',
    s.payload ->> 'imageModel',
    s.payload ->> 'imageQuality',
    s.payload ->> 'videoModel',
    s.payload ->> 'artStyle',
    s.payload ->> 'directorManual',
    s.payload ->> 'mode',
    s.payload ->> 'videoRatio',
    NULLIF (s.payload ->> 'userId', '')::integer,
    NULLIF (s.payload ->> 'createTime', '')::bigint,
    m.supabase_user_id,
    COALESCE(s.payload, '{}'::jsonb)
  FROM legacy_staging.snapshot s
  LEFT JOIN public.legacy_user_map m ON m.legacy_user_id = NULLIF (s.payload ->> 'userId', '')::integer
  WHERE
    s.source_table = 'o_project'
    AND s.payload ? 'id'
  ON CONFLICT (legacy_id) DO UPDATE
  SET
    name = EXCLUDED.name,
    intro = EXCLUDED.intro,
    project_type = EXCLUDED.project_type,
    image_model = EXCLUDED.image_model,
    image_quality = EXCLUDED.image_quality,
    video_model = EXCLUDED.video_model,
    art_style = EXCLUDED.art_style,
    director_manual = EXCLUDED.director_manual,
    mode = EXCLUDED.mode,
    video_ratio = EXCLUDED.video_ratio,
    legacy_user_id = EXCLUDED.legacy_user_id,
    create_time_ms = EXCLUDED.create_time_ms,
    owner_user_id = COALESCE(EXCLUDED.owner_user_id, public.app_project.owner_user_id),
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS p_count = ROW_COUNT;

  INSERT INTO public.app_script (
    project_id,
    legacy_id,
    name,
    content,
    extract_state,
    create_time_ms,
    error_reason,
    legacy_project_id,
    metadata
  )
  SELECT
    p.id,
    (s.payload ->> 'id')::integer,
    s.payload ->> 'name',
    s.payload ->> 'content',
    NULLIF (s.payload ->> 'extractState', '')::integer,
    NULLIF (s.payload ->> 'createTime', '')::bigint,
    s.payload ->> 'errorReason',
    NULLIF (s.payload ->> 'projectId', '')::integer,
    COALESCE(s.payload, '{}'::jsonb)
  FROM legacy_staging.snapshot s
  INNER JOIN public.app_project p ON p.legacy_id = NULLIF (s.payload ->> 'projectId', '')::integer
  WHERE
    s.source_table = 'o_script'
    AND s.payload ? 'id'
  ON CONFLICT (legacy_id) DO UPDATE
  SET
    project_id = EXCLUDED.project_id,
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    extract_state = EXCLUDED.extract_state,
    create_time_ms = EXCLUDED.create_time_ms,
    error_reason = EXCLUDED.error_reason,
    legacy_project_id = EXCLUDED.legacy_project_id,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS s_count = ROW_COUNT;

  INSERT INTO public.app_storyboard (
    script_id,
    legacy_id,
    legacy_script_id,
    prompt,
    file_path,
    duration,
    state,
    track_id,
    reason,
    track,
    video_desc,
    should_generate_image,
    legacy_project_id,
    flow_id,
    sb_index,
    create_time_ms,
    metadata
  )
  SELECT
    sc.id,
    (s.payload ->> 'id')::integer,
    NULLIF (s.payload ->> 'scriptId', '')::integer,
    s.payload ->> 'prompt',
    s.payload ->> 'filePath',
    s.payload ->> 'duration',
    s.payload ->> 'state',
    NULLIF (s.payload ->> 'trackId', '')::integer,
    s.payload ->> 'reason',
    s.payload ->> 'track',
    s.payload ->> 'videoDesc',
    NULLIF (s.payload ->> 'shouldGenerateImage', '')::integer,
    NULLIF (s.payload ->> 'projectId', '')::integer,
    NULLIF (s.payload ->> 'flowId', '')::integer,
    NULLIF (s.payload ->> 'index', '')::integer,
    NULLIF (s.payload ->> 'createTime', '')::bigint,
    COALESCE(s.payload, '{}'::jsonb)
  FROM legacy_staging.snapshot s
  INNER JOIN public.app_script sc ON sc.legacy_id = NULLIF (s.payload ->> 'scriptId', '')::integer
  WHERE
    s.source_table = 'o_storyboard'
    AND s.payload ? 'id'
  ON CONFLICT (legacy_id) DO UPDATE
  SET
    script_id = EXCLUDED.script_id,
    legacy_script_id = EXCLUDED.legacy_script_id,
    prompt = EXCLUDED.prompt,
    file_path = EXCLUDED.file_path,
    duration = EXCLUDED.duration,
    state = EXCLUDED.state,
    track_id = EXCLUDED.track_id,
    reason = EXCLUDED.reason,
    track = EXCLUDED.track,
    video_desc = EXCLUDED.video_desc,
    should_generate_image = EXCLUDED.should_generate_image,
    legacy_project_id = EXCLUDED.legacy_project_id,
    flow_id = EXCLUDED.flow_id,
    sb_index = EXCLUDED.sb_index,
    create_time_ms = EXCLUDED.create_time_ms,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS b_count = ROW_COUNT;

  RETURN QUERY
  SELECT p_count, s_count, b_count;
END;
$$;

REVOKE ALL ON FUNCTION public.promote_legacy_from_staging () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.promote_legacy_from_staging () TO service_role;

COMMENT ON FUNCTION public.promote_legacy_from_staging IS 'Upsert app_project, app_script, app_storyboard from legacy_staging; service_role only';
