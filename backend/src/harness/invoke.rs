//! Synchronous Harness tool execution (MVP). WebSocket and future agent loop call into here.

use serde_json::Value;

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
}

impl From<SkillReadError> for InvokeError {
    fn from(e: SkillReadError) -> Self {
        match e {
            SkillReadError::BadPath(m) => InvokeError::SkillBadRequest(m),
            SkillReadError::SkillsDirMissing => InvokeError::SkillUnavailable,
            SkillReadError::NotFound => InvokeError::SkillNotFound,
            SkillReadError::TooLarge => {
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
        }
    }
}

fn dispatch_in_process(
    _ctx: &HarnessContext,
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
        HarnessContext::new(Uuid::nil())
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
}
