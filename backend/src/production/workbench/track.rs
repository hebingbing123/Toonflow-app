use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

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

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (project_uuid, script_uuid): (uuid::Uuid, uuid::Uuid) = sqlx::query_as(
        r#"
        SELECT p.id, s.id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let next_track_id: i32 = sqlx::query_scalar(
        r#"
        SELECT GREATEST(
          COALESCE((
            SELECT MAX(sb.track_id)
            FROM app_storyboard sb
            WHERE sb.script_id = $1
          ), 0),
          COALESCE((
            SELECT MAX(vt.legacy_id)
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
          project_id, script_id, legacy_id, state, prompt, metadata
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

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let deleted_track = sqlx::query(
        r#"
        DELETE FROM app_video_track vt
        USING app_project p
        WHERE vt.project_id = p.id
          AND p.owner_user_id = $1
          AND p.legacy_id = $2
          AND (vt.script_id IS NULL OR EXISTS (
            SELECT 1
            FROM app_script s
            WHERE s.id = vt.script_id
              AND s.legacy_id = $3
          ))
          AND vt.legacy_id = $4
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
    .bind(body.track_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET track_id = NULL, updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $1
          AND app_project.legacy_id = $2
          AND app_script.legacy_id = $3
          AND app_storyboard.track_id = $4
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
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

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = NULL, state = NULL, updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $1
          AND app_project.legacy_id = $2
          AND app_script.legacy_id = $3
          AND app_storyboard.legacy_id = $4
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
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

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $5, state = '已完成', updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $1
          AND app_project.legacy_id = $2
          AND app_script.legacy_id = $3
          AND app_storyboard.legacy_id = $4
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
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
