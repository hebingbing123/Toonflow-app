use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::Deserialize;

use super::super::storyboard_ops::{ProductionGetProductionDataResponse, ProductionStoryboardItem};
use super::common::{
    require_pool, require_positive_project_script, require_positive_scope_ids,
    resolve_owned_script_id, resolve_owned_storyboard_id,
};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GetStoryboardDataBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/get-data",
    operation_id = "postProductionStoryboardGetDataV1",
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
pub(in crate::production) async fn post_storyboard_get_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetStoryboardDataBody>,
) -> Result<JsonResponse<ProductionStoryboardItem>, ApiError> {
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

    let row = sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index
        FROM app_storyboard sb
        WHERE sb.id = $1
        "#,
    )
    .bind(storyboard_uuid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(JsonResponse(row))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GetStoryboardDataByProjectBody {
    project_id: i32,
    script_id: i32,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/get-storyboard-data",
    operation_id = "postProductionGetStoryboardDataV1",
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
pub(in crate::production) async fn post_get_storyboard_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetStoryboardDataByProjectBody>,
) -> Result<JsonResponse<ProductionGetProductionDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_project_script(body.project_id, body.script_id)?;

    let pool = require_pool(&state)?;
    let script_uuid = resolve_owned_script_id(pool, uid, body.project_id, body.script_id).await?;

    let rows = sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index
        FROM app_storyboard sb
        WHERE sb.script_id = $1
        ORDER BY sb.sb_index ASC
        "#,
    )
    .bind(script_uuid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(ProductionGetProductionDataResponse {
        data: rows,
    }))
}
