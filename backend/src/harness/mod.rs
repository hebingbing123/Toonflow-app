//! Harness-oriented runtime boundaries for tools, permissions, and observation.
//!
//! | Area | Role |
//! |------|------|
//! | [`tools`] | Static catalog (`HarnessToolInfo`); source of truth for allowlists and OpenAPI/WS docs. |
//! | [`http`] | REST under `/api/v1/harness/*` (e.g. tool listing). |
//! | [`wire`] | Deserialize structs for WebSocket **`payload`** bodies (`harness.*`, `agent.*.attach`, `agent.chat.send`, `session.auth`). |
//! | [`ws_channel`] | `Script` / `Production` discriminator + LLM assistant label. |
//! | [`ws_auth`] | `?access_token=` / `session.auth`, notify subscribe/unsubscribe, [`WsConnectionSession`]. |
//! | [`ws_connection`] | Post-upgrade socket loop (notify fan-in + `ws_dispatch`). |
//! | [`ws_dispatch`] | Parse client JSON envelope and route authenticated frames. |
//! | [`ws_outbound`] | `send_envelope` / `error.occurred` helpers for handlers and background tasks. |
//! | [`ws_session`] | `agent.script.attach` / `agent.production.attach` / `agent.context.update`. |
//! | [`ws_tool`] / [`ws_agent`] / [`ws_chat`] | `harness.tool.invoke`, `harness.agent.run`, `agent.chat.send` (keeps the top-level `ws` module thin). |
//! | [`invoke`] | Execute catalog tools (sync + async); gated by [`permissions`]. |
//! | [`observe`] | `tracing` hooks for WS frames, tool runs, HTTP catalog, memory REST, generation jobs. |
//! | [`isolate`] / [`wasm_runtime`] | Hard isolation backends (subprocess, embedded WASM). |
//!
//! Agent / LLM orchestration (`harness.agent.run`, streaming chat) lives in `llm` and harness WS modules; Axum upgrade entry is [`crate::ws`].

pub mod http;
pub mod invoke;
pub mod isolate;
pub mod observe;
pub mod permissions;
pub mod tools;
pub(crate) mod wasm_runtime;
pub mod wire;
pub(crate) mod ws_agent;
pub mod ws_auth;
pub mod ws_channel;
pub(crate) mod ws_chat;
pub(crate) mod ws_connection;
pub(crate) mod ws_dispatch;
pub(crate) mod ws_outbound;
pub(crate) mod ws_session;
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
