-- Staging area for one-shot imports from legacy Electron SQLite (db2.sqlite).
-- Consumed by backend CLI `toonflow-legacy-import`, not by PostgREST by default.
CREATE SCHEMA IF NOT EXISTS legacy_staging;

CREATE TABLE legacy_staging.snapshot (
  id BIGSERIAL PRIMARY KEY,
  source_table TEXT NOT NULL,
  source_row_key TEXT NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_legacy_snapshot_table ON legacy_staging.snapshot (source_table);
CREATE INDEX idx_legacy_snapshot_table_row ON legacy_staging.snapshot (source_table, source_row_key);

COMMENT ON SCHEMA legacy_staging IS 'Legacy SQLite → PG import staging (JSONB rows)';
COMMENT ON TABLE legacy_staging.snapshot IS 'One row per SQLite source row; source_row_key is SQLite rowid string';
