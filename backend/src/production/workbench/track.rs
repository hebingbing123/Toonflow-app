use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope;
use crate::state::AppState;

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

pub(in crate::production) async fn post_workbench_add_track(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddTrackBody>,
) -> Result<JsonResponse<AddTrackResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    if body.track_name.trim().is_empty() {
        return Err(ApiError::BadRequest("trackName must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;
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

pub(in crate::production) async fn post_workbench_delete_track(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteTrackBody>,
) -> Result<JsonResponse<DeleteTrackResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 || body.track_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId, scriptId, and trackId must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

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

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct DeleteVideoBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DeleteVideoResponse {
    storyboard_id: i32,
    message: &'static str,
}

pub(in crate::production) async fn post_workbench_delete_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteVideoBody>,
) -> Result<JsonResponse<DeleteVideoResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 || body.storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId, scriptId, and storyboardId must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = NULL, state = NULL, updated_at = NOW()
        WHERE script_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(scope_row.script_id)
    .bind(body.storyboard_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(DeleteVideoResponse {
        storyboard_id: body.storyboard_id,
        message: "Video deleted from storyboard",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct SelectVideoBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    video_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct SelectVideoResponse {
    storyboard_id: i32,
    video_url: String,
    message: &'static str,
}

pub(in crate::production) async fn post_workbench_select_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SelectVideoBody>,
) -> Result<JsonResponse<SelectVideoResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 || body.storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId, scriptId, and storyboardId must be positive integers".into(),
        ));
    }
    if body.video_url.trim().is_empty() {
        return Err(ApiError::BadRequest("videoUrl must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $3, state = '已完成', updated_at = NOW()
        WHERE script_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(scope_row.script_id)
    .bind(body.storyboard_id)
    .bind(body.video_url.trim())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(SelectVideoResponse {
        storyboard_id: body.storyboard_id,
        video_url: body.video_url.trim().to_string(),
        message: "Video selected for storyboard",
    }))
}
