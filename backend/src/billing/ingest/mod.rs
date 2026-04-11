//! Idempotent webhook row insert + optional `app_user_profile` upsert.
//!
//! Submodules: [`subscription_state`], [`apply_plan`], [`webhook_ingest`], [`event_parse`].

mod apply_plan;
mod event_parse;
mod subscription_state;
mod webhook_ingest;

#[cfg(test)]
mod tests;

pub(crate) use webhook_ingest::ingest_webhook;
