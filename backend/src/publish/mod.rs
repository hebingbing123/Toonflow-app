//! 发布域（short-video-space **§E**）：`publish_profiles` / `publish_drafts` / targets / jobs / attempts + 校验、状态机、半自动闸门、worker 骨架。

mod access;
mod adapters;
mod copy_cache;
mod copy_validate;
mod handlers;
mod handlers_f;
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
    handlers::router().merge(handlers_f::router())
}

pub(crate) use access::require_project_owned;
pub use openapi::PublishOpenApi;

pub(crate) use types::{
    attempt_audit_from_row, draft_from_row, job_from_row, performance_alert_from_row,
    profile_from_row, target_from_row,
};
