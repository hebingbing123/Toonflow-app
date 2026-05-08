-- Add short video configuration fields to app_project table
-- Requirements: 需求 2, 14.2 (impl Wave 1 / MP-W2)
-- Task: B1

-- Add new columns for short video configuration
ALTER TABLE public.app_project
  ADD COLUMN IF NOT EXISTS target_market TEXT,
  ADD COLUMN IF NOT EXISTS target_platforms TEXT[], -- Array of platform identifiers
  ADD COLUMN IF NOT EXISTS duration_strategy TEXT,
  ADD COLUMN IF NOT EXISTS voice_profile TEXT,
  ADD COLUMN IF NOT EXISTS subtitle_style TEXT,
  ADD COLUMN IF NOT EXISTS bgm_strategy TEXT;

-- Add comments for documentation
COMMENT ON COLUMN public.app_project.target_market IS 'Target market for short video (e.g., domestic, overseas, both)';
COMMENT ON COLUMN public.app_project.target_platforms IS 'Array of target platforms (e.g., douyin, bilibili, tiktok, youtube_shorts)';
COMMENT ON COLUMN public.app_project.duration_strategy IS 'Duration strategy for short videos (e.g., short, medium, long)';
COMMENT ON COLUMN public.app_project.voice_profile IS 'Voice profile identifier for narration';
COMMENT ON COLUMN public.app_project.subtitle_style IS 'Subtitle style identifier';
COMMENT ON COLUMN public.app_project.bgm_strategy IS 'Background music strategy';

-- Update the promote function to handle new fields from metadata if they exist
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
    numeric_id,
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
    target_market,
    target_platforms,
    duration_strategy,
    voice_profile,
    subtitle_style,
    bgm_strategy,
    import_user_id,
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
    s.payload ->> 'targetMarket',
    CASE 
      WHEN s.payload -> 'targetPlatforms' IS NOT NULL 
      THEN ARRAY(SELECT jsonb_array_elements_text(s.payload -> 'targetPlatforms'))
      ELSE NULL
    END,
    s.payload ->> 'durationStrategy',
    s.payload ->> 'voiceProfile',
    s.payload ->> 'subtitleStyle',
    s.payload ->> 'bgmStrategy',
    NULLIF (s.payload ->> 'userId', '')::integer,
    NULLIF (s.payload ->> 'createTime', '')::bigint,
    m.supabase_user_id,
    COALESCE(s.payload, '{}'::jsonb)
  FROM import_staging.snapshot s
  LEFT JOIN public.import_user_map m ON m.import_user_id = NULLIF (s.payload ->> 'userId', '')::integer
  WHERE
    s.source_table = 'o_project'
    AND s.payload ? 'id'
  ON CONFLICT (numeric_id) DO UPDATE
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
    target_market = EXCLUDED.target_market,
    target_platforms = EXCLUDED.target_platforms,
    duration_strategy = EXCLUDED.duration_strategy,
    voice_profile = EXCLUDED.voice_profile,
    subtitle_style = EXCLUDED.subtitle_style,
    bgm_strategy = EXCLUDED.bgm_strategy,
    import_user_id = EXCLUDED.import_user_id,
    create_time_ms = EXCLUDED.create_time_ms,
    owner_user_id = COALESCE(EXCLUDED.owner_user_id, public.app_project.owner_user_id),
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS p_count = ROW_COUNT;

  INSERT INTO public.app_script (
    project_id,
    numeric_id,
    name,
    content,
    extract_state,
    create_time_ms,
    error_reason,
    numeric_project_id,
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
  FROM import_staging.snapshot s
  INNER JOIN public.app_project p ON p.numeric_id = NULLIF (s.payload ->> 'projectId', '')::integer
  WHERE
    s.source_table = 'o_script'
    AND s.payload ? 'id'
  ON CONFLICT (numeric_id) DO UPDATE
  SET
    project_id = EXCLUDED.project_id,
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    extract_state = EXCLUDED.extract_state,
    create_time_ms = EXCLUDED.create_time_ms,
    error_reason = EXCLUDED.error_reason,
    numeric_project_id = EXCLUDED.numeric_project_id,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS s_count = ROW_COUNT;

  RETURN QUERY
  SELECT p_count, s_count;
END;
$$;

COMMENT ON FUNCTION public.promote_legacy_from_staging IS 'Upsert app_project from o_project snapshots and app_script from o_script; run after import; service_role only';
