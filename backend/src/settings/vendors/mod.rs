//! Legacy **`POST /api/setting/vendorConfig/getVendorList`** returned SQLite **`o_vendorConfig`**
//! rows (including **`inputValues`** secrets).
//! SaaS: **`GET …/vendors/summary`** merges the static catalog with per-user **`vendor_config`**
//! from `app_user_profile`.
//! **`POST …/vendors/{add,update,delete,enable,update-code,code-from-link}`** persists vendor
//! metadata in Postgres-backed user config, but never executes TS, fetches remote code, or stores
//! API keys. Custom / linked vendor code is stored as metadata only.
//! **`POST …/model-test`** validates the legacy body, enqueues **`settings.vendor.model_test`**;
//! the worker then performs a live probe:
//! text / image prefer stored vendor credentials and fall back to server LLM env,
//! while video resolves provider-specific minimal generation requests.
//! API keys (`inputValues`) are intentionally NOT stored; use server env or vault.

mod dto;
mod handlers;
mod store;

pub(super) const MAX_VENDOR_MODEL_TEST_FIELD_LEN: usize = 512;

use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    handlers::router()
}

#[cfg(test)]
mod tests;
