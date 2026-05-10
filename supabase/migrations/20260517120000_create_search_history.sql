-- Create search history table for global search feature
-- This table stores user search queries with automatic cleanup and per-user limits

CREATE TABLE IF NOT EXISTS public.app_search_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES public.app_workspace(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  result_count INTEGER NOT NULL DEFAULT 0,
  searched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Query length constraint: 2-200 characters
  CONSTRAINT app_search_history_query_length CHECK (char_length(query) >= 2 AND char_length(query) <= 200)
);

-- Index for user-specific history queries (most recent first)
CREATE INDEX IF NOT EXISTS idx_app_search_history_user 
ON public.app_search_history(user_id, searched_at DESC);

-- Index for workspace-specific history queries (most recent first)
CREATE INDEX IF NOT EXISTS idx_app_search_history_workspace 
ON public.app_search_history(workspace_id, searched_at DESC);

-- Enable Row Level Security
ALTER TABLE public.app_search_history ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only access their own search history
DROP POLICY IF EXISTS app_search_history_own ON public.app_search_history;
CREATE POLICY app_search_history_own ON public.app_search_history
FOR ALL TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

-- Function: Automatically delete search history older than 90 days
CREATE OR REPLACE FUNCTION public.cleanup_old_search_history()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.app_search_history
  WHERE searched_at < NOW() - INTERVAL '90 days';
END;
$$;

-- Function: Limit each user to maximum 50 search history entries
-- Automatically triggered after each insert to maintain the limit
CREATE OR REPLACE FUNCTION public.limit_search_history_per_user()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delete oldest entries beyond the 50 most recent for this user
  DELETE FROM public.app_search_history
  WHERE user_id = NEW.user_id
  AND id NOT IN (
    SELECT id FROM public.app_search_history
    WHERE user_id = NEW.user_id
    ORDER BY searched_at DESC
    LIMIT 50
  );
  RETURN NEW;
END;
$$;

-- Trigger: Enforce 50-entry limit per user after each insert
DROP TRIGGER IF EXISTS trigger_limit_search_history ON public.app_search_history;
CREATE TRIGGER trigger_limit_search_history
AFTER INSERT ON public.app_search_history
FOR EACH ROW
EXECUTE FUNCTION public.limit_search_history_per_user();

-- Comments for documentation
COMMENT ON TABLE public.app_search_history IS 'User search history for global search feature; automatically limited to 50 entries per user and cleaned up after 90 days.';
COMMENT ON COLUMN public.app_search_history.query IS 'Search query string (2-200 characters).';
COMMENT ON COLUMN public.app_search_history.result_count IS 'Number of results returned for this search.';
COMMENT ON COLUMN public.app_search_history.searched_at IS 'Timestamp when the search was performed.';
COMMENT ON FUNCTION public.cleanup_old_search_history() IS 'Deletes search history entries older than 90 days; should be called periodically via cron job.';
COMMENT ON FUNCTION public.limit_search_history_per_user() IS 'Trigger function that maintains maximum 50 search history entries per user.';
