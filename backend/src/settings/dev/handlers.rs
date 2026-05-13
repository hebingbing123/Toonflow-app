use axum::{
    extract::{Json, State},
    http::HeaderMap,
};

use crate::auth::require_user_uuid;
use crate::error::helpers::bad_request_i18n;
use crate::error::ApiError;
use crate::state::AppState;

use super::types::{SwitchAiDevToolPutBody, SwitchAiDevToolResponse};

#[utoipa::path(
    get,
    path = "/api/v1/settings/dev/switch-ai-tool",
    operation_id = "getSwitchAiDevToolV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_switch_ai_dev_tool(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<SwitchAiDevToolResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let value = state.switch_ai_dev_tool.read().await.clone();
    Ok(Json(SwitchAiDevToolResponse { value }))
}

#[utoipa::path(
    put,
    path = "/api/v1/settings/dev/switch-ai-tool",
    operation_id = "putSwitchAiDevToolV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn put_switch_ai_dev_tool(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SwitchAiDevToolPutBody>,
) -> Result<Json<SwitchAiDevToolResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let v = body.value.trim();
    if v != "0" && v != "1" {
        return Err(bad_request_i18n(
            "value must be \"0\" or \"1\"",
            "value 必须为 \"0\" 或 \"1\"",
        ));
    }
    let mut current = state.switch_ai_dev_tool.write().await;
    *current = v.to_string();
    Ok(Json(SwitchAiDevToolResponse {
        value: current.clone(),
    }))
}
