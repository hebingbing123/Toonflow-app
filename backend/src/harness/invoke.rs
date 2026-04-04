//! Synchronous Harness tool execution (MVP). WebSocket and future agent loop call into here.

use serde_json::Value;

use super::observe;
use super::permissions;
use super::HarnessContext;

#[derive(Debug)]
pub enum InvokeError {
    UnknownTool(String),
    NotImplemented { tool: String, hint: String },
}

impl InvokeError {
    #[must_use]
    pub fn code(&self) -> &'static str {
        match self {
            InvokeError::UnknownTool(_) => "unknown_tool",
            InvokeError::NotImplemented { .. } => "tool_not_implemented",
        }
    }

    #[must_use]
    pub fn message(&self) -> String {
        match self {
            InvokeError::UnknownTool(n) => format!("unknown or unregistered tool: {n}"),
            InvokeError::NotImplemented { tool, hint } => format!("{tool}: {hint}"),
        }
    }
}

/// Run a catalog tool by name. Returns JSON suitable for `harness.tool.result.payload.result`.
pub fn invoke_tool(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    if !permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    observe::harness_tool_invoke(ctx, name);

    match name {
        "echo" => Ok(arguments.clone()),
        "skills.read" => Err(InvokeError::NotImplemented {
            tool: name.to_string(),
            hint: "use GET /api/v1/skills/content with Bearer JWT".to_string(),
        }),
        _ => Err(InvokeError::NotImplemented {
            tool: name.to_string(),
            hint: "registered in catalog but execution is not wired yet".to_string(),
        }),
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
    fn skills_read_not_implemented_on_invoke_path() {
        let err = invoke_tool(&ctx(), "skills.read", &json!({})).unwrap_err();
        assert_eq!(err.code(), "tool_not_implemented");
    }
}
