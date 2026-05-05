//! 发布域（short-video-space **§E**）：`publish_profiles` / `publish_drafts` / targets / jobs / attempts + 校验、状态机、半自动闸门、worker 骨架。

mod access;
mod handlers;
mod openapi;
mod state_machine;
mod store;
mod types;
mod validation;
pub mod worker;

pub use handlers::router;
pub use openapi::PublishOpenApi;

pub(crate) use types::{draft_from_row, job_from_row, profile_from_row, target_from_row};
