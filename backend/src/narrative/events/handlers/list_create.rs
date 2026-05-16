use axum::{
    extract::{Json, Path, Query, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, validate_non_empty_string, ApiError};
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::state::AppState;

use super::super::dto::{
    CreateNovelEventBody, EventWithChapters, ListNovelEventsQuery, ListNovelEventsResponse,
};
use super::super::query::{count_novel_events, list_event_rows, search_ilike};
use super::super::{ADV_LOCK_NOVEL_EVENT_NUMERIC, MAX_EVENT_LIST_LIMIT};
use sqlx::PgPool;

async fn list_novel_events_core(
    pool: &PgPool,
    project_id: Uuid,
    query: ListNovelEventsQuery,
) -> Result<JsonResponse<ListNovelEventsResponse>, ApiError> {
    let page = query.page.unwrap_or(1);
    let limit = query.limit.unwrap_or(20);
    if page < 1 {
        return Err(bad_request_i18n("page must be >= 1", "page 必须大于等于 1"));
    }
    if limit < 1 {
        return Err(bad_request_i18n(
            "limit must be positive",
            "limit 必须为正数",
        ));
    }

    let lim = i64::from(limit).min(MAX_EVENT_LIST_LIMIT);
    let off = i64::from(page.saturating_sub(1)) * lim;
    let search_pat = search_ilike(query.search);
    let search_ref = search_pat.as_deref();
    let total = count_novel_events(pool, project_id, search_ref).await?;
    let rows: Vec<EventWithChapters> = list_event_rows(pool, project_id, lim, off, search_ref)
        .await?
        .into_iter()
        .map(EventWithChapters::from)
        .collect();

    Ok(JsonResponse(ListNovelEventsResponse { items: rows, total }))
}

pub(crate) async fn list_novel_events_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Query(query): Query<ListNovelEventsQuery>,
) -> Result<JsonResponse<ListNovelEventsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_workspace_member_scope(&state, uid, project_id).await?;
    list_novel_events_core(pool, project_id, query).await
}

async fn create_novel_event_core(
    pool: &PgPool,
    project_uuid: Uuid,
    body: CreateNovelEventBody,
) -> Result<JsonResponse<serde_json::Value>, ApiError> {
    let name = body.name.trim();
    validate_non_empty_string(name, "name")?;

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
            return Err(bad_request_i18n(
                "some chapterIds do not exist in this project",
                "部分 chapterIds 在当前项目中不存在",
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

pub(crate) async fn create_novel_event_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<CreateNovelEventBody>,
) -> Result<JsonResponse<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    require_project_write_scope(&state, uid, project_id).await?;
    create_novel_event_core(pool, project_id, body).await
}
