-- numeric_id removal window policy (comment-only; no column drops)
-- Related: docs/plans/tasks-http-api-cleanup.md H5·D, backend/src/legacy_numeric_id/mod.rs
--
-- PG identifier columns remain until import + /jobs/page UUID filter + DBA sign-off.
-- Runtime gates: OPENFLOW_NUMERIC_ID_LEGACY_READ / OPENFLOW_NUMERIC_ID_LEGACY_WRITE (default true).
-- Target sunset for numeric-only clients: 2026-11-01 (operational).

COMMENT ON COLUMN public.app_project.numeric_id IS
  'Legacy per-owner integer project id (Electron/SQLite era). UUID app_project.id is canonical. Removal window: keep through ~2026-11; drop only after promote_import_snapshots UUID path and jobs UUID filter. Env: OPENFLOW_NUMERIC_ID_LEGACY_READ/WRITE.';

COMMENT ON COLUMN public.app_script.numeric_id IS
  'Legacy script integer id within project. Prefer app_script.id (UUID) on new clients. Same removal window as app_project.numeric_id.';

COMMENT ON COLUMN public.app_storyboard.numeric_id IS
  'Legacy storyboard integer id within script. Prefer UUID storyboard rows where exposed. Same removal window as app_project.numeric_id.';

COMMENT ON COLUMN public.app_asset.numeric_id IS
  'Legacy asset integer id within project. Prefer app_asset.id (UUID) on new clients. Same removal window as app_project.numeric_id.';
