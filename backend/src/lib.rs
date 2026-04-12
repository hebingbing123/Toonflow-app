//! Toonflow server library crate (shared by `toonflow-server` and tooling binaries).

#![recursion_limit = "1024"]

pub mod app;
pub mod assets;
pub mod auth;
pub mod billing;
pub mod error;
pub mod harness;
pub mod http_kit;
pub mod jobs;
pub mod llm;
pub mod manuals;
pub mod metering;
pub mod narrative;
pub mod production;
pub mod production_flow;
pub mod projects;
pub mod prompting;
pub mod scope;
pub mod scripting;
pub mod settings;
pub mod state;
pub mod vendor;

pub mod openapi_spec;
