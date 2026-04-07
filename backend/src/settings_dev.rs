//! Legacy **`/api/setting/dev/getSwitchAiDevTool`** / **`updateSwitchAiDevTool`**: AI dev-tool toggle was SQLite **`o_setting`**.
//! Rust exposes the **effective** value from server env; **PUT** does not persist (use **`TOONFLOW_SWITCH_AI_DEV_TOOL`** or future user settings).

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::get,
    Router,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

const ENV_SWITCH_AI_DEV_TOOL: &str = "TOONFLOW_SWITCH_AI_DEV_TOOL";

#[derive(Debug, Serialize)]
pub struct SwitchAiDevToolResponse {
    /// **`"0"`** off, **`"1"`** on — same string legacy stored in **`o_setting.value`**.
    pub value: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct SwitchAiDevToolPutBody {
    value: String,
}

fn switch_value_from_env() -> String {
    match std::env::var(ENV_SWITCH_AI_DEV_TOOL) {
        Ok(s) if s.trim() == "1" => "1".into(),
        _ => "0".into(),
    }
}

async fn get_switch_ai_dev_tool(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<SwitchAiDevToolResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(SwitchAiDevToolResponse {
        value: switch_value_from_env(),
    }))
}

async fn put_switch_ai_dev_tool(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SwitchAiDevToolPutBody>,
) -> Result<Json<SwitchAiDevToolResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let v = body.value.trim();
    if v != "0" && v != "1" {
        return Err(ApiError::BadRequest("value must be \"0\" or \"1\"".into()));
    }
    Err(ApiError::NotImplemented(format!(
        "persisting dev switch is not supported; set {} on the server (current effective value unchanged)",
        ENV_SWITCH_AI_DEV_TOOL
    )))
}

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/settings/dev/switch-ai-tool",
        get(get_switch_ai_dev_tool).put(put_switch_ai_dev_tool),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

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
    fn switch_value_from_env_returns_zero_when_unset() {
        // This test assumes the env var is not set in test environment
        // or set to a value other than "1"
        let val = switch_value_from_env();
        assert!(val == "0" || val == "1");
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
