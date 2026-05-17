-- Wave 6 / tech-debt B: durable video prompt cache (metadata cache remains fallback).

CREATE TABLE IF NOT EXISTS public.app_video_prompt_cache (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    script_numeric_id integer NOT NULL,
    storyboard_numeric_id integer NOT NULL,
    input_hash text NOT NULL,
    prompt text NOT NULL,
    negative_prompt text,
    observation_note text,
    model text NOT NULL DEFAULT 'runway-gen-2',
    duration_seconds integer NOT NULL DEFAULT 5,
    use_count integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    last_used_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT app_video_prompt_cache_storyboard_scope UNIQUE (script_numeric_id, storyboard_numeric_id, input_hash)
);

CREATE INDEX IF NOT EXISTS idx_app_video_prompt_cache_hash
    ON public.app_video_prompt_cache (input_hash);

CREATE INDEX IF NOT EXISTS idx_app_video_prompt_cache_last_used
    ON public.app_video_prompt_cache (last_used_at DESC);

COMMENT ON TABLE public.app_video_prompt_cache IS 'Cache for generate-video-prompt to reduce redundant LLM work';
COMMENT ON COLUMN public.app_video_prompt_cache.input_hash IS 'SHA256 of prompt inputs (description, image, memory tier, constraints)';
