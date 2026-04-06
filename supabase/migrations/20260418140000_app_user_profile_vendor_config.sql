-- Per-user vendor configuration (non-sensitive: enable/disable, model selection)
-- API keys (inputValues) are intentionally NOT stored here; use server env or vault.
-- TypeScript code (tsCode) execution is not supported in Rust backend.
alter table app_user_profile add column if not exists vendor_config jsonb default null;
comment on column app_user_profile.vendor_config is
  'User vendor configuration JSON (non-sensitive only: enabled vendors, model selection). API keys intentionally excluded for security; use server env.';
