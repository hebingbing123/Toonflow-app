-- Benchmark: persist A/B compare runs (platform ops)

CREATE TABLE IF NOT EXISTS app_benchmark_ab_compare_run (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    name TEXT,
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    summary JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_benchmark_ab_compare_run_owner_created_at
    ON app_benchmark_ab_compare_run(owner_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS app_benchmark_ab_compare_case (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id UUID NOT NULL REFERENCES app_benchmark_ab_compare_run(id) ON DELETE CASCADE,
    test_case_id TEXT NOT NULL,
    baseline_job_id UUID NOT NULL,
    optimized_job_id UUID NOT NULL,
    comparison JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_benchmark_ab_compare_case_run_id
    ON app_benchmark_ab_compare_case(run_id);

CREATE INDEX IF NOT EXISTS idx_benchmark_ab_compare_case_test_case_id
    ON app_benchmark_ab_compare_case(test_case_id);

COMMENT ON TABLE app_benchmark_ab_compare_run IS 'Persisted A/B compare runs (benchmark ops) for replay and audit';
COMMENT ON TABLE app_benchmark_ab_compare_case IS 'Per-case comparison payload for a persisted A/B compare run';
