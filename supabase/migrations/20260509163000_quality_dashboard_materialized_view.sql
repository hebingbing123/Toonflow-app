-- Quality dashboard materialized read model.
-- Purpose: speed up the quality main panel by persisting per-review dashboard facts,
-- then letting API handlers aggregate on top of this snapshot instead of repeatedly
-- joining raw review + token-usage tables.

DROP MATERIALIZED VIEW IF EXISTS public.app_quality_dashboard_review_fact;

CREATE MATERIALIZED VIEW public.app_quality_dashboard_review_fact AS
WITH llm_usage_by_review AS (
  SELECT
    quality_review_id,
    COUNT(*)::BIGINT AS token_usage_sample_count,
    AVG(total_tokens)::FLOAT8 AS avg_total_tokens
  FROM public.app_llm_usage_log
  WHERE quality_review_id IS NOT NULL
  GROUP BY quality_review_id
)
SELECT
  qr.id AS quality_review_id,
  qr.user_id,
  qr.project_id,
  qr.script_id,
  qr.created_at,
  qr.target_type,
  qr.source,
  qr.stage,
  qr.grade,
  qr.passed,
  qr.overall_score,
  qr.is_bad_case,
  qr.bad_case_category,
  qr.dialogue_naturalness,
  qr.visual_quality,
  qr.comments,
  qr.memory_delivery_priority_applied,
  qr.model_params,
  (COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::INTEGER
    AS diagnostics_prompt_chars,
  (COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::INTEGER
    AS diagnostics_memory_style_chars,
  (COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryChars')::INTEGER
    AS diagnostics_memory_delivery_chars,
  COALESCE(usage.token_usage_sample_count, 0)::BIGINT AS token_usage_sample_count,
  usage.avg_total_tokens,
  (
    qr.passed IS NOT NULL
    OR qr.overall_score IS NOT NULL
    OR qr.is_bad_case = true
    OR qr.bad_case_category IS NOT NULL
    OR qr.grade IS NOT NULL
  ) AS has_quality_signal,
  (qr.source = 'auto' AND COALESCE(qr.model_params, '{}'::jsonb) ? 'diagnostics')
    AS has_diagnostics,
  (COALESCE(usage.token_usage_sample_count, 0) > 0) AS has_token_usage
FROM public.app_quality_review qr
LEFT JOIN llm_usage_by_review usage
  ON usage.quality_review_id = qr.id
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_quality_dashboard_review_fact_pk
  ON public.app_quality_dashboard_review_fact (quality_review_id);

CREATE INDEX IF NOT EXISTS idx_quality_dashboard_review_fact_scope
  ON public.app_quality_dashboard_review_fact (
    user_id,
    project_id,
    script_id,
    created_at DESC
  );

CREATE INDEX IF NOT EXISTS idx_quality_dashboard_review_fact_signal
  ON public.app_quality_dashboard_review_fact (
    user_id,
    has_quality_signal,
    created_at DESC
  );

CREATE INDEX IF NOT EXISTS idx_quality_dashboard_review_fact_auto_usage
  ON public.app_quality_dashboard_review_fact (
    user_id,
    has_diagnostics,
    has_token_usage,
    created_at DESC
  );

COMMENT ON MATERIALIZED VIEW public.app_quality_dashboard_review_fact IS
  'Per-quality-review dashboard facts for the quality main panel read model';

REFRESH MATERIALIZED VIEW public.app_quality_dashboard_review_fact;
