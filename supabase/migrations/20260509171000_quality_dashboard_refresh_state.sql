-- Quality dashboard refresh metadata.
-- Keeps the materialized-view freshness observable to both API and UI.

CREATE TABLE IF NOT EXISTS public.app_dashboard_refresh_state (
  dashboard_key TEXT PRIMARY KEY,
  refreshed_at TIMESTAMPTZ NOT NULL,
  row_count BIGINT NOT NULL DEFAULT 0,
  source_review_count BIGINT NOT NULL DEFAULT 0,
  source_usage_count BIGINT NOT NULL DEFAULT 0,
  source_max_review_created_at TIMESTAMPTZ,
  source_max_usage_created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.app_dashboard_refresh_state IS
  'Refresh metadata for persisted dashboard read models';

COMMENT ON COLUMN public.app_dashboard_refresh_state.dashboard_key IS
  'Logical dashboard identifier, e.g. quality_main_panel';
