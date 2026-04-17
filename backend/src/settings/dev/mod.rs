//! 开发者设置模块。
//!
//! 遗留 `/api/setting/dev/getSwitchAiDevTool` / `updateSwitchAiDevTool`：AI 开发工具切换曾是 SQLite `o_setting`。
//! Rust 保持进程本地覆盖，环境引导；重启回退到 `TOONFLOW_SWITCH_AI_DEV_TOOL`。

use axum::{routing::get, Router};

use crate::state::AppState;

mod handlers;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{__path_get_switch_ai_dev_tool, __path_put_switch_ai_dev_tool};
pub(crate) use handlers::{get_switch_ai_dev_tool, put_switch_ai_dev_tool};

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/settings/dev/switch-ai-tool",
        get(get_switch_ai_dev_tool).put(put_switch_ai_dev_tool),
    )
}

#[cfg(test)]
mod tests {
    use super::types::{SwitchAiDevToolPutBody, SwitchAiDevToolResponse};

    #[test]
    fn switch_ai_dev_tool_put_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<SwitchAiDevToolPutBody>(r#"{"value":"1","extra":true}"#);
        assert!(err.is_err());
    }

    #[test]
    fn switch_ai_dev_tool_put_body_accepts_one() {
        let b: SwitchAiDevToolPutBody = serde_json::from_str(r#"{"value":"1"}"#).unwrap();
        assert_eq!(b.value, "1");
    }

    #[test]
    fn switch_ai_dev_tool_put_body_accepts_zero() {
        let b: SwitchAiDevToolPutBody = serde_json::from_str(r#"{"value":"0"}"#).unwrap();
        assert_eq!(b.value, "0");
    }

    #[test]
    fn switch_ai_dev_tool_response_serialize() {
        let resp = SwitchAiDevToolResponse {
            value: "1".to_string(),
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"value\":\"1\""));
    }
}
