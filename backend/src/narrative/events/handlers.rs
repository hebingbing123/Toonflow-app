//! 小说事件 HTTP 处理器。
//!
//! 事件 CRUD 和章节关联管理。

use axum::{
    extract::{Json, Path, Query, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::dto::{
    BatchDeleteEventsBody, BatchDeleteEventsResponse, CreateNovelEventBody, EventWithChapters,
    GenerateNovelEventsBody, ListNovelEventsQuery, ListNovelEventsResponse,
    NovelEventExtractionRow, NovelOkMessageResponse, UpdateNovelEventBody,
};
use super::extraction::{resolve_event_extraction_prompt, run_novel_event_extraction_task};
use super::query::{count_novel_events, list_event_rows, search_ilike};
use super::{
    ADV_LOCK_NOVEL_EVENT_NUMERIC, MAX_EVENT_BATCH_DELETE, MAX_EVENT_LIST_LIMIT,
    MAX_GENERATE_EVENTS_CONCURRENCY,
};

async fn list_novel_events_core(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    query: ListNovelEventsQuery,
) -> Result<JsonResponse<ListNovelEventsResponse>, ApiError> {
    let page = query.page.unwrap_or(1);
    let limit = query.limit.unwrap_or(20);
    if page < 1 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }
    if limit < 1 {
        return Err(ApiError::BadRequest("limit must be positive".into()));
    }

    let lim = i64::from(limit).min(MAX_EVENT_LIST_LIMIT);
    let off = i64::from(page.saturating_sub(1)) * lim;
    let search_pat = search_ilike(query.search);
    let search_ref = search_pat.as_deref();
    let total = count_novel_events(pool, project_id, uid, search_ref).await?;
    let rows: Vec<EventWithChapters> = list_event_rows(pool, project_id, uid, lim, off, search_ref)
        .await?
        .into_iter()
        .map(EventWithChapters::from)
        .collect();

    Ok(JsonResponse(ListNovelEventsResponse { items: rows, total }))
}

pub(super) async fn list_novel_events_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Query(query): Query<ListNovelEventsQuery>,
) -> Result<JsonResponse<ListNovelEventsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    list_novel_events_core(pool, uid, project_id, query).await
}

async fn create_novel_event_core(
    pool: &PgPool,
    project_uuid: Uuid,
    body: CreateNovelEventBody,
) -> Result<JsonResponse<Value>, ApiError> {
    let name = body.name.trim();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_NOVEL_EVENT_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 =
        sqlx::query_scalar("SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_novel_event")
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let detail = body.detail.as_ref().map(|s| s.trim()).unwrap_or("");

    let event_id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO app_novel_event (project_id, numeric_id, name, detail, create_time_ms, metadata)
        VALUES ($1, $2, $3, $4, $5, '{}'::jsonb)
        RETURNING id
        "#,
    )
    .bind(project_uuid)
    .bind(next_numeric_id)
    .bind(name)
    .bind(detail)
    .bind(now_ms)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if !body.chapter_ids.is_empty() {
        let valid_novels: Vec<(Uuid, i32)> = sqlx::query_as(
            "SELECT id, numeric_id FROM app_novel WHERE project_id = $1 AND numeric_id = ANY($2)",
        )
        .bind(project_uuid)
        .bind(&body.chapter_ids)
        .fetch_all(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if valid_novels.len() != body.chapter_ids.len() {
            return Err(ApiError::BadRequest(
                "Some chapter_ids do not exist in this project".into(),
            ));
        }

        for (novel_uuid, _numeric_id) in valid_novels {
            sqlx::query(
                "INSERT INTO app_novel_event_chapter (event_id, novel_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
            )
            .bind(event_id)
            .bind(novel_uuid)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(serde_json::json!({
        "id": next_numeric_id,
        "name": name,
        "detail": detail,
        "message": "创建事件成功"
    })))
}

pub(super) async fn create_novel_event_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<CreateNovelEventBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    create_novel_event_core(pool, project_id, body).await
}

