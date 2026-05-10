-- Create search logs table for performance monitoring and analytics
-- This table records all search requests with response times for monitoring and analysis
-- Requirements: 7.6, 9.5, 12.1

CREATE TABLE IF NOT EXISTS public.app_search_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES public.app_workspace(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  result_count INTEGER NOT NULL DEFAULT 0,
  response_time_ms INTEGER NOT NULL,
  filters JSONB,
  is_slow_query BOOLEAN GENERATED ALWAYS AS (response_time_ms > 1000) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Query length constraint: 2-200 characters
  CONSTRAINT app_search_log_query_length CHECK (char_length(query) >= 2 AND char_length(query) <= 200),
  -- Response time must be non-negative
  CONSTRAINT app_search_log_response_time_positive CHECK (response_time_ms >= 0)
);

-- Index for slow query monitoring (queries > 1 second)
CREATE INDEX IF NOT EXISTS idx_app_search_log_slow_queries 
ON public.app_search_log(created_at DESC) 
WHERE is_slow_query = true;

-- Index for user-specific search analytics
CREATE INDEX IF NOT EXISTS idx_app_search_log_user 
ON public.app_search_log(user_id, created_at DESC);

-- Index for workspace-specific search analytics
CREATE INDEX IF NOT EXISTS idx_app_search_log_workspace 
ON public.app_search_log(workspace_id, created_at DESC);

-- Index for time-based queries (for analytics dashboards)
CREATE INDEX IF NOT EXISTS idx_app_search_log_created_at 
ON public.app_search_log(created_at DESC);

-- Index for query frequency analysis
CREATE INDEX IF NOT EXISTS idx_app_search_log_query 
ON public.app_search_log(query, created_at DESC);

-- Enable Row Level Security (admin-only access for analytics)
ALTER TABLE public.app_search_log ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only service role can access search logs (for analytics/monitoring)
-- Regular users should not see search logs directly
DROP POLICY IF EXISTS app_search_log_service_only ON public.app_search_log;
CREATE POLICY app_search_log_service_only ON public.app_search_log
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Function: Automatically delete search logs older than 180 days
-- Keeps logs for 6 months for analytics and compliance
CREATE OR REPLACE FUNCTION public.cleanup_old_search_logs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.app_search_log
  WHERE created_at < NOW() - INTERVAL '180 days';
END;
$$;

-- Function: Get slow query statistics for monitoring
CREATE OR REPLACE FUNCTION public.get_slow_query_stats(
  p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
  total_slow_queries BIGINT,
  avg_response_time_ms NUMERIC,
  max_response_time_ms INTEGER,
  most_common_slow_query TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*) as total_slow_queries,
    ROUND(AVG(response_time_ms)::numeric, 2) as avg_response_time_ms,
    MAX(response_time_ms) as max_response_time_ms,
    (
      SELECT query 
      FROM public.app_search_log 
      WHERE is_slow_query = true 
        AND created_at >= NOW() - (p_hours || ' hours')::INTERVAL
      GROUP BY query 
      ORDER BY COUNT(*) DESC 
      LIMIT 1
    ) as most_common_slow_query
  FROM public.app_search_log
  WHERE is_slow_query = true
    AND created_at >= NOW() - (p_hours || ' hours')::INTERVAL;
END;
$$;

-- Function: Get search analytics for a time period
CREATE OR REPLACE FUNCTION public.get_search_analytics(
  p_workspace_id UUID DEFAULT NULL,
  p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
  total_searches BIGINT,
  unique_users BIGINT,
  avg_response_time_ms NUMERIC,
  slow_query_rate NUMERIC,
  avg_results_per_search NUMERIC,
  top_queries TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*) as total_searches,
    COUNT(DISTINCT user_id) as unique_users,
    ROUND(AVG(response_time_ms)::numeric, 2) as avg_response_time_ms,
    ROUND((COUNT(*) FILTER (WHERE is_slow_query = true)::numeric / NULLIF(COUNT(*), 0) * 100), 2) as slow_query_rate,
    ROUND(AVG(result_count)::numeric, 2) as avg_results_per_search,
    ARRAY(
      SELECT query 
      FROM public.app_search_log 
      WHERE (p_workspace_id IS NULL OR workspace_id = p_workspace_id)
        AND created_at >= NOW() - (p_hours || ' hours')::INTERVAL
      GROUP BY query 
      ORDER BY COUNT(*) DESC 
      LIMIT 10
    ) as top_queries
  FROM public.app_search_log
  WHERE (p_workspace_id IS NULL OR workspace_id = p_workspace_id)
    AND created_at >= NOW() - (p_hours || ' hours')::INTERVAL;
END;
$$;

-- Comments for documentation
COMMENT ON TABLE public.app_search_log IS 'Search request logs for performance monitoring and analytics; automatically cleaned up after 180 days.';
COMMENT ON COLUMN public.app_search_log.query IS 'Search query string (2-200 characters).';
COMMENT ON COLUMN public.app_search_log.result_count IS 'Number of results returned for this search.';
COMMENT ON COLUMN public.app_search_log.response_time_ms IS 'Search response time in milliseconds.';
COMMENT ON COLUMN public.app_search_log.filters IS 'Applied filters (result_type, time_range, etc.) as JSON.';
COMMENT ON COLUMN public.app_search_log.is_slow_query IS 'Automatically set to true if response_time_ms > 1000 (1 second).';
COMMENT ON FUNCTION public.cleanup_old_search_logs() IS 'Deletes search logs older than 180 days; should be called periodically via cron job.';
COMMENT ON FUNCTION public.get_slow_query_stats(INTEGER) IS 'Returns statistics about slow queries (>1s) for the specified time period.';
COMMENT ON FUNCTION public.get_search_analytics(UUID, INTEGER) IS 'Returns comprehensive search analytics for a workspace and time period.';

