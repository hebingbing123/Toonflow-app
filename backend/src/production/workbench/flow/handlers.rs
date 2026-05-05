//! 制作流程加载与保存 HTTP 处理器。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::{IntoResponse, Response},
    Json as JsonResponse,
};
use serde_json::Value;

use crate::error::ApiError;
use crate::production::flow_data::load_production_flow_json_by_scope;
use crate::scope::http::require_owned_numeric_production_episodes_scope_row;
use crate::state::AppState;

use super::storyboard_order::ordered_storyboard_numeric_ids;
use super::types::{GetFlowDataBody, SaveFlowDataBody};

#[utoipa::path(
    post,
    path = "/api/v1/production/get-flow-data",
    operation_id = "postProductionGetFlowDataV1",
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
pub(crate) async fn post_get_flow_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetFlowDataBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let (pool, project_id, script_id, script_content) =
        require_owned_numeric_production_episodes_scope_row(
            &state,
            &headers,
            body.project_id,
            body.episodes_id,
        )
        .await?;
    let flow =
        load_production_flow_json_by_scope(pool, project_id, script_id, script_content).await?;
    Ok(JsonResponse(flow))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/save-flow-data",
    operation_id = "postProductionSaveFlowDataV1",
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
pub(crate) async fn post_save_flow_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SaveFlowDataBody>,
) -> Result<Response, ApiError> {
    let ordered_storyboard_ids = ordered_storyboard_numeric_ids(&body.data)?;

    let (pool, project_id, script_id, _script_content) =
        require_owned_numeric_production_episodes_scope_row(
            &state,
            &headers,
            body.project_id,
            body.episodes_id,
        )
        .await?;

    // Version conflict detection: if flowVersion is provided, check current version
    if let Some(ref expected_version) = body.flow_version {
        let current_version: Option<String> = sqlx::query_scalar(
            r#"
            SELECT updated_at::text
            FROM app_production_flow
            WHERE project_id = $1 AND script_id = $2
            "#,
        )
        .bind(project_id)
        .bind(script_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if let Some(current) = current_version {
            if &current != expected_version {
                return Err(ApiError::ConflictWithDetails {
                    message: "Timeline has been modified by another user or session".to_string(),
                    details: serde_json::json!({
                        "expected_version": expected_version,
                        "current_version": current,
                        "conflict_type": "version_mismatch"
                    }),
                });
            }
        } else {
            // No existing flow record - if client provided a version, it's stale
            return Err(ApiError::ConflictWithDetails {
                message: "Timeline has been modified (no existing flow record)".to_string(),
                details: serde_json::json!({
                    "expected_version": expected_version,
                    "current_version": null,
                    "conflict_type": "missing_record"
                }),
            });
        }
    }

    if let Some(ordered_ids) = ordered_storyboard_ids {
        for (index, storyboard_numeric_id) in ordered_ids.iter().enumerate() {
            sqlx::query(
                r#"
                UPDATE app_storyboard
                SET sb_index = $3, updated_at = NOW()
                WHERE script_id = $1
                  AND numeric_id = $2
                "#,
            )
            .bind(script_id)
            .bind(storyboard_numeric_id)
            .bind(index as i32)
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }
    }

    sqlx::query(
        r#"
        INSERT INTO app_production_flow (project_id, script_id, flow_data)
        VALUES ($1, $2, $3)
        ON CONFLICT (project_id, script_id) DO UPDATE
        SET flow_data = EXCLUDED.flow_data,
            updated_at = NOW()
        "#,
    )
    .bind(project_id)
    .bind(script_id)
    .bind(&body.data)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(axum::http::StatusCode::OK.into_response())
}
