use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use super::common::{require_pool, require_positive_scope_ids, resolve_owned_storyboard_id};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct DownPreviewImageBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DownPreviewImageResponse {
    storyboard_id: i32,
    preview_url: Option<String>,
    message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/down-preview-image",
    operation_id = "postProductionStoryboardDownPreviewImageV1",
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
pub(in crate::production) async fn post_storyboard_down_preview_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DownPreviewImageBody>,
) -> Result<JsonResponse<DownPreviewImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;

    let pool = require_pool(&state)?;
    let storyboard_uuid = resolve_owned_storyboard_id(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

    let file_path: Option<String> =
        sqlx::query_scalar(r#"SELECT file_path FROM app_storyboard WHERE id = $1"#)
            .bind(storyboard_uuid)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if file_path.is_none() {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(DownPreviewImageResponse {
        storyboard_id: body.storyboard_id,
        preview_url: file_path,
        message: "Preview image URL retrieved",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct PreviewImageBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct PreviewImageResponse {
    storyboard_id: i32,
    image_url: Option<String>,
    prompt: Option<String>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/preview-image",
    operation_id = "postProductionStoryboardPreviewImageV1",
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
pub(in crate::production) async fn post_storyboard_preview_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PreviewImageBody>,
) -> Result<JsonResponse<PreviewImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;

    let pool = require_pool(&state)?;
    let storyboard_uuid = resolve_owned_storyboard_id(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

    let (file_path, prompt): (Option<String>, Option<String>) =
        sqlx::query_as(r#"SELECT file_path, prompt FROM app_storyboard WHERE id = $1"#)
            .bind(storyboard_uuid)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(PreviewImageResponse {
        storyboard_id: body.storyboard_id,
        image_url: file_path,
        prompt,
    }))
}
