-- Normalized app tables (UUID PK, Supabase Auth). 旧版 integer ids kept for idempotent promote.
-- Requires legacy_staging.snapshot populated (e.g. openflow-sqlite-import) and optional legacy_user_map rows.

CREATE TABLE IF NOT EXISTS public.legacy_user_map (
  legacy_user_id INTEGER PRIMARY KEY,
  supabase_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.app_project (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  legacy_id INTEGER NOT NULL UNIQUE,
  name TEXT,
  intro TEXT,
  project_type TEXT,
  image_model TEXT,
  image_quality TEXT,
  video_model TEXT,
  art_style TEXT,
  director_manual TEXT,
  mode TEXT,
  video_ratio TEXT,
  legacy_user_id INTEGER,
  create_time_ms BIGINT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_project_owner ON public.app_project (owner_user_id);

CREATE TABLE IF NOT EXISTS public.app_script (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  legacy_id INTEGER NOT NULL UNIQUE,
  name TEXT,
  content TEXT,
  extract_state INTEGER,
  create_time_ms BIGINT,
  error_reason TEXT,
  legacy_project_id INTEGER,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_script_project ON public.app_script (project_id);

-- RLS
ALTER TABLE public.legacy_user_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_project ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_script ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS legacy_user_map_self ON public.legacy_user_map;
CREATE POLICY legacy_user_map_self ON public.legacy_user_map FOR ALL TO authenticated USING (supabase_user_id = (SELECT auth.uid ()))
WITH
  CHECK (supabase_user_id = (SELECT auth.uid ()));

DROP POLICY IF EXISTS app_project_own ON public.app_project;
CREATE POLICY app_project_own ON public.app_project FOR ALL TO authenticated USING (owner_user_id = (SELECT auth.uid ()))
WITH
  CHECK (owner_user_id = (SELECT auth.uid ()));

DROP POLICY IF EXISTS app_script_via_project ON public.app_script;
CREATE POLICY app_script_via_project ON public.app_script FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE
      p.id = app_script.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_project p
      WHERE
        p.id = app_script.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

COMMENT ON TABLE public.legacy_user_map IS 'Maps old o_user.id (int) to auth.users.id; required for owner_user_id on promote';
COMMENT ON TABLE public.app_project IS 'Projects; promoted from o_project + legacy_staging';
COMMENT ON TABLE public.app_script IS 'Scripts; promoted from o_script; FK to app_project by 历史 project id';

-- Idempotent promote from JSONB snapshots (matches Knex column names in SQLite export).
CREATE OR REPLACE FUNCTION public.promote_legacy_from_staging ()
RETURNS TABLE (
  projects_upserted bigint,
  scripts_upserted bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p_count bigint;
  s_count bigint;
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

  RETURN QUERY
  SELECT p_count, s_count;
END;
$$;

REVOKE ALL ON FUNCTION public.promote_legacy_from_staging () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.promote_legacy_from_staging () TO service_role;

COMMENT ON FUNCTION public.promote_legacy_from_staging IS 'Upsert app_project from o_project snapshots and app_script from o_script; run after 历史 import; service_role only';