async fn update_novel_event_core(
    pool: &PgPool,
    project_uuid: Uuid,
    event_numeric_id: i32,
    body: UpdateNovelEventBody,
) -> Result<JsonResponse<Value>, ApiError> {
    if event_numeric_id <= 0 {
        return Err(ApiError::BadRequest("ids must be positive".into()));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let event_row: Option<(Uuid, Uuid)> = sqlx::query_as(
        r#"
        SELECT e.id, p.id
        FROM app_novel_event e
        INNER JOIN app_project p ON p.id = e.project_id
        WHERE p.id = $1 AND e.numeric_id = $2
        "#,
    )
    .bind(project_uuid)
    .bind(event_numeric_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (event_uuid, _) = event_row.ok_or(ApiError::NotFound)?;

    if let Some(name) = &body.name {
        let name = name.trim();
        if name.is_empty() {
            return Err(ApiError::BadRequest("name must not be empty".into()));
        }
        sqlx::query("UPDATE app_novel_event SET name = $1, updated_at = NOW() WHERE id = $2")
            .bind(name)
            .bind(event_uuid)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    if let Some(detail) = &body.detail {
        let detail_val = match detail {
            Value::Null => None,
            Value::String(s) => {
                let t = s.trim();
                if t.is_empty() {
                    None
                } else {
                    Some(t.to_string())
                }
            }
            _ => return Err(ApiError::BadRequest("detail must be string or null".into())),
        };
        sqlx::query("UPDATE app_novel_event SET detail = $1, updated_at = NOW() WHERE id = $2")
            .bind(detail_val)
            .bind(event_uuid)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    if let Some(chapter_ids) = &body.chapter_ids {
        sqlx::query("DELETE FROM app_novel_event_chapter WHERE event_id = $1")
            .bind(event_uuid)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if !chapter_ids.is_empty() {
            let valid_novels: Vec<(Uuid, i32)> = sqlx::query_as(
                "SELECT id, numeric_id FROM app_novel WHERE project_id = $1 AND numeric_id = ANY($2)",
            )
            .bind(project_uuid)
            .bind(chapter_ids)
            .fetch_all(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            if valid_novels.len() != chapter_ids.len() {
                return Err(ApiError::BadRequest(
                    "Some chapter_ids do not exist in this project".into(),
                ));
            }

            for (novel_uuid, _numeric_id) in valid_novels {
                sqlx::query(
                    "INSERT INTO app_novel_event_chapter (event_id, novel_id) VALUES ($1, $2)",
                )
                .bind(event_uuid)
                .bind(novel_uuid)
                .execute(&mut *tx)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            }
        }
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(serde_json::json!({
        "message": "更新事件成功"
    })))
}

pub(super) async fn update_novel_event_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((project_id, event_numeric_id)): Path<(Uuid, i32)>,
    Json(body): Json<UpdateNovelEventBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    update_novel_event_core(pool, project_id, event_numeric_id, body).await
}

async fn delete_novel_event_core(
    pool: &PgPool,
    uid: Uuid,
    project_uuid: Uuid,
    event_numeric_id: i32,
) -> Result<JsonResponse<Value>, ApiError> {
    if event_numeric_id <= 0 {
        return Err(ApiError::BadRequest("ids must be positive".into()));
    }

    let res = sqlx::query(
        r#"
        DELETE FROM app_novel_event e
        USING app_project p
        WHERE e.project_id = p.id
          AND p.id = $1
          AND p.owner_user_id = $2
          AND e.numeric_id = $3
        "#,
    )
    .bind(project_uuid)
    .bind(uid)
    .bind(event_numeric_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(serde_json::json!({
        "message": "删除事件成功"
    })))
}

pub(super) async fn delete_novel_event_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((project_id, event_numeric_id)): Path<(Uuid, i32)>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    delete_novel_event_core(pool, uid, project_id, event_numeric_id).await
}

async fn batch_delete_novel_events_core(
    pool: &PgPool,
    uid: Uuid,
    project_uuid: Uuid,
    body: BatchDeleteEventsBody,
) -> Result<JsonResponse<BatchDeleteEventsResponse>, ApiError> {
    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("请先选择需要删除的事件".into()));
    }
    if body.ids.len() > MAX_EVENT_BATCH_DELETE {
        return Err(ApiError::BadRequest(format!(
            "ids must contain at most {MAX_EVENT_BATCH_DELETE} entries",
        )));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_novel_event e
        USING app_project p
        WHERE e.project_id = p.id
          AND p.id = $1
          AND p.owner_user_id = $2
          AND e.numeric_id = ANY($3)
        "#,
    )
    .bind(project_uuid)
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

    Ok(JsonResponse(BatchDeleteEventsResponse {
        message: "删除事件成功",
    }))
}

pub(super) async fn batch_delete_novel_events_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<BatchDeleteEventsBody>,
) -> Result<JsonResponse<BatchDeleteEventsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    batch_delete_novel_events_core(pool, uid, project_id, body).await
}

pub(super) async fn post_generate_novel_events_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_uuid): Path<Uuid>,
    Json(body): Json<GenerateNovelEventsBody>,
) -> Result<JsonResponse<NovelOkMessageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
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

    ensure_owned_project_pk(pool, uid, project_uuid).await?;

    let novels: Vec<NovelEventExtractionRow> = sqlx::query_as(
        r#"
        SELECT n.id, n.chapter_index, n.reel, n.chapter, n.chapter_data
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.id = $1
          AND p.owner_user_id = $2
          AND n.numeric_id = ANY($3)
        ORDER BY n.chapter_index ASC, n.numeric_id ASC
        "#,
    )
    .bind(project_uuid)
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
