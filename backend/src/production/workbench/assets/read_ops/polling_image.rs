use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use crate::error::ApiError;
use crate::state::AppState;

use super::super::common::require_owned_normalized_assets_scope_ref;
use super::types::{AssetImageStatus, AssetsPollingImageBody, AssetsPollingImageResponse};

#[utoipa::path(
    post,
    path = "/api/v1/production/assets/polling-image",
    operation_id = "postProductionAssetsPollingImageV1",
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
pub(in crate::production) async fn post_assets_polling_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AssetsPollingImageBody>,
) -> Result<JsonResponse<AssetsPollingImageResponse>, ApiError> {
    let (uid, pool, project_numeric_id, script_id, uniq) =
        require_owned_normalized_assets_scope_ref(
            &state,
            &headers,
            body.project_id,
            body.project_uuid,
            body.script_id,
            &body.asset_ids,
        )
        .await?;

    let statuses = sqlx::query_as::<_, AssetImageStatus>(
        r#"
        SELECT
          a.numeric_id AS asset_id,
          COUNT(ai.id) AS image_count,
          MAX(ai.state) AS latest_state
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $1
        LEFT JOIN app_asset_image ai ON ai.asset_id = a.id
        WHERE p.numeric_id = $3
          AND a.numeric_id = ANY($4::int4[])
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $2
          )
        GROUP BY a.numeric_id
        ORDER BY array_position($4::int4[], a.numeric_id)
        "#,
    )
    .bind(script_id)
    .bind(uid)
    .bind(project_numeric_id)
    .bind(&uniq)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if statuses.len() != uniq.len() {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(AssetsPollingImageResponse { statuses }))
}
