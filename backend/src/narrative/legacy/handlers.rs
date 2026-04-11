use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::Value;
use sqlx::{PgPool, Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::narrative::novels::NovelRow;
use crate::state::AppState;

use super::dto::{
    AddNovelBody, BatchDeleteNovelsBody, BatchDeleteNovelsResponse, DeleteSingleNovelBody,
    GenerateNovelEventsBody, GetNovelBody, GetNovelEventStateBody, GetNovelResponse,
    LegacyNovelDataResponse, LegacyNovelEventStateItem, LegacyNovelEventStateResponse,
    LegacyNovelIndexResponse, LegacyNovelPageRow, NovelEventExtractionRow, NovelItem,
    NovelOkMessageResponse, ProjectIdBody, UpdateNovelBody,
};
use super::extraction::{resolve_event_extraction_prompt, run_novel_event_extraction_task};
use super::{
    ADV_LOCK_NOVEL_LEGACY, MAX_ADD_NOVEL_BATCH, MAX_BATCH_DELETE_NOVELS,
    MAX_GENERATE_EVENTS_CONCURRENCY, MAX_GET_NOVEL_LIMIT,
};

async fn fetch_novels_for_project(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
) -> Result<Vec<NovelRow>, ApiError> {
    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    sqlx::query_as::<_, NovelRow>(
        r#"
        SELECT n.id, n.legacy_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
               n.event, n.event_state, n.error_reason, n.create_time_ms
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.legacy_id = $1 AND p.owner_user_id = $2
        ORDER BY n.chapter_index ASC, n.legacy_id ASC
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
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

fn trim_reel(s: &str) -> Option<String> {
    let t = s.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_owned())
    }
}

fn parse_index_field(v: &Value) -> Result<i32, ApiError> {
    match v {
        Value::Number(n) => n
            .as_i64()
            .and_then(|x| i32::try_from(x).ok())
            .ok_or_else(|| ApiError::BadRequest("index must be a valid integer".into())),
        Value::String(s) => s
            .trim()
            .parse::<i32>()
            .map_err(|_| ApiError::BadRequest("index must be a valid integer".into())),
        _ => Err(ApiError::BadRequest(
            "index must be number or string".into(),
        )),
    }
}

pub(super) async fn post_get_novel_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ProjectIdBody>,
) -> Result<JsonResponse<LegacyNovelDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows = fetch_novels_for_project(pool, body.project_id, uid).await?;
    Ok(JsonResponse(LegacyNovelDataResponse { data: rows }))
}

pub(super) async fn post_get_novel_index(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ProjectIdBody>,
) -> Result<JsonResponse<LegacyNovelIndexResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows = fetch_novels_for_project(pool, body.project_id, uid).await?;
    let data = rows
        .into_iter()
        .map(|n| NovelItem {
            id: n.legacy_id,
            index: n.chapter_index,
            chapter: n.chapter,
        })
        .collect();

    Ok(JsonResponse(LegacyNovelIndexResponse { data }))
}

pub(super) async fn post_get_novel_event_state(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetNovelEventStateBody>,
) -> Result<JsonResponse<LegacyNovelEventStateResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if body.ids.is_empty() {
        return Ok(JsonResponse(LegacyNovelEventStateResponse {
            data: Vec::new(),
        }));
    }

    let data = sqlx::query_as::<_, LegacyNovelEventStateItem>(
        r#"
        SELECT n.legacy_id AS id, n.event, n.event_state, n.error_reason
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.owner_user_id = $1
          AND n.legacy_id = ANY($2)
          AND n.event_state <> 0
        ORDER BY n.legacy_id ASC
        "#,
    )
    .bind(uid)
    .bind(&body.ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(LegacyNovelEventStateResponse { data }))
}

pub(super) async fn post_batch_delete_novels(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchDeleteNovelsBody>,
) -> Result<JsonResponse<BatchDeleteNovelsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("请先选择需要删除的内容".into()));
    }
    if body.ids.len() > MAX_BATCH_DELETE_NOVELS {
        return Err(ApiError::BadRequest(format!(
            "ids must contain at most {MAX_BATCH_DELETE_NOVELS} entries",
        )));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_novel n
        USING app_project p
        WHERE n.project_id = p.id
          AND p.owner_user_id = $1
          AND n.legacy_id = ANY($2)
        "#,
    )
    .bind(uid)
    .bind(&body.ids)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(BatchDeleteNovelsResponse {
        message: "删除原文成功",
    }))
}

