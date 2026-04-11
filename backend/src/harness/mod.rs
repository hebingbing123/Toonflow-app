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
mod sub_agent;
pub mod tools;
pub(crate) mod wasm_runtime;
pub mod wire;
pub mod ws;

use uuid::Uuid;

/// Harness 工具执行上下文。
///
/// 在执行 Harness 工具调用时传递，包含用户身份、数据库访问、LLM 配置等资源。
/// 用于权限验证和工具执行所需的服务访问。
#[derive(Clone, Debug)]
pub struct HarnessContext {
    /// 当前用户的 UUID。
    pub user_id: Uuid,
    /// 数据库连接池（如果工具需要数据库访问）。
    pub pool: Option<sqlx::PgPool>,
    /// 当前项目的遗留 ID（用于项目范围工具）。
    pub project_legacy_id: Option<i32>,
    /// 当前脚本的遗留 ID（用于脚本范围工具）。
    pub script_legacy_id: Option<i32>,
    /// LLM 配置（用于需要 AI 调用的工具）。
    pub llm: Option<crate::llm::LlmConfig>,
    /// HTTP 客户端（用于需要外部 API 调用的工具）。
    pub http_client: Option<reqwest::Client>,
}

impl HarnessContext {
    pub fn with_runtime_scope(
        user_id: Uuid,
        pool: Option<sqlx::PgPool>,
        project_legacy_id: Option<i32>,
        script_legacy_id: Option<i32>,
        llm: Option<crate::llm::LlmConfig>,
        http_client: Option<reqwest::Client>,
    ) -> Self {
        Self {
            user_id,
            pool,
            project_legacy_id,
            script_legacy_id,
            llm,
            http_client,
        }
    }
}
