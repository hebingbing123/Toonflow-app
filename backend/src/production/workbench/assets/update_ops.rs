use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::{bad_request_i18n, validate_non_empty_string, ApiError};
use crate::state::AppState;

use crate::scope::http::require_script_write_scope_ref;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct UpdateAssetsUrlBody {
    #[serde(default)]
    project_id: Option<i32>,
    #[serde(default)]
    project_uuid: Option<Uuid>,
    script_id: i32,
    asset_id: i32,
    image_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateAssetsUrlResponse {
    asset_id: i32,
    image_url: String,
    message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/assets/update-assets-url",
    operation_id = "postProductionAssetsUpdateUrlV1",
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
pub(in crate::production) async fn post_assets_update_url(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateAssetsUrlBody>,
) -> Result<JsonResponse<UpdateAssetsUrlResponse>, ApiError> {
    if body.asset_id <= 0 {
        return Err(bad_request_i18n(
            "projectId, scriptId, and assetId must be positive integers",
            "projectId、scriptId 和 assetId 必须是正整数",
        ));
    }
    validate_non_empty_string(body.image_url.trim(), "imageUrl")?;

    let (uid, pool, scope_row) = require_script_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
    )
    .await?;

    let image_id = sqlx::query_scalar::<_, uuid::Uuid>(
        r#"
        INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
        SELECT $5, a.id, COALESCE(MAX(ai.sort_index), 0) + 1, $6, '已完成', '{}'::jsonb
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $1
        LEFT JOIN app_asset_image ai ON ai.asset_id = a.id
        WHERE p.numeric_id = $3
          AND a.numeric_id = $4
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $2
          )
        GROUP BY a.id
        RETURNING id
        "#,
    )
    .bind(scope_row.script_id)
    .bind(uid)
    .bind(scope_row.project_numeric_id)
    .bind(body.asset_id)
    .bind(uuid::Uuid::new_v4())
    .bind(body.image_url.trim())
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if image_id.is_none() {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(UpdateAssetsUrlResponse {
        asset_id: body.asset_id,
        image_url: body.image_url.trim().to_string(),
        message: "Asset image URL updated",
    }))
}
