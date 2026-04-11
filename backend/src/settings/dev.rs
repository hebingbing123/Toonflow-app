//! Legacy **`/api/setting/dev/getSwitchAiDevTool`** / **`updateSwitchAiDevTool`**: AI dev-tool toggle was SQLite **`o_setting`**.
//! Rust keeps a process-local override with env bootstrap; restart falls back to **`TOONFLOW_SWITCH_AI_DEV_TOOL`**.

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

async fn get_switch_ai_dev_tool(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<SwitchAiDevToolResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let value = state.switch_ai_dev_tool.read().await.clone();
    Ok(Json(SwitchAiDevToolResponse { value }))
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
    let mut current = state.switch_ai_dev_tool.write().await;
    *current = v.to_string();
    Ok(Json(SwitchAiDevToolResponse {
        value: current.clone(),
    }))
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
    fn switch_ai_dev_tool_response_serialize() {
        let resp = SwitchAiDevToolResponse {
            value: "1".to_string(),
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"value\":\"1\""));
    }
}
