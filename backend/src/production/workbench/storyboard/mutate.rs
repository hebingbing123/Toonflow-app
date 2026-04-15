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
pub(in crate::production) struct EditStoryboardInfoBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct EditStoryboardInfoResponse {
    storyboard_id: i32,
    message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/edit-info",
    operation_id = "postProductionStoryboardEditInfoV1",
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
pub(in crate::production) async fn post_storyboard_edit_info(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditStoryboardInfoBody>,
) -> Result<JsonResponse<EditStoryboardInfoResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }

    let pool = require_pool(&state)?;
    let storyboard_uuid = resolve_owned_storyboard_id(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET prompt = $2, duration = $3, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_uuid)
    .bind(body.prompt.trim())
    .bind(body.duration)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(EditStoryboardInfoResponse {
        storyboard_id: body.storyboard_id,
        message: "Storyboard info updated",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct RemoveFrameBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct RemoveFrameResponse {
    storyboard_id: i32,
    message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/remove-frame",
    operation_id = "postProductionStoryboardRemoveFrameV1",
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
pub(in crate::production) async fn post_storyboard_remove_frame(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<RemoveFrameBody>,
) -> Result<JsonResponse<RemoveFrameResponse>, ApiError> {
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

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = NULL, state = NULL, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_uuid)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(RemoveFrameResponse {
        storyboard_id: body.storyboard_id,
        message: "Frame removed from storyboard",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct UpdateStoryboardUrlBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    image_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateStoryboardUrlResponse {
    storyboard_id: i32,
    image_url: String,
    message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/update-url",
    operation_id = "postProductionStoryboardUpdateUrlV1",
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
pub(in crate::production) async fn post_storyboard_update_url(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateStoryboardUrlBody>,
) -> Result<JsonResponse<UpdateStoryboardUrlResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;
    if body.image_url.trim().is_empty() {
        return Err(ApiError::BadRequest("imageUrl must not be empty".into()));
    }

    let pool = require_pool(&state)?;
    let storyboard_uuid = resolve_owned_storyboard_id(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $2, state = '已完成', updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_uuid)
    .bind(body.image_url.trim())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(UpdateStoryboardUrlResponse {
        storyboard_id: body.storyboard_id,
        image_url: body.image_url.trim().to_string(),
        message: "Storyboard image URL updated",
    }))
}
