//! Harness-oriented runtime boundaries for tools, permissions, and observation.
//!
//! | Area | Role |
//! |------|------|
//! | [`tools`] | Static catalog (`HarnessToolInfo`); source of truth for allowlists and OpenAPI/WS docs. |
//! | [`http`] | REST under `/api/v1/harness/*` (e.g. tool listing). |
//! | [`wire`] | Deserialize structs for `harness.*` WebSocket payloads (`schema_version` 1). |
//! | [`ws_tool`] / [`ws_agent`] | WebSocket branches for `harness.tool.invoke` and `harness.agent.run` (keeps the top-level `ws` module thin). |
//! | [`invoke`] | Execute catalog tools (sync + async); gated by [`permissions`]. |
//! | [`observe`] | `tracing` hooks for WS frames, tool runs, HTTP catalog, memory REST, generation jobs. |
//! | [`isolate`] / [`wasm_runtime`] | Hard isolation backends (subprocess, embedded WASM). |
//!
//! Agent / LLM orchestration (`harness.agent.run`, streaming chat) lives in the sibling `llm` and `ws` modules, calling into invoke + observe here.

pub mod http;
pub mod invoke;
pub mod isolate;
pub mod observe;
pub mod permissions;
pub mod tools;
pub(crate) mod wasm_runtime;
pub mod wire;
pub(crate) mod ws_agent;
pub(crate) mod ws_tool;

use uuid::Uuid;

#[derive(Clone, Debug)]
pub struct HarnessContext {
    pub user_id: Uuid,
}

impl HarnessContext {
    pub fn new(user_id: Uuid) -> Self {
        Self { user_id }
    }
}
