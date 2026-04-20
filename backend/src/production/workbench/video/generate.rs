use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::{IntoResponse, Response},
};

use super::WorkbenchGenerateVideoBody;
use crate::error::ApiError;
use crate::scope::http::require_owned_numeric_script_scope;
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/generate-video",
    operation_id = "postProductionWorkbenchGenerateVideoV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_generate_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchGenerateVideoBody>,
) -> Result<Response, ApiError> {
    if body.track_id <= 0 {
        return Err(ApiError::BadRequest(
            "trackId must be a positive integer".into(),
        ));
    }

    require_owned_numeric_script_scope(&state, &headers, body.project_id, body.script_id).await?;

    Ok(axum::http::StatusCode::OK.into_response())
}
