//! 分镜 HTTP 处理器。
//!
//! 分镜 CRUD 和脚本关联管理。

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::state::AppState;

use super::dto::{CreateStoryboardBody, PatchStoryboardBody, StoryboardRow};
use super::ADV_LOCK_STORYBOARD_LEGACY_ID;

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

async fn create_storyboard_locked(
    tx: &mut Transaction<'_, Postgres>,
    script_uuid: Uuid,
    project_legacy_id: i32,
    path_script_numeric_id: i32,
    body: CreateStoryboardBody,
) -> Result<StoryboardRow, ApiError> {
    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_STORYBOARD_LEGACY_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0) + 1
        FROM app_storyboard
        "#,
    )
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let lsid = body.legacy_script_id.unwrap_or(path_script_numeric_id);
    let lpid = body.legacy_project_id.unwrap_or(project_legacy_id);

    sqlx::query_as::<_, StoryboardRow>(
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
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn list_by_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<Vec<StoryboardRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let rows = sqlx::query_as::<_, StoryboardRow>(
        r#"
        SELECT
          sb.id, sb.script_id, sb.legacy_id, sb.legacy_script_id, sb.prompt, sb.file_path,
          sb.duration, sb.state, sb.track_id, sb.reason, sb.track, sb.video_desc,
          sb.should_generate_image, sb.legacy_project_id, sb.flow_id, sb.sb_index, sb.create_time_ms
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.id = $1 AND sc.legacy_id = $2 AND p.owner_user_id = $3
        ORDER BY sb.sb_index ASC NULLS LAST, sb.legacy_id ASC
        "#,
    )
    .bind(project_id)
    .bind(script_numeric_id)
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}

pub(super) async fn create_under_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<CreateStoryboardBody>,
) -> Result<(StatusCode, Json<StoryboardRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (script_uuid, project_legacy_id): (Uuid, i32) = sqlx::query_as(
        r#"
        SELECT s.id, p.legacy_id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.id = $1 AND s.legacy_id = $2 AND p.owner_user_id = $3
        "#,
    )
    .bind(project_id)
    .bind(script_numeric_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let row = create_storyboard_locked(
        &mut tx,
        script_uuid,
        project_legacy_id,
        script_numeric_id,
        body,
    )
    .await?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

pub(super) async fn get_by_legacy_for_project(
    State(state): State<AppState>,
    Path((project_id, storyboard_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<StoryboardRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let row = sqlx::query_as::<_, StoryboardRow>(
        r#"
        SELECT
          sb.id, sb.script_id, sb.legacy_id, sb.legacy_script_id, sb.prompt, sb.file_path,
          sb.duration, sb.state, sb.track_id, sb.reason, sb.track, sb.video_desc,
          sb.should_generate_image, sb.legacy_project_id, sb.flow_id, sb.sb_index, sb.create_time_ms
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE sb.legacy_id = $1 AND p.id = $2 AND p.owner_user_id = $3
        "#,
    )
    .bind(storyboard_numeric_id)
    .bind(project_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn patch_storyboard_row(
    pool: &PgPool,
    uid: Uuid,
    legacy_id: i32,
    body: PatchStoryboardBody,
    project_id: Uuid,
) -> Result<Json<StoryboardRow>, ApiError> {
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
        WHERE sb.legacy_id = $1 AND p.id = $2 AND p.owner_user_id = $3
        "#,
    )
    .bind(legacy_id)
    .bind(project_id)
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

pub(super) async fn patch_by_legacy_for_project(
    State(state): State<AppState>,
    Path((project_id, storyboard_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchStoryboardBody>,
) -> Result<Json<StoryboardRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    patch_storyboard_row(pool, uid, storyboard_numeric_id, body, project_id).await
}

async fn delete_storyboard_row(
    pool: &PgPool,
    uid: Uuid,
    legacy_id: i32,
    project_id: Uuid,
) -> Result<StatusCode, ApiError> {
    let res = sqlx::query(
        r#"
            DELETE FROM app_storyboard sb
            USING app_script sc, app_project p
            WHERE sb.script_id = sc.id
              AND sc.project_id = p.id
              AND sb.legacy_id = $1
              AND p.owner_user_id = $2
              AND p.id = $3
            "#,
    )
    .bind(legacy_id)
    .bind(uid)
    .bind(project_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

pub(super) async fn delete_by_legacy_for_project(
    State(state): State<AppState>,
    Path((project_id, storyboard_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    delete_storyboard_row(pool, uid, storyboard_numeric_id, project_id).await
}
