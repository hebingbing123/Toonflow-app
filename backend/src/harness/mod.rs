//! Harness-oriented runtime boundaries for tools, permissions, and observation.
//!
//! | Area | Role |
//! |------|------|
//! | [`tools`] | Static catalog (`HarnessToolInfo`); source of truth for allowlists and OpenAPI/WS docs. |
//! | [`http`] | REST under `/api/v1/harness/*` (e.g. tool listing). |
//! | [`wire`] | Deserialize structs for WebSocket **`payload`** bodies (`harness.*`, `agent.*.attach`, `agent.chat.send`, `session.auth`). |
//! | [`ws`] | **`/api/v1/ws`** stack: [`ws::upgrade`], [`ws::connection`], [`ws::auth`], [`ws::dispatch`], [`ws::outbound`], [`ws::session`], [`ws::tool`], [`ws::agent`], [`ws::chat`], [`ws::channel`]. |
//! | [`invoke`] | Execute catalog tools (sync + async); gated by [`permissions`]. |
//! | [`observe`] | `tracing` hooks for WS frames, tool runs, HTTP catalog, memory REST, generation jobs. |
//! | [`isolate`] / [`wasm_runtime`] | Hard isolation backends (subprocess, embedded WASM). |
//!
//! Agent / LLM orchestration (`harness.agent.run`, streaming chat) lives in `llm` and [`ws`]; the HTTP upgrade entry is [`ws::upgrade`].

pub mod http;
pub mod invoke;
pub mod isolate;
pub mod observe;
pub mod permissions;
pub mod tools;
pub(crate) mod wasm_runtime;
pub mod wire;
pub mod ws;

use uuid::Uuid;

#[derive(Clone, Debug)]
pub struct HarnessContext {
    pub user_id: Uuid,
    pub pool: Option<sqlx::PgPool>,
    pub project_legacy_id: Option<i32>,
    pub script_legacy_id: Option<i32>,
}

impl HarnessContext {
    pub fn with_scope(
        user_id: Uuid,
        pool: Option<sqlx::PgPool>,
        project_legacy_id: Option<i32>,
        script_legacy_id: Option<i32>,
    ) -> Self {
        Self {
            user_id,
            pool,
            project_legacy_id,
            script_legacy_id,
        }
    }
}
