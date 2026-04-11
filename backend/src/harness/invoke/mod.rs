//! Harness 工具执行。WebSocket 和代理循环调用此处。
//!
//! 子模块：
//! - `domain_script` — 脚本域工具（get_planData、get_script_content、get_novel_*）
//! - `domain_production` — 制作域工具（get_flowData、derive-asset、storyboard）

mod domain_production;
mod domain_script;

use std::collections::BTreeSet;

use serde_json::Value;

use super::HarnessContext;
use crate::prompting::skills::SkillReadError;

// ── InvokeError ──────────────────────────────────────────────────────────────

#[derive(Debug)]
pub enum InvokeError {
    UnknownTool(String),
    NotImplemented {
        tool: String,
        hint: String,
    },
    /// Tool-specific argument validation (maps to `invalid_payload` over WS).
    InvalidArgs(String),
    SkillNotFound,
    SkillBadRequest(String),
    SkillUnavailable,
    /// Child process / IPC failure for process-isolated tools (`isolated.echo`).
    IsolationFailed(String),
    /// WASM interpreter failure (`wasm.probe`).
    WasmFailed(String),
    /// Postgres-backed domain tools require a configured pool.
    DatabaseUnavailable,
    /// Domain tools require project/script context and/or arguments.
    MissingContext(String),
    DatabaseError(String),
    LlmNotConfigured,
    LlmError(String),
}

impl From<SkillReadError> for InvokeError {
    fn from(e: SkillReadError) -> Self {
        match e {
            SkillReadError::BadPath(m) => InvokeError::SkillBadRequest(m),
            SkillReadError::SkillsDirMissing => InvokeError::SkillUnavailable,
            SkillReadError::NotFound => InvokeError::SkillNotFound,
            SkillReadError::TooLarge | SkillReadError::TooLargeBinary => {
                InvokeError::SkillBadRequest("skill file exceeds maximum allowed size".into())
            }
            SkillReadError::Io(m) => InvokeError::SkillBadRequest(m),
        }
    }
}

impl InvokeError {
    #[must_use]
    pub fn code(&self) -> &'static str {
        match self {
            InvokeError::UnknownTool(_) => "unknown_tool",
            InvokeError::NotImplemented { .. } => "tool_not_implemented",
            InvokeError::InvalidArgs(_) => "invalid_payload",
            InvokeError::SkillNotFound => "not_found",
            InvokeError::SkillBadRequest(_) => "invalid_payload",
            InvokeError::SkillUnavailable => "skill_unavailable",
            InvokeError::IsolationFailed(_) => "isolation_failed",
            InvokeError::WasmFailed(_) => "wasm_failed",
            InvokeError::DatabaseUnavailable => "database_error",
            InvokeError::MissingContext(_) => "invalid_state",
            InvokeError::DatabaseError(_) => "database_error",
            InvokeError::LlmNotConfigured => "llm_not_configured",
            InvokeError::LlmError(_) => "llm_error",
        }
    }

    #[must_use]
    pub fn message(&self) -> String {
        match self {
            InvokeError::UnknownTool(n) => format!("unknown or unregistered tool: {n}"),
            InvokeError::NotImplemented { tool, hint } => format!("{tool}: {hint}"),
            InvokeError::InvalidArgs(m) => m.clone(),
            InvokeError::SkillNotFound => "skill file not found".into(),
            InvokeError::SkillBadRequest(m) => m.clone(),
            InvokeError::SkillUnavailable => {
                "skills directory is not available on this server".into()
            }
            InvokeError::IsolationFailed(m) => m.clone(),
            InvokeError::WasmFailed(m) => m.clone(),
            InvokeError::DatabaseUnavailable => "DATABASE_URL not configured".into(),
            InvokeError::MissingContext(m) => m.clone(),
            InvokeError::DatabaseError(m) => m.clone(),
            InvokeError::LlmNotConfigured => "set OPENAI_API_KEY or LLM_API_KEY".into(),
            InvokeError::LlmError(m) => m.clone(),
        }
    }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

pub(super) fn require_pool(ctx: &HarnessContext) -> Result<&sqlx::PgPool, InvokeError> {
    ctx.pool.as_ref().ok_or(InvokeError::DatabaseUnavailable)
}

