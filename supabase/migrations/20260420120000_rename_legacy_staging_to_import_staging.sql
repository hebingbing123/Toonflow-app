-- Rename SQLite import staging schema; refresh promote_import_snapshots to use import_staging.snapshot.

ALTER SCHEMA legacy_staging RENAME TO import_staging;

DROP FUNCTION IF EXISTS public.promote_import_snapshots ();

CREATE OR REPLACE FUNCTION public.promote_import_snapshots ()
RETURNS TABLE (
  projects_upserted bigint,
  scripts_upserted bigint,
  storyboards_upserted bigint,
  novels_upserted bigint,
  assets_upserted bigint,
  script_assets_upserted bigint,
  art_styles_upserted bigint,
  prompts_upserted bigint,
  asset_images_upserted bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$

DECLARE
  p_count bigint;
  s_count bigint;
  b_count bigint;
  n_count bigint;
  a_count bigint;
  sa_count bigint;
  as_count bigint;
  pr_count bigint;
  img_count bigint;
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

  INSERT INTO public.app_storyboard (
    script_id,
    numeric_id,
    numeric_script_id,
    prompt,
    file_path,
    duration,
    state,
    track_id,
    reason,
    track,
    video_desc,
    should_generate_image,
    numeric_project_id,
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
  FROM import_staging.snapshot s
  INNER JOIN public.app_script sc ON sc.numeric_id = NULLIF (s.payload ->> 'scriptId', '')::integer
  WHERE
    s.source_table = 'o_storyboard'
    AND s.payload ? 'id'
  ON CONFLICT (numeric_id) DO UPDATE
  SET
    script_id = EXCLUDED.script_id,
    numeric_script_id = EXCLUDED.numeric_script_id,
    prompt = EXCLUDED.prompt,
    file_path = EXCLUDED.file_path,
    duration = EXCLUDED.duration,
    state = EXCLUDED.state,
    track_id = EXCLUDED.track_id,
    reason = EXCLUDED.reason,
    track = EXCLUDED.track,
    video_desc = EXCLUDED.video_desc,
    should_generate_image = EXCLUDED.should_generate_image,
    numeric_project_id = EXCLUDED.numeric_project_id,
    flow_id = EXCLUDED.flow_id,
    sb_index = EXCLUDED.sb_index,
    create_time_ms = EXCLUDED.create_time_ms,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS b_count = ROW_COUNT;

  INSERT INTO public.app_novel (
    project_id,
    numeric_id,
    chapter_index,
    reel,
    chapter,
    chapter_data,
    event,
    event_state,
    error_reason,
    create_time_ms,
    metadata
  )
  SELECT
    p.id,
    (s.payload ->> 'id')::integer,
    COALESCE(NULLIF (s.payload ->> 'chapterIndex', '')::integer, 0),
    s.payload ->> 'reel',
    COALESCE(s.payload ->> 'chapter', ''),
    COALESCE(s.payload ->> 'chapterData', ''),
    s.payload ->> 'event',
    COALESCE(NULLIF (s.payload ->> 'eventState', '')::integer, 0),
    s.payload ->> 'errorReason',
    NULLIF (s.payload ->> 'createTime', '')::bigint,
    COALESCE(s.payload, '{}'::jsonb)
  FROM import_staging.snapshot s
  INNER JOIN public.app_project p ON p.numeric_id = NULLIF (s.payload ->> 'projectId', '')::integer
  WHERE
    s.source_table = 'o_novel'
    AND s.payload ? 'id'
  ON CONFLICT (numeric_id) DO UPDATE
  SET
    project_id = EXCLUDED.project_id,
    chapter_index = EXCLUDED.chapter_index,
    reel = EXCLUDED.reel,
    chapter = EXCLUDED.chapter,
    chapter_data = EXCLUDED.chapter_data,
    event = EXCLUDED.event,
    event_state = EXCLUDED.event_state,
    error_reason = EXCLUDED.error_reason,
    create_time_ms = EXCLUDED.create_time_ms,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS n_count = ROW_COUNT;

  INSERT INTO public.app_asset (
    project_id,
    numeric_id,
    name,
    asset_type,
    description,
    create_time_ms,
    metadata
  )
  SELECT
    p.id,
    (s.payload ->> 'id')::integer,
    COALESCE(
      NULLIF (trim(COALESCE(s.payload ->> 'name', '')), ''),
      'asset_' || (s.payload ->> 'id')
    ),
    (
      CASE lower(trim(COALESCE(s.payload ->> 'type', '')))
        WHEN 'tool' THEN 'tool'
        WHEN 'scene' THEN 'scene'
        WHEN 'character' THEN 'role'
        WHEN 'prop' THEN 'tool'
        ELSE 'role'
      END
    )::text,
    NULLIF (
      trim(
        COALESCE(
          NULLIF (s.payload ->> 'describe', ''),
          NULLIF (s.payload ->> 'remark', '')
        )
      ),
      ''
    ),
    NULLIF (s.payload ->> 'startTime', '')::bigint,
    COALESCE(s.payload, '{}'::jsonb)
  FROM import_staging.snapshot s
  INNER JOIN public.app_project p ON p.numeric_id = NULLIF (s.payload ->> 'projectId', '')::integer
  WHERE
    s.source_table = 'o_assets'
    AND s.payload ? 'id'
  ON CONFLICT (numeric_id) DO UPDATE
  SET
    project_id = EXCLUDED.project_id,
    name = EXCLUDED.name,
    asset_type = EXCLUDED.asset_type,
    description = EXCLUDED.description,
    create_time_ms = EXCLUDED.create_time_ms,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS a_count = ROW_COUNT;

  INSERT INTO public.app_script_asset (script_id, asset_id)
  SELECT sc.id, a.id
  FROM import_staging.snapshot s
  INNER JOIN public.app_script sc
    ON sc.numeric_id = NULLIF (s.payload ->> 'scriptId', '')::integer
  INNER JOIN public.app_asset a
    ON a.numeric_id = NULLIF (s.payload ->> 'assetId', '')::integer
  WHERE
    s.source_table = 'o_scriptAssets'
    AND s.payload ? 'scriptId'
    AND s.payload ? 'assetId'
    AND sc.project_id = a.project_id
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS sa_count = ROW_COUNT;

  INSERT INTO public.app_art_style (
    owner_user_id,
    numeric_id,
    name,
    file_url,
    label,
    prompt,
    metadata
  )
  SELECT
    map.supabase_user_id,
    (s.payload ->> 'id')::integer,
    COALESCE(
      NULLIF (trim(COALESCE(s.payload ->> 'name', '')), ''),
      'style_' || (s.payload ->> 'id')
    ),
    NULLIF (trim(COALESCE(s.payload ->> 'fileUrl', '')), ''),
    NULLIF (trim(COALESCE(s.payload ->> 'label', '')), ''),
    NULLIF (trim(COALESCE(s.payload ->> 'prompt', '')), ''),
    COALESCE(s.payload, '{}'::jsonb)
  FROM import_staging.snapshot s
  INNER JOIN (
    SELECT m.supabase_user_id
    FROM public.import_user_map m
    ORDER BY m.import_user_id
    LIMIT 1
  ) map ON TRUE
  WHERE
    s.source_table = 'o_artStyle'
    AND s.payload ? 'id'
  ON CONFLICT (numeric_id) DO UPDATE
  SET
    owner_user_id = EXCLUDED.owner_user_id,
    name = EXCLUDED.name,
    file_url = EXCLUDED.file_url,
    label = EXCLUDED.label,
    prompt = EXCLUDED.prompt,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS as_count = ROW_COUNT;

  INSERT INTO public.app_user_prompt (
    owner_user_id,
    numeric_id,
    name,
    kind,
    body
  )
  SELECT
    map.supabase_user_id,
    (s.payload ->> 'id')::smallint,
    NULLIF (trim(COALESCE(s.payload ->> 'name', '')), ''),
    trim(COALESCE(s.payload ->> 'type', '')),
    COALESCE(s.payload ->> 'data', '')
  FROM import_staging.snapshot s
  INNER JOIN (
    SELECT m.supabase_user_id
    FROM public.import_user_map m
    ORDER BY m.import_user_id
    LIMIT 1
  ) map ON TRUE
  WHERE
    s.source_table = 'o_prompt'
    AND s.payload ? 'id'
    AND s.payload ? 'type'
    AND (s.payload ->> 'type') IN (
      'eventExtraction',
      'scriptAssetExtraction',
      'videoPromptGeneration'
    )
    AND (s.payload ->> 'id')::integer BETWEEN 1 AND 32767
    AND length(trim(COALESCE(s.payload ->> 'data', ''))) > 0
  ON CONFLICT (owner_user_id, numeric_id) DO UPDATE
  SET
    name = COALESCE(NULLIF(trim(EXCLUDED.name), ''), public.app_user_prompt.name),
    kind = EXCLUDED.kind,
    body = EXCLUDED.body,
    updated_at = NOW();

  GET DIAGNOSTICS pr_count = ROW_COUNT;

  INSERT INTO public.app_asset_image (
    asset_id,
    sort_index,
    file_path,
    state,
    metadata,
    numeric_image_id
  )
  SELECT
    ranked.asset_id,
    ranked.sort_index,
    ranked.file_path,
    ranked.state,
    ranked.metadata,
    ranked.numeric_image_id
  FROM (
    SELECT
      a.id AS asset_id,
      (ROW_NUMBER() OVER (
        PARTITION BY a.id
        ORDER BY (s.payload ->> 'id')::integer
      ) - 1)::integer AS sort_index,
      NULLIF (trim(COALESCE(s.payload ->> 'filePath', '')), '') AS file_path,
      NULLIF (trim(COALESCE(s.payload ->> 'state', '')), '') AS state,
      COALESCE(
        jsonb_strip_nulls(
          jsonb_build_object(
            'type', NULLIF (trim(COALESCE(s.payload ->> 'type', '')), ''),
            'model', NULLIF (trim(COALESCE(s.payload ->> 'model', '')), ''),
            'resolution', NULLIF (trim(COALESCE(s.payload ->> 'resolution', '')), ''),
            'errorReason', NULLIF (trim(COALESCE(s.payload ->> 'errorReason', '')), '')
          )
        ),
        '{}'::jsonb
      ) AS metadata,
      (s.payload ->> 'id')::integer AS numeric_image_id
    FROM import_staging.snapshot s
    INNER JOIN public.app_asset a
      ON a.numeric_id = NULLIF (s.payload ->> 'assetsId', '')::integer
    WHERE
      s.source_table = 'o_image'
      AND s.payload ? 'id'
      AND s.payload ? 'assetsId'
      AND NULLIF (s.payload ->> 'assetsId', '')::integer IS NOT NULL
  ) ranked
  ON CONFLICT (numeric_image_id) DO UPDATE
  SET
    asset_id = EXCLUDED.asset_id,
    sort_index = EXCLUDED.sort_index,
    file_path = EXCLUDED.file_path,
    state = EXCLUDED.state,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

  GET DIAGNOSTICS img_count = ROW_COUNT;

  RETURN QUERY
  SELECT p_count, s_count, b_count, n_count, a_count, sa_count, as_count, pr_count, img_count;
END;
$$;

REVOKE ALL ON FUNCTION public.promote_import_snapshots () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.promote_import_snapshots () TO service_role;

COMMENT ON FUNCTION public.promote_import_snapshots IS 'Idempotent upsert from import_staging.snapshot into app_* tables; service_role only';
