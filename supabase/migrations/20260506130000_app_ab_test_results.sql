-- L.3: A/B testing results table for token optimization validation
-- Stores A/B test results comparing baseline vs optimized implementations

CREATE TABLE IF NOT EXISTS app_ab_test_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_case_id TEXT NOT NULL,
    variant TEXT NOT NULL CHECK (variant IN ('baseline', 'optimized')),
    quality_metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
    token_metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fetching results by test case
CREATE INDEX IF NOT EXISTS idx_ab_test_results_test_case_id 
    ON app_ab_test_results(test_case_id);

-- Index for fetching results by variant
CREATE INDEX IF NOT EXISTS idx_ab_test_results_variant 
    ON app_ab_test_results(variant);

-- Index for time-based queries
CREATE INDEX IF NOT EXISTS idx_ab_test_results_created_at 
    ON app_ab_test_results(created_at DESC);

-- Composite index for test case + variant lookups
CREATE INDEX IF NOT EXISTS idx_ab_test_results_test_case_variant 
    ON app_ab_test_results(test_case_id, variant);

COMMENT ON TABLE app_ab_test_results IS 'A/B testing results for validating token optimizations without quality regression';
COMMENT ON COLUMN app_ab_test_results.test_case_id IS 'Identifier for the test case (e.g., project-123-publish-copy)';
COMMENT ON COLUMN app_ab_test_results.variant IS 'Test variant: baseline (pre-optimization) or optimized (Phase J)';
COMMENT ON COLUMN app_ab_test_results.quality_metrics IS 'Quality metrics: overall_score, character_consistency, dialogue_naturalness, visual_quality, plot_coherence, grade, passed';
COMMENT ON COLUMN app_ab_test_results.token_metrics IS 'Token usage metrics: prompt_tokens, completion_tokens, total_tokens, call_count, cache_hits, incremental_hits';
COMMENT ON COLUMN app_ab_test_results.metadata IS 'Additional test metadata and context';
