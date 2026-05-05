-- J.1: Add input hash cache for publish copy generation
-- Reduces redundant LLM calls by caching publish copy generation results based on input hash.

CREATE TABLE IF NOT EXISTS public.app_publish_copy_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  input_hash TEXT NOT NULL UNIQUE,
  platform_copy_fragment JSONB NOT NULL,
  source TEXT NOT NULL, -- 'llm' or 'fallback'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  use_count INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_app_publish_copy_cache_hash ON public.app_publish_copy_cache (input_hash);
CREATE INDEX IF NOT EXISTS idx_app_publish_copy_cache_last_used ON public.app_publish_copy_cache (last_used_at DESC);

COMMENT ON TABLE public.app_publish_copy_cache IS 'Cache for publish copy generation to reduce redundant LLM calls';
COMMENT ON COLUMN public.app_publish_copy_cache.input_hash IS 'SHA256 hash of input parameters (draft content + targets + style_hint)';
COMMENT ON COLUMN public.app_publish_copy_cache.platform_copy_fragment IS 'Generated platform copy fragment';
COMMENT ON COLUMN public.app_publish_copy_cache.source IS 'Generation source: llm or fallback';
COMMENT ON COLUMN public.app_publish_copy_cache.use_count IS 'Number of times this cached result has been used';
