use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use crate::error::ApiError;
use crate::state::AppState;

use super::types::{AssetDataItem, AssetsDataResponse, GetAssetsDataBody};
use crate::scope::http::require_owned_numeric_script_scope;

#[utoipa::path(
    post,
    path = "/api/v1/production/assets/get-assets-data",
    operation_id = "postProductionAssetsGetAssetsDataV1",
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
pub(in crate::production) async fn post_assets_get_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetAssetsDataBody>,
) -> Result<JsonResponse<AssetsDataResponse>, ApiError> {
    let (uid, pool, scope_row) =
        require_owned_numeric_script_scope(&state, &headers, body.project_id, body.script_id)
            .await?;

    let limit = body.limit.map(|l| l.clamp(1, 100)).unwrap_or(50);
    let offset = body.offset.unwrap_or(0).max(0);
    let asset_type = body
        .asset_type
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty());

    let assets = sqlx::query_as::<_, AssetDataItem>(
        r#"
        SELECT
          a.numeric_id AS id,
          a.name,
          a.asset_type AS "type",
          a.describe,
          a.cover_numeric_image_id,
          a.created_at
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $3
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND ($4::text IS NULL OR a.asset_type = $4)
        ORDER BY a.created_at DESC
        LIMIT $5 OFFSET $6
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(scope_row.script_id)
    .bind(asset_type)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $3
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND ($4::text IS NULL OR a.asset_type = $4)
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(scope_row.script_id)
    .bind(asset_type)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(AssetsDataResponse { assets, total }))
}
