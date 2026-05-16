-- LLM token usage log: per-call tracking for cost optimization and quality correlation.
-- Isolation: user_id + project_id + script_id (NULL = no specific scope).
-- Enables automated memory enhancement based on token efficiency vs quality trade-offs.

CREATE TABLE IF NOT EXISTS public.app_llm_usage_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  project_id INTEGER,                 -- optional project scope
  script_id INTEGER,                  -- optional script/episode scope
  job_id UUID REFERENCES app_generation_job(id), -- optional job linkage

  -- Call metadata
  call_type TEXT NOT NULL,            -- e.g. 'chat_completion', 'agent_loop', 'summarize', 'video_prompt'
  model_name TEXT NOT NULL,           -- e.g. 'gpt-4o', 'claude-3-5-sonnet'
  provider TEXT,                      -- e.g. 'openai', 'anthropic'

  -- Token counts (from API response usage field)
  prompt_tokens INTEGER NOT NULL DEFAULT 0,
  completion_tokens INTEGER NOT NULL DEFAULT 0,
  total_tokens INTEGER NOT NULL DEFAULT 0,

  -- Cost estimation (in CNY cents, nullable until rate is known)
  estimated_cost_cents INTEGER,

  -- Context fingerprint for deduplication / cache hit analysis
  prompt_hash TEXT,                   -- SHA256 of prompt content (first 16 chars)
  prompt_chars INTEGER,               -- character count of prompt

  -- Outcome correlation
  success BOOLEAN NOT NULL DEFAULT true,
  error_message TEXT,
  duration_ms INTEGER,                -- round-trip latency

  -- Quality correlation (filled later if available)
  quality_review_id UUID REFERENCES app_quality_review(id),
  overall_score SMALLINT CHECK (overall_score BETWEEN 1 AND 10),

  -- Raw payload summary (not full content, to save space)
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW ()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_llm_usage_user_created ON public.app_llm_usage_log (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llm_usage_user_project ON public.app_llm_usage_log (user_id, project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llm_usage_job ON public.app_llm_usage_log (job_id) WHERE job_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_llm_usage_call_type ON public.app_llm_usage_log (call_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llm_usage_model ON public.app_llm_usage_log (model_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llm_usage_quality ON public.app_llm_usage_log (quality_review_id) WHERE quality_review_id IS NOT NULL;

COMMENT ON TABLE public.app_llm_usage_log IS 'Per-LLM-call token usage tracking for cost optimization and automated memory quality enhancement';

ALTER TABLE public.app_llm_usage_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_llm_usage_own_select ON public.app_llm_usage_log;
CREATE POLICY app_llm_usage_own_select ON public.app_llm_usage_log FOR SELECT TO authenticated USING (
  user_id = (SELECT auth.uid ())
);

-- Aggregate view: daily token usage per user / project / model
CREATE OR REPLACE VIEW llm_usage_daily_summary AS
SELECT
  user_id,
  project_id,
  model_name,
  date_trunc('day', created_at) as usage_date,
  count(*) as call_count,
  sum(prompt_tokens) as total_prompt_tokens,
  sum(completion_tokens) as total_completion_tokens,
  sum(total_tokens) as total_tokens,
  sum(estimated_cost_cents) as total_estimated_cost_cents,
  avg(duration_ms)::integer as avg_duration_ms,
  count(*) FILTER (WHERE success = false) as failed_count
FROM public.app_llm_usage_log
GROUP BY user_id, project_id, model_name, date_trunc('day', created_at);

COMMENT ON VIEW llm_usage_daily_summary IS 'Daily LLM usage aggregates for dashboard and quota monitoring';
