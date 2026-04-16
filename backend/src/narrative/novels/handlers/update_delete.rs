use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::state::AppState;

use super::super::dto::{NovelRow, PatchNovelBody};

async fn patch_novel_inner(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    novel_numeric_id: i32,
    body: PatchNovelBody,
) -> Result<Json<NovelRow>, ApiError> {
    if novel_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    let idx_patch = parse_optional_i32_field(body.chapter_index, "chapter_index")?;
    let reel_patch = parse_optional_text_field(body.reel, "reel")?;
    let chapter_patch = parse_optional_text_field(body.chapter, "chapter")?;
    let data_patch = parse_optional_text_field(body.chapter_data, "chapter_data")?;
    let event_patch = parse_optional_text_field(body.event, "event")?;
    let state_patch = parse_optional_i32_field(body.event_state, "event_state")?;
    let err_patch = parse_optional_text_field(body.error_reason, "error_reason")?;

    if matches!(idx_patch, FieldPatch::Absent)
        && matches!(reel_patch, FieldPatch::Absent)
        && matches!(chapter_patch, FieldPatch::Absent)
        && matches!(data_patch, FieldPatch::Absent)
        && matches!(event_patch, FieldPatch::Absent)
        && matches!(state_patch, FieldPatch::Absent)
        && matches!(err_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one patch field".into(),
        ));
    }

    let current = sqlx::query_as::<_, NovelRow>(
        r#"
        SELECT n.id, n.numeric_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
               n.event, n.event_state, n.error_reason, n.create_time_ms
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.id = $1
          AND p.owner_user_id = $2
          AND n.numeric_id = $3
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(novel_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let new_idx = match &idx_patch {
        FieldPatch::Absent => current.chapter_index,
        FieldPatch::Set(None) => {
            return Err(ApiError::BadRequest(
                "chapter_index cannot be null; omit or set a number".into(),
            ));
        }
        FieldPatch::Set(Some(v)) => *v,
    };

    let new_reel = match &reel_patch {
        FieldPatch::Absent => current.reel.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_chapter = match &chapter_patch {
        FieldPatch::Absent => current.chapter.clone(),
        FieldPatch::Set(None) => String::new(),
        FieldPatch::Set(Some(s)) => s.clone(),
    };

    let new_data = match &data_patch {
        FieldPatch::Absent => current.chapter_data.clone(),
        FieldPatch::Set(None) => String::new(),
        FieldPatch::Set(Some(s)) => s.clone(),
    };

    let new_event = match &event_patch {
        FieldPatch::Absent => current.event.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_state = match &state_patch {
        FieldPatch::Absent => current.event_state,
        FieldPatch::Set(None) => {
            return Err(ApiError::BadRequest(
                "event_state cannot be null; omit or set a number".into(),
            ));
        }
        FieldPatch::Set(Some(v)) => *v,
    };

    let new_err = match &err_patch {
        FieldPatch::Absent => current.error_reason.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let row = sqlx::query_as::<_, NovelRow>(
        r#"
        UPDATE app_novel n
        SET chapter_index = $1, reel = $2, chapter = $3, chapter_data = $4,
            event = $5, event_state = $6, error_reason = $7, updated_at = NOW()
        FROM app_project p
        WHERE n.project_id = p.id
          AND p.id = $8
          AND p.owner_user_id = $9
          AND n.numeric_id = $10
        RETURNING n.id, n.numeric_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
                  n.event, n.event_state, n.error_reason, n.create_time_ms
        "#,
    )
    .bind(new_idx)
    .bind(new_reel.as_ref())
    .bind(&new_chapter)
    .bind(&new_data)
    .bind(new_event.as_ref())
    .bind(new_state)
    .bind(new_err.as_ref())
    .bind(project_id)
    .bind(uid)
    .bind(novel_numeric_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}

pub(crate) async fn patch_novel_for_project(
    State(state): State<AppState>,
    Path((project_id, novel_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchNovelBody>,
) -> Result<Json<NovelRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    patch_novel_inner(pool, uid, project_id, novel_numeric_id, body).await
}

async fn delete_novel_inner(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    novel_numeric_id: i32,
) -> Result<StatusCode, ApiError> {
    if novel_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    let res = sqlx::query(
        r#"
        DELETE FROM app_novel n
        USING app_project p
        WHERE n.project_id = p.id
          AND p.id = $1
          AND p.owner_user_id = $2
          AND n.numeric_id = $3
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(novel_numeric_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

pub(crate) async fn delete_novel_for_project(
    State(state): State<AppState>,
    Path((project_id, novel_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    delete_novel_inner(pool, uid, project_id, novel_numeric_id).await
}
