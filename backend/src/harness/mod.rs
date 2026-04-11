//! Harness 运行时边界：工具、权限和观察。
//!
//! | 模块 | 职责 |
//! |------|------|
//! | `tools` | 静态目录（`HarnessToolInfo`）；允许列表和 OpenAPI/WS 文档的真理源 |
//! | `http` | `/api/v1/harness/*` 下的 REST（如工具列表） |
//! | `wire` | WebSocket `payload` 体的反序列化结构 |
//! | `ws` | `/api/v1/ws` 协议栈：升级、连接、认证、调度、出站、会话、工具、代理、聊天、频道 |
//! | `invoke` | 执行目录工具（同步 + 异步）；由 `permissions` 控制 |
//! | `observe` | 用于 WS 帧、工具运行、HTTP 目录、内存 REST、生成任务的追踪钩子 |
//! | `isolate` / `wasm_runtime` | 硬隔离后端（子进程、嵌入式 WASM） |
//!
//! 代理/LLM 编排（`harness.agent.run`、流式聊天）位于 `llm` 和 `ws`；HTTP 升级入口是 `ws::upgrade`。

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
    pub project_numeric_id: Option<i32>,
    /// 当前脚本的遗留 ID（用于脚本范围工具）。
    pub script_numeric_id: Option<i32>,
    /// LLM 配置（用于需要 AI 调用的工具）。
    pub llm: Option<crate::llm::LlmConfig>,
    /// HTTP 客户端（用于需要外部 API 调用的工具）。
    pub http_client: Option<reqwest::Client>,
}

impl HarnessContext {
    pub fn with_runtime_scope(
        user_id: Uuid,
        pool: Option<sqlx::PgPool>,
        project_numeric_id: Option<i32>,
        script_numeric_id: Option<i32>,
        llm: Option<crate::llm::LlmConfig>,
        http_client: Option<reqwest::Client>,
    ) -> Self {
        Self {
            user_id,
            pool,
            project_numeric_id,
            script_numeric_id,
            llm,
            http_client,
        }
    }
}
