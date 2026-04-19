use axum::{
    extract::{Json, State},
    http::HeaderMap,
};
use chrono::Utc;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::resolve::resolve_check_update_response;
use super::types::{CheckUpdateBody, CheckUpdateResponse};

#[utoipa::path(
    post,
    path = "/api/v1/settings/about/check-update",
    operation_id = "postAboutCheckUpdateV1",
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
pub(crate) async fn post_check_update(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CheckUpdateBody>,
) -> Result<Json<CheckUpdateResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(resolve_check_update_response(body.source, Utc::now())))
}