pub(super) fn map_api_error(err: crate::error::ApiError, fallback: &'static str) -> InvokeError {
    match err {
        crate::error::ApiError::NotFound => {
            InvokeError::MissingContext("resource not found".into())
        }
        crate::error::ApiError::BadRequest(msg) => InvokeError::InvalidArgs(msg),
        crate::error::ApiError::DatabaseError(msg) => InvokeError::DatabaseError(msg),
        _ => InvokeError::DatabaseError(fallback.into()),
    }
}

pub(super) fn project_legacy_from_ctx(ctx: &HarnessContext) -> Result<i32, InvokeError> {
    ctx.project_legacy_id
        .filter(|v| *v > 0)
        .ok_or_else(|| InvokeError::MissingContext("project context not attached".into()))
}

pub(super) fn script_legacy_id_from_args_or_ctx(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<i32, InvokeError> {
    let from_args = arguments
        .get("scriptId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);
    from_args.or(ctx.script_legacy_id).ok_or_else(|| {
        InvokeError::MissingContext("scriptId is required (arg or attach context)".into())
    })
}

pub(super) fn parse_i32_required(arguments: &Value, key: &str) -> Result<i32, InvokeError> {
    arguments
        .get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0)
        .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be a positive integer")))
}

pub(super) fn parse_ids_required(arguments: &Value, key: &str) -> Result<Vec<i32>, InvokeError> {
    let values = arguments
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be a non-empty array")))?;
    if values.is_empty() {
        return Err(InvokeError::InvalidArgs(format!(
            "{key} must be a non-empty array"
        )));
    }
    let mut uniq = BTreeSet::new();
    for value in values {
        let id = value
            .as_i64()
            .and_then(|v| i32::try_from(v).ok())
            .filter(|v| *v > 0)
            .ok_or_else(|| {
                InvokeError::InvalidArgs(format!("{key} must contain positive integers"))
            })?;
        uniq.insert(id);
    }
    Ok(uniq.into_iter().collect())
}

fn is_sub_agent_tool(name: &str) -> bool {
    matches!(
        name,
        "run_sub_agent_storySkeleton"
            | "run_sub_agent_adaptationStrategy"
            | "run_sub_agent_script"
            | "run_supervision_agent"
            | "run_sub_agent_derive_assets"
            | "run_sub_agent_generate_assets"
            | "run_sub_agent_director_plan"
            | "run_sub_agent_storyboard_gen"
            | "run_sub_agent_storyboard_panel"
            | "run_sub_agent_storyboard_table"
    )
}

// ── Dispatch ─────────────────────────────────────────────────────────────────

fn dispatch_in_process(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    use domain_production::*;
    use domain_script::*;

    match name {
        "echo" => Ok(arguments.clone()),
        "wasm.probe" => super::wasm_runtime::invoke_probe().map_err(InvokeError::WasmFailed),
        "skills.read" => {
            let path = arguments
                .get("path")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .ok_or_else(|| {
                    InvokeError::InvalidArgs(
                        "skills.read requires arguments.path (non-empty string)".into(),
                    )
                })?;
            let doc =
                crate::prompting::skills::read_skill_markdown(path).map_err(InvokeError::from)?;
            serde_json::to_value(&doc).map_err(|_| {
                InvokeError::SkillBadRequest("failed to serialize skill content".into())
            })
        }
        "get_planData" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_planData requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_plan_data(ctx))
        }
        "get_script_content" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_script_content requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_script_content(ctx, arguments))
        }
        "get_novel_text" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_novel_text requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_novel_text(ctx, arguments))
        }
        "get_novel_events" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_novel_events requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_novel_events(ctx, arguments))
        }
        "get_flowData" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_flowData requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_flow_data(ctx, arguments))
        }
        "add_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "add_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_add_derive_asset(ctx, arguments))
        }
        "del_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "del_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_del_derive_asset(ctx, arguments))
        }
        "generate_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "generate_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_generate_derive_asset(ctx, arguments))
        }
        "generate_storyboard" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "generate_storyboard requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_generate_storyboard(ctx, arguments))
        }
        _ if is_sub_agent_tool(name) => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "sub-agent tools require async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(super::sub_agent::invoke_sub_agent_tool(
                ctx, name, arguments,
            ))
        }
        _ => Err(InvokeError::NotImplemented {
            tool: name.to_string(),
            hint: "registered in catalog but execution is not wired yet".to_string(),
        }),
    }
}

