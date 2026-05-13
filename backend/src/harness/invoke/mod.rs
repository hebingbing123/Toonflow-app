//! Harness 工具执行。WebSocket 和代理循环调用此处。
//!
//! 子模块：
//! - `domain_script` — 脚本域工具（get_planData、get_script_content、get_novel_*）
//! - `domain_production` — 制作域工具（get_flowData、derive-asset、storyboard）

mod domain_production;
mod domain_script;

mod dispatch;
mod errors;
mod helpers;

pub use errors::InvokeError;

pub(super) use helpers::{
    apply_text_window, map_api_error, parse_i32_required, parse_ids_required, parse_optional_i32,
    parse_optional_i32_array, parse_optional_string_array, parse_optional_usize,
    parse_optional_zero_based_usize, project_numeric_from_ctx, require_pool,
    script_numeric_id_from_args_or_ctx, select_object_fields,
};

pub use dispatch::{invoke_tool, invoke_tool_async};

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::harness::HarnessContext;
    use serde_json::{json, Value};
    use uuid::Uuid;

    fn ctx() -> HarnessContext {
        HarnessContext::with_runtime_scope(
            Uuid::nil(),
            None,
            None,
            None,
            None,
            None,
            None,
            crate::metering::BillingConfig::default(),
        )
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
