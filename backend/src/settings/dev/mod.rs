//! 开发者设置模块。
//!
//! 遗留 `/api/setting/dev/getSwitchAiDevTool` / `updateSwitchAiDevTool`：AI 开发工具切换曾是 SQLite `o_setting`。
//! Rust 保持进程本地覆盖，环境引导；重启回退到 `OPENFLOW_SWITCH_AI_DEV_TOOL`。

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
    use crate::error::helpers::bad_request_i18n;
    use crate::error::locale::{ApiLocale, REQUEST_LOCALE};
    use crate::error::ApiError;
    use axum::body::to_bytes;
    use axum::response::IntoResponse;

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

    #[test]
    fn switch_ai_dev_tool_invalid_value_error_creates_correct_variant() {
        let err = bad_request_i18n(
            "value must be \"0\" or \"1\"",
            "value 必须为 \"0\" 或 \"1\"",
        );
        match err {
            ApiError::BadRequest(msg) => {
                assert!(
                    msg == "value must be \"0\" or \"1\"" || msg == "value 必须为 \"0\" 或 \"1\""
                );
            }
            _ => panic!("expected BadRequest variant"),
        }
    }

    #[tokio::test]
    async fn switch_ai_dev_tool_invalid_value_error_response_en() {
        let err = bad_request_i18n(
            "value must be \"0\" or \"1\"",
            "value 必须为 \"0\" 或 \"1\"",
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("value must be \"0\" or \"1\"")
        );
    }

    #[tokio::test]
    async fn switch_ai_dev_tool_invalid_value_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = bad_request_i18n(
                    "value must be \"0\" or \"1\"",
                    "value 必须为 \"0\" 或 \"1\"",
                );
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("value 必须为 \"0\" 或 \"1\"")
        );
    }
}