/// Run a catalog tool by name. Returns JSON suitable for `harness.tool.result.payload.result`.
/// WebSocket uses [`invoke_tool_async`] (process-isolated tools); this remains for tests and a future sync caller.
#[allow(dead_code)]
pub fn invoke_tool(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    if !super::permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    super::observe::harness_tool_invoke(ctx, name);

    dispatch_in_process(ctx, name, arguments)
}

/// Like [`invoke_tool`], but routes process-isolated tools to async handlers (WebSocket path).
pub async fn invoke_tool_async(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    use domain_production::*;
    use domain_script::*;

    if !super::permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    super::observe::harness_tool_invoke(ctx, name);

    match name {
        "isolated.echo" => super::isolate::isolated_echo(arguments).await,
        "get_planData" => invoke_get_plan_data(ctx).await,
        "get_script_content" => invoke_get_script_content(ctx, arguments).await,
        "get_novel_text" => invoke_get_novel_text(ctx, arguments).await,
        "get_novel_events" => invoke_get_novel_events(ctx, arguments).await,
        "get_flowData" => invoke_get_flow_data(ctx, arguments).await,
        "add_deriveAsset" => invoke_add_derive_asset(ctx, arguments).await,
        "del_deriveAsset" => invoke_del_derive_asset(ctx, arguments).await,
        "generate_deriveAsset" => invoke_generate_derive_asset(ctx, arguments).await,
        "generate_storyboard" => invoke_generate_storyboard(ctx, arguments).await,
        _ if is_sub_agent_tool(name) => {
            super::sub_agent::invoke_sub_agent_tool(ctx, name, arguments).await
        }
        "wasm.probe" => {
            let r = tokio::task::spawn_blocking(super::wasm_runtime::invoke_probe)
                .await
                .map_err(|e| InvokeError::WasmFailed(format!("join: {e}")))?;
            r.map_err(InvokeError::WasmFailed)
        }
        _ => dispatch_in_process(ctx, name, arguments),
    }
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use uuid::Uuid;

    fn ctx() -> HarnessContext {
        HarnessContext::with_runtime_scope(Uuid::nil(), None, None, None, None, None)
    }

    #[test]
    fn echo_returns_arguments() {
        let args = json!({ "a": 1, "b": "x" });
        let out = invoke_tool(&ctx(), "echo", &args).unwrap();
        assert_eq!(out, args);
    }

    #[test]
    fn unknown_tool_not_in_catalog() {
        let err = invoke_tool(&ctx(), "no_such_tool", &json!({})).unwrap_err();
        assert_eq!(err.code(), "unknown_tool");
    }

    #[test]
    fn skills_read_requires_path() {
        let err = invoke_tool(&ctx(), "skills.read", &json!({})).unwrap_err();
        assert_eq!(err.code(), "invalid_payload");
    }

    #[test]
    fn skills_read_loads_known_file() {
        let out = invoke_tool(
            &ctx(),
            "skills.read",
            &json!({ "path": "script_execution_script.md" }),
        )
        .unwrap();
        let path = out.get("path").and_then(Value::as_str).unwrap();
        assert!(
            path.ends_with("script_execution_script.md"),
            "unexpected path: {path}"
        );
        let content = out.get("content").and_then(Value::as_str).unwrap();
        assert!(!content.is_empty());
    }

    #[test]
    fn wasm_probe_returns_42() {
        let out = invoke_tool(&ctx(), "wasm.probe", &json!({})).unwrap();
        assert_eq!(out.get("value").and_then(Value::as_i64), Some(42));
    }

    #[tokio::test]
    async fn get_script_content_requires_context() {
        let err = invoke_tool_async(&ctx(), "get_script_content", &json!({}))
            .await
            .unwrap_err();
        assert_eq!(err.code(), "database_error");
    }

    #[tokio::test]
    async fn get_flow_data_requires_key() {
        let err = invoke_tool_async(&ctx(), "get_flowData", &json!({}))
            .await
            .unwrap_err();
        assert_eq!(err.code(), "invalid_payload");
    }

    #[tokio::test]
    async fn generate_storyboard_ids_require_positive_ints() {
        let err = invoke_tool_async(&ctx(), "generate_storyboard", &json!({ "ids": [0] }))
            .await
            .unwrap_err();
        assert_eq!(err.code(), "invalid_payload");
    }
}
