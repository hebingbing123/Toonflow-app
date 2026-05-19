//! Openflow server library crate (shared by `openflow-server` and tooling binaries).

#![recursion_limit = "1024"]

pub mod app;
pub mod assets;
pub mod auth;
pub mod billing;
pub mod error;
pub mod harness;
pub mod http_kit;
pub mod internal_ops;
pub mod jobs;
pub mod legacy_numeric_id;
pub mod llm;
pub mod manuals;
pub mod metering;
pub mod metrics;
pub mod middleware;
pub mod narrative;
pub mod production;
pub mod projects;
pub mod prompting;
pub mod publish;
pub mod scope;
pub mod scripting;
pub mod search;
pub mod settings;
pub mod short_video;
pub mod state;
pub mod telemetry;
pub mod vendor;
pub mod workspaces;

pub mod openapi_spec;
