//! 小说 HTTP 处理器。
//!
//! 小说 CRUD 和分页列表查询。

use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use sqlx::{PgPool, Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::state::AppState;

use super::dto::{CreateNovelBody, ListNovelsQuery, ListNovelsResponse, NovelRow, PatchNovelBody};
use super::{ADV_LOCK_NOVEL_LEGACY, MAX_NOVEL_LIST_LIMIT};

fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

fn search_ilike(raw: Option<String>) -> Option<String> {
    raw.and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(format!("%{t}%"))
        }
    })
}

async fn count_novels_filtered(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    search_pat: Option<&str>,
) -> Result<i64, ApiError> {
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT COUNT(*)::BIGINT
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(project_legacy_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_pat {
        qb.push(" AND n.chapter ILIKE ");
        qb.push_bind(pat);
    }
    let total: i64 = qb
        .build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(total)
}

async fn select_novels_filtered(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    search_pat: Option<&str>,
    limit_offset: Option<(i64, i64)>,
) -> Result<Vec<NovelRow>, ApiError> {
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT n.id, n.legacy_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
               n.event, n.event_state, n.error_reason, n.create_time_ms
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(project_legacy_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_pat {
        qb.push(" AND n.chapter ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(" ORDER BY n.chapter_index ASC, n.legacy_id ASC ");
    if let Some((lim, off)) = limit_offset {
        qb.push(" LIMIT ");
        qb.push_bind(lim);
        qb.push(" OFFSET ");
        qb.push_bind(off);
    }
    qb.build_query_as::<NovelRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn list_novels(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    Query(query): Query<ListNovelsQuery>,
    headers: HeaderMap,
) -> Result<Json<ListNovelsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }

    let search_pat = search_ilike(query.search);
    let search_ref = search_pat.as_deref();

    let limit_clamped = match query.limit {
        None => None,
        Some(0) => {
            return Err(ApiError::BadRequest(
                "limit must be positive or omitted".into(),
            ));
        }
        Some(l) => Some(i64::from(l).min(MAX_NOVEL_LIST_LIMIT)),
    };

    if query.page.is_some() && limit_clamped.is_none() {
        let p = query.page.unwrap_or(1);
        if p != 1 {
            return Err(ApiError::BadRequest(
                "page is only valid together with limit".into(),
            ));
        }
    }

    let page = query.page.unwrap_or(1);
    if page == 0 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }

    let limit_offset = limit_clamped.map(|lim| {
        let off = i64::from(page.saturating_sub(1)) * lim;
        (lim, off)
    });

    let (items, total) = if limit_offset.is_some() {
        let total = count_novels_filtered(pool, project_legacy_id, uid, search_ref).await?;
        let items =
            select_novels_filtered(pool, project_legacy_id, uid, search_ref, limit_offset).await?;
        (items, total)
    } else {
        let items = select_novels_filtered(pool, project_legacy_id, uid, search_ref, None).await?;
        let total = items.len() as i64;
        (items, total)
    };

    Ok(Json(ListNovelsResponse { items, total }))
}

pub(super) async fn create_novel(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<CreateNovelBody>,
) -> Result<(StatusCode, Json<NovelRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }

    let chapter_index = body.chapter_index.unwrap_or(0);
    let reel = trim_opt(body.reel);
    let chapter = body.chapter.unwrap_or_default();
    let chapter_data = body.chapter_data.unwrap_or_default();

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_uuid: Uuid = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_NOVEL_LEGACY)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0) + 1
        FROM app_novel
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    let row = sqlx::query_as::<_, NovelRow>(
        r#"
        INSERT INTO app_novel (
          project_id, legacy_id, chapter_index, reel, chapter, chapter_data,
          event, event_state, error_reason, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, NULL, 0, NULL, $7, '{}'::jsonb)
        RETURNING id, legacy_id, chapter_index, reel, chapter, chapter_data,
                  event, event_state, error_reason, create_time_ms
        "#,
    )
    .bind(project_uuid)
    .bind(next_legacy)
    .bind(chapter_index)
    .bind(reel.as_ref())
    .bind(&chapter)
    .bind(&chapter_data)
    .bind(now_ms)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

pub(super) async fn get_novel_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, novel_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
) -> Result<Json<NovelRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || novel_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let row = sqlx::query_as::<_, NovelRow>(
        r#"
        SELECT n.id, n.legacy_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
               n.event, n.event_state, n.error_reason, n.create_time_ms
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND n.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(novel_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

pub(super) async fn patch_novel_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, novel_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchNovelBody>,
) -> Result<Json<NovelRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || novel_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
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
        SELECT n.id, n.legacy_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
               n.event, n.event_state, n.error_reason, n.create_time_ms
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND n.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(novel_legacy_id)
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
          AND p.legacy_id = $8
          AND p.owner_user_id = $9
          AND n.legacy_id = $10
        RETURNING n.id, n.legacy_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
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
    .bind(project_legacy_id)
    .bind(uid)
    .bind(novel_legacy_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}

pub(super) async fn delete_novel_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, novel_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || novel_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let res = sqlx::query(
        r#"
        DELETE FROM app_novel n
        USING app_project p
        WHERE n.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND n.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(novel_legacy_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}
