use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::super::storyboard_ops::{ProductionGetProductionDataResponse, ProductionStoryboardItem};
use super::common::{
    build_storyboard_data_response, fetch_storyboard_item, list_storyboard_items_by_script,
    StoryboardScopeBody, StoryboardScriptScopeBody,
};
use crate::error::ApiError;
use crate::scope::http::{
    require_owned_numeric_script_scope_row, require_owned_numeric_storyboard_scope,
};
use crate::state::AppState;

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
    Json(body): Json<StoryboardScopeBody>,
) -> Result<JsonResponse<ProductionStoryboardItem>, ApiError> {
    let (pool, sb_uuid) = require_owned_numeric_storyboard_scope(
        &state,
        &headers,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    let row = fetch_storyboard_item(pool, sb_uuid).await?;

    Ok(JsonResponse(row))
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
    Json(body): Json<StoryboardScriptScopeBody>,
) -> Result<JsonResponse<ProductionGetProductionDataResponse>, ApiError> {
    let (pool, scope_row) =
        require_owned_numeric_script_scope_row(&state, &headers, body.project_id, body.script_id)
            .await?;

    let rows = list_storyboard_items_by_script(pool, scope_row.script_id).await?;

    Ok(JsonResponse(build_storyboard_data_response(rows)))
}
