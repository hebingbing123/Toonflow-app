-- Global Search: Add tsvector search indexes to app_project, app_script, app_asset
-- Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6
-- Design: PostgreSQL tsvector + GIN indexes for full-text search with weighted fields

-- Add search_vector column to app_project
-- Weight A (highest) for name, Weight B for intro
ALTER TABLE public.app_project 
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
  setweight(to_tsvector('simple', COALESCE(intro, '')), 'B')
) STORED;

-- Create GIN index on app_project.search_vector for fast full-text search
CREATE INDEX IF NOT EXISTS idx_app_project_search 
ON public.app_project USING GIN(search_vector);

COMMENT ON COLUMN public.app_project.search_vector IS 'Full-text search index: name (weight A) + intro (weight B)';

-- Add search_vector column to app_script
-- Weight A (highest) for name, Weight B for content
ALTER TABLE public.app_script 
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
  setweight(to_tsvector('simple', COALESCE(content, '')), 'B')
) STORED;

-- Create GIN index on app_script.search_vector for fast full-text search
CREATE INDEX IF NOT EXISTS idx_app_script_search 
ON public.app_script USING GIN(search_vector);

COMMENT ON COLUMN public.app_script.search_vector IS 'Full-text search index: name (weight A) + content (weight B)';

-- Add search_vector column to app_asset
-- Weight A (highest) for name, Weight B for description
ALTER TABLE public.app_asset 
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
  setweight(to_tsvector('simple', COALESCE(description, '')), 'B')
) STORED;

-- Create GIN index on app_asset.search_vector for fast full-text search
CREATE INDEX IF NOT EXISTS idx_app_asset_search 
ON public.app_asset USING GIN(search_vector);

COMMENT ON COLUMN public.app_asset.search_vector IS 'Full-text search index: name (weight A) + description (weight B)';

-- Notes:
-- 1. Using 'simple' text search configuration for Chinese + English mixed content
--    (no stemming, preserves original words for better CJK support)
-- 2. GENERATED ALWAYS AS ... STORED automatically maintains the index on INSERT/UPDATE
-- 3. GIN (Generalized Inverted Index) provides fast full-text search queries
-- 4. Weight A (name/title) ranks higher than Weight B (description/content) in ts_rank
-- 5. Search queries should use plainto_tsquery('simple', search_term) for matching
-- 6. Use ts_rank(search_vector, query) for relevance scoring
-- 7. Use ts_headline('simple', content, query) for generating highlighted snippets