pub(super) async fn post_get_novel(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetNovelBody>,
) -> Result<JsonResponse<GetNovelResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.page < 1 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }
    if body.limit < 1 {
        return Err(ApiError::BadRequest("limit must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let lim = i64::from(body.limit).min(MAX_GET_NOVEL_LIMIT);
    let off = i64::from(body.page.saturating_sub(1)) * lim;
    let search_pat = search_ilike(body.search);
    let search_ref = search_pat.as_deref();

    let total = {
        let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
            r#"
            SELECT COUNT(*)::BIGINT
            FROM app_novel n
            INNER JOIN app_project p ON p.id = n.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(body.project_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        if let Some(pat) = search_ref {
            qb.push(" AND n.chapter ILIKE ");
            qb.push_bind(pat);
        }
        qb.build_query_scalar::<i64>()
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT n.id, n.legacy_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
               n.event, n.event_state, n.error_reason, n.create_time_ms
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(body.project_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_ref {
        qb.push(" AND n.chapter ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(" ORDER BY n.chapter_index ASC, n.legacy_id ASC LIMIT ");
    qb.push_bind(lim);
    qb.push(" OFFSET ");
    qb.push_bind(off);

    let rows: Vec<NovelRow> = qb
        .build_query_as::<NovelRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let data = rows
        .into_iter()
        .map(|n| LegacyNovelPageRow {
            id: n.legacy_id,
            index: n.chapter_index,
            reel: n.reel,
            chapter: n.chapter,
            chapter_data: n.chapter_data,
            event: n.event,
            event_state: n.event_state,
            error_reason: n.error_reason,
        })
        .collect();

    Ok(JsonResponse(GetNovelResponse { data, total }))
}

pub(super) async fn post_add_novel(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddNovelBody>,
) -> Result<JsonResponse<NovelOkMessageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.data.len() > MAX_ADD_NOVEL_BATCH {
        return Err(ApiError::BadRequest(format!(
            "data must contain at most {MAX_ADD_NOVEL_BATCH} entries",
        )));
    }

    if body.data.is_empty() {
        return Ok(JsonResponse(NovelOkMessageResponse {
            message: "新增原文成功",
        }));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

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
    .bind(body.project_id)
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

    let mut next_legacy: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0) + 1
        FROM app_novel
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    for item in &body.data {
        let reel = trim_reel(&item.reel);
        sqlx::query(
            r#"
            INSERT INTO app_novel (
              project_id, legacy_id, chapter_index, reel, chapter, chapter_data,
              event, event_state, error_reason, create_time_ms, metadata
            )
            VALUES ($1, $2, $3, $4, $5, $6, NULL, 0, NULL, $7, '{}'::jsonb)
            "#,
        )
        .bind(project_uuid)
        .bind(next_legacy)
        .bind(item.index)
        .bind(reel.as_ref())
        .bind(&item.chapter)
        .bind(&item.chapter_data)
        .bind(now_ms)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        next_legacy += 1;
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(NovelOkMessageResponse {
        message: "新增原文成功",
    }))
}

pub(super) async fn post_delete_novel(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteSingleNovelBody>,
) -> Result<JsonResponse<NovelOkMessageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_novel n
        USING app_project p
        WHERE n.project_id = p.id
          AND p.owner_user_id = $1
          AND n.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(NovelOkMessageResponse {
        message: "删除原文成功",
    }))
}

pub(super) async fn post_update_novel(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateNovelBody>,
) -> Result<JsonResponse<NovelOkMessageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let chapter_index = parse_index_field(&body.index)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let reel = trim_reel(&body.reel);
    let event = if body.event.trim().is_empty() {
        None
    } else {
        Some(body.event.clone())
    };

    let res = sqlx::query(
        r#"
        UPDATE app_novel n
        SET chapter_index = $1, reel = $2, chapter = $3, chapter_data = $4,
            event = $5, updated_at = NOW()
        FROM app_project p
        WHERE n.project_id = p.id
          AND p.owner_user_id = $6
          AND n.legacy_id = $7
        "#,
    )
    .bind(chapter_index)
    .bind(reel.as_ref())
    .bind(&body.chapter)
    .bind(&body.chapter_data)
    .bind(event.as_ref())
    .bind(uid)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(NovelOkMessageResponse {
        message: "更新原文成功",
    }))
}

pub(super) async fn post_generate_novel_events(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateNovelEventsBody>,
) -> Result<JsonResponse<NovelOkMessageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.novel_ids.is_empty() {
        return Err(ApiError::BadRequest("novelIds must not be empty".into()));
    }
    if body.concurrent_count == 0 {
        return Err(ApiError::BadRequest("concurrentCount must be >= 1".into()));
    }
    if body.concurrent_count > MAX_GENERATE_EVENTS_CONCURRENCY {
        return Err(ApiError::BadRequest(format!(
            "concurrentCount must be at most {MAX_GENERATE_EVENTS_CONCURRENCY}"
        )));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let novels: Vec<NovelEventExtractionRow> = sqlx::query_as(
        r#"
        SELECT n.id, n.chapter_index, n.reel, n.chapter, n.chapter_data
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND n.legacy_id = ANY($3)
        ORDER BY n.chapter_index ASC, n.legacy_id ASC
        "#,
    )
    .bind(body.project_id)
    .bind(uid)
    .bind(&body.novel_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if novels.is_empty() {
        return Err(ApiError::BadRequest("没有对应章节".into()));
    }

    let ids: Vec<Uuid> = novels.iter().map(|n| n.id).collect();
    sqlx::query(
        r#"
        UPDATE app_novel
        SET event = NULL, event_state = 0, error_reason = NULL, updated_at = NOW()
        WHERE id = ANY($1)
        "#,
    )
    .bind(&ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let prompt = resolve_event_extraction_prompt(pool, uid).await?;
    let pool_clone = pool.clone();
    let llm = state.llm.clone();
    let http_client = state.http_client.clone();
    let concurrency = body.concurrent_count;

    tokio::spawn(async move {
        run_novel_event_extraction_task(pool_clone, llm, http_client, prompt, novels, concurrency)
            .await;
    });

    Ok(JsonResponse(NovelOkMessageResponse {
        message: "生成事件成功",
    }))
}
