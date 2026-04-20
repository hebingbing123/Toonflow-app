//! 删除视频轨。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::super::super::common::validate_positive_id;
use super::super::types::{DeleteTrackBody, DeleteTrackResponse};
use crate::error::ApiError;
use crate::scope::http::require_owned_numeric_script_scope_row;
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/delete-track",
    operation_id = "postProductionWorkbenchDeleteTrackV1",
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
pub(in crate::production) async fn post_workbench_delete_track(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteTrackBody>,
) -> Result<JsonResponse<DeleteTrackResponse>, ApiError> {
    validate_positive_id("trackId", body.track_id)?;
    let (pool, scope_row) =
        require_owned_numeric_script_scope_row(&state, &headers, body.project_id, body.script_id)
            .await?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let deleted_track = sqlx::query(
        r#"
        DELETE FROM app_video_track vt
        WHERE vt.project_id = $1
          AND vt.script_id = $2
          AND vt.numeric_id = $3
        "#,
    )
    .bind(scope_row.project_id)
    .bind(scope_row.script_id)
    .bind(body.track_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET track_id = NULL, updated_at = NOW()
        WHERE script_id = $1
          AND track_id = $2
        "#,
    )
    .bind(scope_row.script_id)
    .bind(body.track_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if deleted_track.rows_affected() == 0 && updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(DeleteTrackResponse {
        track_id: body.track_id,
        message: "Track deleted",
    }))
}
