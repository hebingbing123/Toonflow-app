//! Synchronous Harness tool execution (MVP). WebSocket and future agent loop call into here.

use serde::Serialize;
use serde_json::Value;
use sqlx::types::Json;

use crate::skills::SkillReadError;

use super::observe;
use super::permissions;
use super::HarnessContext;

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
        }
    }
}

#[derive(sqlx::FromRow, Serialize)]
struct HarnessScriptRow {
    legacy_id: i32,
    name: Option<String>,
    content: Option<String>,
    extract_state: Option<i32>,
}

fn require_pool(ctx: &HarnessContext) -> Result<&sqlx::PgPool, InvokeError> {
    ctx.pool.as_ref().ok_or(InvokeError::DatabaseUnavailable)
}

fn project_legacy_from_ctx(ctx: &HarnessContext) -> Result<i32, InvokeError> {
    ctx.project_legacy_id
        .filter(|v| *v > 0)
        .ok_or_else(|| InvokeError::MissingContext("project context not attached".into()))
}

async fn invoke_get_plan_data(ctx: &HarnessContext) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;

    let project_uuid: uuid::Uuid = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_legacy_id)
    .bind(ctx.user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        InvokeError::MissingContext("attached project is not owned or missing".into())
    })?;

    let plan_data: Option<Json<Value>> = sqlx::query_scalar(
        r#"
        SELECT plan_data
        FROM app_script_agent_plan
        WHERE project_id = $1 AND owner_user_id = $2 AND agent_key = 'scriptAgent'
        "#,
    )
    .bind(project_uuid)
    .bind(ctx.user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let scripts: Vec<HarnessScriptRow> = sqlx::query_as(
        r#"
        SELECT s.legacy_id, s.name, s.content, s.extract_state
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1 AND p.legacy_id = $2
        ORDER BY s.legacy_id
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_legacy_id)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let mut data = plan_data.map_or_else(|| Value::Object(Default::default()), |j| j.0);
    if let Some(obj) = data.as_object_mut() {
        obj.insert(
            "script".into(),
            serde_json::to_value(&scripts)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize scripts".into()))?,
        );
    }

    Ok(serde_json::json!({
        "projectId": project_legacy_id,
        "agentType": "scriptAgent",
        "data": data,
    }))
}

fn script_legacy_id_from_args_or_ctx(
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

async fn invoke_get_script_content(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let script_legacy_id = script_legacy_id_from_args_or_ctx(ctx, arguments)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;

    let row: HarnessScriptRow = sqlx::query_as(
        r#"
        SELECT s.legacy_id, s.name, s.content, s.extract_state
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_legacy_id)
    .bind(script_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| InvokeError::MissingContext("script not found in attached project".into()))?;

    serde_json::to_value(row)
        .map_err(|_| InvokeError::DatabaseError("failed to serialize script".into()))
}

fn dispatch_in_process(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
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
            let doc = crate::skills::read_skill_markdown(path).map_err(InvokeError::from)?;
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
    if !permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    observe::harness_tool_invoke(ctx, name);

    dispatch_in_process(ctx, name, arguments)
}

/// Like [`invoke_tool`], but routes process-isolated tools to async handlers (WebSocket path).
pub async fn invoke_tool_async(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    if !permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    observe::harness_tool_invoke(ctx, name);

    match name {
        "isolated.echo" => super::isolate::isolated_echo(arguments).await,
        "get_planData" => invoke_get_plan_data(ctx).await,
        "get_script_content" => invoke_get_script_content(ctx, arguments).await,
        "wasm.probe" => {
            let r = tokio::task::spawn_blocking(super::wasm_runtime::invoke_probe)
                .await
                .map_err(|e| InvokeError::WasmFailed(format!("join: {e}")))?;
            r.map_err(InvokeError::WasmFailed)
        }
        _ => dispatch_in_process(ctx, name, arguments),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use uuid::Uuid;

    fn ctx() -> HarnessContext {
        HarnessContext::with_scope(Uuid::nil(), None, None, None)
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
}
