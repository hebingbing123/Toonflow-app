use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::error::ApiError;
use crate::state::AppState;

use super::common::require_owned_script_scope;

/// Serializes `GREATEST(MAX storyboard.track_id, MAX app_video_track.numeric_id)+1` allocation for a script/project pair.
const ADV_LOCK_WORKBENCH_TRACK_SLOT: i64 = 884_422_009;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct AddTrackBody {
    project_id: i32,
    script_id: i32,
    track_name: String,
    #[serde(default)]
    #[allow(dead_code)]
    track_type: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AddTrackResponse {
    track_id: i32,
    track_name: String,
    message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/add-track",
    operation_id = "postProductionWorkbenchAddTrackV1",
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
pub(in crate::production) async fn post_workbench_add_track(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddTrackBody>,
) -> Result<JsonResponse<AddTrackResponse>, ApiError> {
    if body.track_name.trim().is_empty() {
        return Err(ApiError::BadRequest("trackName must not be empty".into()));
    }

    let (_uid, pool, scope_row) =
        require_owned_script_scope(&state, &headers, body.project_id, body.script_id).await?;
    let project_uuid = scope_row.project_id;
    let script_uuid = scope_row.script_id;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_WORKBENCH_TRACK_SLOT)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_track_id: i32 = sqlx::query_scalar(
        r#"
        SELECT GREATEST(
          COALESCE((
            SELECT MAX(sb.track_id)
            FROM app_storyboard sb
            WHERE sb.script_id = $1
          ), 0),
          COALESCE((
            SELECT MAX(vt.numeric_id)
            FROM app_video_track vt
            WHERE vt.project_id = $2
              AND (vt.script_id = $1 OR vt.script_id IS NULL)
          ), 0)
        ) + 1
        "#,
    )
    .bind(script_uuid)
    .bind(project_uuid)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_video_track (
          project_id, script_id, numeric_id, state, prompt, metadata
        )
        VALUES ($1, $2, $3, 'draft', $4, jsonb_build_object('track_name', $4))
        "#,
    )
    .bind(project_uuid)
    .bind(script_uuid)
    .bind(next_track_id)
    .bind(body.track_name.trim())
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(AddTrackResponse {
        track_id: next_track_id,
        track_name: body.track_name.trim().to_string(),
        message: "Track added",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct DeleteTrackBody {
    project_id: i32,
    script_id: i32,
    track_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DeleteTrackResponse {
    track_id: i32,
    message: &'static str,
}

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
    super::common::validate_positive_id("trackId", body.track_id)?;
    let (_uid, pool, scope_row) =
        require_owned_script_scope(&state, &headers, body.project_id, body.script_id).await?;

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
