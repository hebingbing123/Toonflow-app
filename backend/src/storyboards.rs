use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::json_patch::{parse_optional_i32_field, parse_optional_text_field, FieldPatch};
use crate::state::AppState;

#[derive(Debug, FromRow, Serialize)]
pub struct StoryboardRow {
    pub id: Uuid,
    pub script_id: Uuid,
    pub legacy_id: i32,
    pub legacy_script_id: Option<i32>,
    pub prompt: Option<String>,
    pub file_path: Option<String>,
    pub duration: Option<String>,
    pub state: Option<String>,
    pub track_id: Option<i32>,
    pub reason: Option<String>,
    pub track: Option<String>,
    pub video_desc: Option<String>,
    pub should_generate_image: Option<i32>,
    pub legacy_project_id: Option<i32>,
    pub flow_id: Option<i32>,
    pub sb_index: Option<i32>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct PatchStoryboardBody {
    #[serde(default)]
    prompt: Option<Value>,
    #[serde(default)]
    file_path: Option<Value>,
    #[serde(default)]
    duration: Option<Value>,
    #[serde(default)]
    state: Option<Value>,
    #[serde(default)]
    reason: Option<Value>,
    #[serde(default)]
    track: Option<Value>,
    #[serde(default)]
    video_desc: Option<Value>,
    #[serde(default)]
    legacy_script_id: Option<Value>,
    #[serde(default)]
    track_id: Option<Value>,
    #[serde(default)]
    should_generate_image: Option<Value>,
    #[serde(default)]
    legacy_project_id: Option<Value>,
    #[serde(default)]
    flow_id: Option<Value>,
    #[serde(default)]
    sb_index: Option<Value>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct CreateStoryboardBody {
    #[serde(default)]
    prompt: Option<String>,
    #[serde(default)]
    file_path: Option<String>,
    #[serde(default)]
    duration: Option<String>,
    #[serde(default)]
    state: Option<String>,
    #[serde(default)]
    track_id: Option<i32>,
    #[serde(default)]
    reason: Option<String>,
    #[serde(default)]
    track: Option<String>,
    #[serde(default)]
    video_desc: Option<String>,
    #[serde(default)]
    should_generate_image: Option<i32>,
    #[serde(default)]
    legacy_script_id: Option<i32>,
    #[serde(default)]
    legacy_project_id: Option<i32>,
    #[serde(default)]
    flow_id: Option<i32>,
    #[serde(default)]
    sb_index: Option<i32>,
}

const ADV_LOCK_STORYBOARD_LEGACY_ID: i64 = 884_422_003;

fn trim_opt_sb(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/scripts/legacy/{script_legacy_id}/storyboards",
            get(list_by_script_legacy).post(create_under_script_legacy),
        )
        .route(
            "/api/v1/storyboards/legacy/{legacy_id}",
            get(get_by_legacy)
                .patch(patch_by_legacy)
                .delete(delete_by_legacy),
        )
}

async fn create_under_script_legacy(
    State(state): State<AppState>,
    Path(script_legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<CreateStoryboardBody>,
) -> Result<(StatusCode, Json<StoryboardRow>), ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (script_uuid, project_legacy_id): (Uuid, i32) = sqlx::query_as(
        r#"
        SELECT s.id, p.legacy_id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE s.legacy_id = $1 AND p.owner_user_id = $2
        "#,
    )
    .bind(script_legacy_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_STORYBOARD_LEGACY_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0) + 1
        FROM app_storyboard
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let lsid = body.legacy_script_id.unwrap_or(script_legacy_id);
    let lpid = body.legacy_project_id.unwrap_or(project_legacy_id);

    let row = sqlx::query_as::<_, StoryboardRow>(
        r#"
        INSERT INTO app_storyboard (
          script_id, legacy_id,
          legacy_script_id, legacy_project_id,
          prompt, file_path, duration, state, track_id, reason, track, video_desc,
          should_generate_image, flow_id, sb_index, create_time_ms, metadata
        )
        VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, '{}'::jsonb
        )
        RETURNING
          id, script_id, legacy_id, legacy_script_id, prompt, file_path,
          duration, state, track_id, reason, track, video_desc,
          should_generate_image, legacy_project_id, flow_id, sb_index, create_time_ms
        "#,
    )
    .bind(script_uuid)
    .bind(next_legacy)
    .bind(lsid)
    .bind(lpid)
    .bind(trim_opt_sb(body.prompt))
    .bind(trim_opt_sb(body.file_path))
    .bind(trim_opt_sb(body.duration))
    .bind(trim_opt_sb(body.state))
    .bind(body.track_id)
    .bind(trim_opt_sb(body.reason))
    .bind(trim_opt_sb(body.track))
    .bind(trim_opt_sb(body.video_desc))
    .bind(body.should_generate_image)
    .bind(body.flow_id)
    .bind(body.sb_index)
    .bind(now_ms)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

async fn list_by_script_legacy(
    State(state): State<AppState>,
    Path(script_legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<Vec<StoryboardRow>>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let rows = sqlx::query_as::<_, StoryboardRow>(
        r#"
        SELECT
          sb.id, sb.script_id, sb.legacy_id, sb.legacy_script_id, sb.prompt, sb.file_path,
          sb.duration, sb.state, sb.track_id, sb.reason, sb.track, sb.video_desc,
          sb.should_generate_image, sb.legacy_project_id, sb.flow_id, sb.sb_index, sb.create_time_ms
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE sc.legacy_id = $1 AND p.owner_user_id = $2
        ORDER BY sb.sb_index ASC NULLS LAST, sb.legacy_id ASC
        "#,
    )
    .bind(script_legacy_id)
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}

async fn get_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<StoryboardRow>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let row = sqlx::query_as::<_, StoryboardRow>(
        r#"
        SELECT
          sb.id, sb.script_id, sb.legacy_id, sb.legacy_script_id, sb.prompt, sb.file_path,
          sb.duration, sb.state, sb.track_id, sb.reason, sb.track, sb.video_desc,
          sb.should_generate_image, sb.legacy_project_id, sb.flow_id, sb.sb_index, sb.create_time_ms
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE sb.legacy_id = $1 AND p.owner_user_id = $2
        "#,
    )
    .bind(legacy_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn patch_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<PatchStoryboardBody>,
) -> Result<Json<StoryboardRow>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let p_prompt = parse_optional_text_field(body.prompt, "prompt")?;
    let p_file = parse_optional_text_field(body.file_path, "file_path")?;
    let p_dur = parse_optional_text_field(body.duration, "duration")?;
    let p_state = parse_optional_text_field(body.state, "state")?;
    let p_reason = parse_optional_text_field(body.reason, "reason")?;
    let p_track = parse_optional_text_field(body.track, "track")?;
    let p_video = parse_optional_text_field(body.video_desc, "video_desc")?;
    let p_lsid = parse_optional_i32_field(body.legacy_script_id, "legacy_script_id")?;
    let p_tid = parse_optional_i32_field(body.track_id, "track_id")?;
    let p_sgi = parse_optional_i32_field(body.should_generate_image, "should_generate_image")?;
    let p_lpid = parse_optional_i32_field(body.legacy_project_id, "legacy_project_id")?;
    let p_fid = parse_optional_i32_field(body.flow_id, "flow_id")?;
    let p_sbi = parse_optional_i32_field(body.sb_index, "sb_index")?;

    if matches!(p_prompt, FieldPatch::Absent)
        && matches!(p_file, FieldPatch::Absent)
        && matches!(p_dur, FieldPatch::Absent)
        && matches!(p_state, FieldPatch::Absent)
        && matches!(p_reason, FieldPatch::Absent)
        && matches!(p_track, FieldPatch::Absent)
        && matches!(p_video, FieldPatch::Absent)
        && matches!(p_lsid, FieldPatch::Absent)
        && matches!(p_tid, FieldPatch::Absent)
        && matches!(p_sgi, FieldPatch::Absent)
        && matches!(p_lpid, FieldPatch::Absent)
        && matches!(p_fid, FieldPatch::Absent)
        && matches!(p_sbi, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one patchable field".into(),
        ));
    }

    let current = sqlx::query_as::<_, StoryboardRow>(
        r#"
        SELECT
          sb.id, sb.script_id, sb.legacy_id, sb.legacy_script_id, sb.prompt, sb.file_path,
          sb.duration, sb.state, sb.track_id, sb.reason, sb.track, sb.video_desc,
          sb.should_generate_image, sb.legacy_project_id, sb.flow_id, sb.sb_index, sb.create_time_ms
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE sb.legacy_id = $1 AND p.owner_user_id = $2
        "#,
    )
    .bind(legacy_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let merge_t = |patch: &FieldPatch<String>, cur: &Option<String>| -> Option<String> {
        match patch {
            FieldPatch::Absent => cur.clone(),
            FieldPatch::Set(v) => v.clone(),
        }
    };
    let merge_i = |patch: &FieldPatch<i32>, cur: Option<i32>| -> Option<i32> {
        match patch {
            FieldPatch::Absent => cur,
            FieldPatch::Set(v) => *v,
        }
    };

    let new_prompt = merge_t(&p_prompt, &current.prompt);
    let new_file = merge_t(&p_file, &current.file_path);
    let new_dur = merge_t(&p_dur, &current.duration);
    let new_state = merge_t(&p_state, &current.state);
    let new_reason = merge_t(&p_reason, &current.reason);
    let new_track = merge_t(&p_track, &current.track);
    let new_video = merge_t(&p_video, &current.video_desc);
    let new_lsid = merge_i(&p_lsid, current.legacy_script_id);
    let new_tid = merge_i(&p_tid, current.track_id);
    let new_sgi = merge_i(&p_sgi, current.should_generate_image);
    let new_lpid = merge_i(&p_lpid, current.legacy_project_id);
    let new_fid = merge_i(&p_fid, current.flow_id);
    let new_sbi = merge_i(&p_sbi, current.sb_index);

    let row = sqlx::query_as::<_, StoryboardRow>(
        r#"
        UPDATE app_storyboard
        SET
          prompt = $1,
          file_path = $2,
          duration = $3,
          state = $4,
          reason = $5,
          track = $6,
          video_desc = $7,
          legacy_script_id = $8,
          track_id = $9,
          should_generate_image = $10,
          legacy_project_id = $11,
          flow_id = $12,
          sb_index = $13,
          updated_at = NOW()
        WHERE id = $14
        RETURNING
          id, script_id, legacy_id, legacy_script_id, prompt, file_path,
          duration, state, track_id, reason, track, video_desc,
          should_generate_image, legacy_project_id, flow_id, sb_index, create_time_ms
        "#,
    )
    .bind(&new_prompt)
    .bind(&new_file)
    .bind(&new_dur)
    .bind(&new_state)
    .bind(&new_reason)
    .bind(&new_track)
    .bind(&new_video)
    .bind(new_lsid)
    .bind(new_tid)
    .bind(new_sgi)
    .bind(new_lpid)
    .bind(new_fid)
    .bind(new_sbi)
    .bind(current.id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}

async fn delete_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_storyboard sb
        USING app_script sc, app_project p
        WHERE sb.script_id = sc.id
          AND sc.project_id = p.id
          AND sb.legacy_id = $1
          AND p.owner_user_id = $2
        "#,
    )
    .bind(legacy_id)
    .bind(uid)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_storyboard_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<PatchStoryboardBody>(r#"{"prompt":"x","extra":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn create_storyboard_body_accepts_empty() {
        let b: CreateStoryboardBody = serde_json::from_str("{}").unwrap();
        assert!(b.prompt.is_none());
    }

    #[test]
    fn create_storyboard_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<CreateStoryboardBody>(r#"{"prompt":"a","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }
}
