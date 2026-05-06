//! 发布域（short-video-space **§E**）：`publish_profiles` / `publish_drafts` / targets / jobs / attempts + 校验、状态机、半自动闸门、worker 骨架。

pub mod ab_testing;
#[cfg(test)]
mod ab_testing_tests;
mod access;
mod adapters;
mod callback_config;
mod callback_handlers;
mod callback_validation;
#[cfg(test)]
mod callback_validation_tests;
mod copy_cache;
mod copy_validate;
mod handlers;
mod handlers_f;
#[cfg(test)]
mod nine_platform_acceptance_tests;
mod openapi;
mod performance_rework;
mod platform_registry;
#[cfg(test)]
mod quality_gate_tests;
mod state_machine;
mod store;
mod suggest_copy;
mod types;
mod validation;
pub mod worker;

use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    handlers::router()
        .merge(handlers_f::router())
        .merge(callback_handlers::callback_router())
}

pub(crate) use access::require_project_owned;
pub use openapi::PublishOpenApi;

pub(crate) use types::{
    attempt_audit_from_row, draft_from_row, job_from_row, performance_alert_from_row,
    profile_from_row, target_from_row,
};

// M.1: Callback security exports
pub use callback_config::{
    deactivate_platform_secret, get_platform_secret, init_default_secrets, list_platform_secrets,
    upsert_platform_secret, PlatformSecretInfo,
};
pub use callback_validation::{
    cleanup_expired_nonces, CallbackValidationConfig, ValidatedCallback,
};
