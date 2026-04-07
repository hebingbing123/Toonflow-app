//! Novel events (legacy **`o_event`** / **`o_eventChapter`**): CRUD and chapter associations.

use axum::{
    extract::{Json, Path, Query, State},
    http::HeaderMap,
    routing::{delete, get, post},
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{FromRow, Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

const MAX_EVENT_BATCH_DELETE: usize = 500;
const MAX_EVENT_LIST_LIMIT: i64 = 200;

#[derive(Debug, FromRow)]
struct EventQueryRow {
    id: Uuid,
    project_id: Uuid,
    legacy_id: i32,
    name: String,
    detail: String,
    create_time_ms: Option<i64>,
    chapter_indexes: Vec<i32>,
}

#[derive(Debug, Serialize)]
pub struct EventWithChapters {
    pub id: Uuid,
    pub project_id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub detail: String,
    pub create_time_ms: Option<i64>,
    pub chapter_indexes: Vec<i32>,
}

impl From<EventQueryRow> for EventWithChapters {
    fn from(row: EventQueryRow) -> Self {
        Self {
            id: row.id,
            project_id: row.project_id,
            legacy_id: row.legacy_id,
            name: row.name,
            detail: row.detail,
            create_time_ms: row.create_time_ms,
            chapter_indexes: row.chapter_indexes,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct ListNovelEventsQuery {
    #[serde(default)]
    pub search: Option<String>,
    #[serde(default)]
    pub page: Option<u32>,
    #[serde(default)]
    pub limit: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct ListNovelEventsResponse {
    pub items: Vec<EventWithChapters>,
    pub total: i64,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct CreateNovelEventBody {
    pub name: String,
    #[serde(default)]
    pub detail: Option<String>,
    #[serde(default)]
    pub chapter_ids: Vec<i32>, // legacy novel ids to associate
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct UpdateNovelEventBody {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub detail: Option<Value>, // null to clear, string to set
    #[serde(default)]
    pub chapter_ids: Option<Vec<i32>>, // if provided, replaces all associations
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BatchDeleteEventsBody {
    pub ids: Vec<i32>,
}

#[derive(Debug, Serialize)]
pub struct BatchDeleteEventsResponse {
    pub message: &'static str,
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

async fn list_novel_events(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_legacy_id): Path<i32>,
    Query(query): Query<ListNovelEventsQuery>,
) -> Result<JsonResponse<ListNovelEventsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }

    let page = query.page.unwrap_or(1);
    let limit = query.limit.unwrap_or(20);
    if page < 1 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }
    if limit < 1 {
        return Err(ApiError::BadRequest("limit must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let lim = i64::from(limit).min(MAX_EVENT_LIST_LIMIT);
    let off = i64::from(page.saturating_sub(1)) * lim;
    let search_pat = search_ilike(query.search);
    let search_ref = search_pat.as_deref();

    // Count total (distinct events matching search)
    let total = {
        let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
            "SELECT COUNT(DISTINCT e.id)::BIGINT
             FROM app_novel_event e
             INNER JOIN app_project p ON p.id = e.project_id
             WHERE p.legacy_id = ",
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        if let Some(pat) = search_ref {
            qb.push(" AND e.name ILIKE ");
            qb.push_bind(pat);
        }
        qb.build_query_scalar::<i64>()
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };

    // Fetch events with aggregated chapter indexes
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT 
            e.id as "id!",
            e.project_id as "project_id!",
            e.legacy_id as "legacy_id!",
            e.name as "name!",
            e.detail as "detail!",
            e.create_time_ms,
            COALESCE(
                ARRAY_AGG(n.chapter_index ORDER BY n.chapter_index) 
                FILTER (WHERE n.chapter_index IS NOT NULL),
                ARRAY[]::INTEGER[]
            ) as "chapter_indexes!: Vec<i32>"
        FROM app_novel_event e
        INNER JOIN app_project p ON p.id = e.project_id
        LEFT JOIN app_novel_event_chapter ec ON ec.event_id = e.id
        LEFT JOIN app_novel n ON n.id = ec.novel_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(project_legacy_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_ref {
        qb.push(" AND e.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(
        " GROUP BY e.id, e.project_id, e.legacy_id, e.name, e.detail, e.create_time_ms
          ORDER BY e.create_time_ms DESC NULLS LAST, e.legacy_id DESC
          LIMIT ",
    );
    qb.push_bind(lim);
    qb.push(" OFFSET ");
    qb.push_bind(off);

    let rows: Vec<EventWithChapters> = qb
        .build_query_as::<EventQueryRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .into_iter()
        .map(EventWithChapters::from)
        .collect();

    Ok(JsonResponse(ListNovelEventsResponse { items: rows, total }))
}

async fn create_novel_event(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_legacy_id): Path<i32>,
    Json(body): Json<CreateNovelEventBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }

    let name = body.name.trim();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Verify project access
    let project_uuid: Uuid = sqlx::query_scalar(
        "SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2",
    )
    .bind(project_legacy_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    // Get next legacy_id
    let next_legacy: i32 =
        sqlx::query_scalar("SELECT COALESCE(MAX(legacy_id), 0) + 1 FROM app_novel_event")
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let detail = body.detail.as_ref().map(|s| s.trim()).unwrap_or("");

    // Insert event
    let event_id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO app_novel_event (project_id, legacy_id, name, detail, create_time_ms, metadata)
        VALUES ($1, $2, $3, $4, $5, '{}'::jsonb)
        RETURNING id
        "#,
    )
    .bind(project_uuid)
    .bind(next_legacy)
    .bind(name)
    .bind(detail)
    .bind(now_ms)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Insert chapter associations if provided
    if !body.chapter_ids.is_empty() {
        // Validate all novel_ids belong to this project
        let valid_novels: Vec<(Uuid, i32)> = sqlx::query_as(
            "SELECT id, legacy_id FROM app_novel WHERE project_id = $1 AND legacy_id = ANY($2)",
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

        for (novel_uuid, _legacy_id) in valid_novels {
            sqlx::query(
                "INSERT INTO app_novel_event_chapter (event_id, novel_id) VALUES ($1, $2) ON CONFLICT DO NOTHING"
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
        "id": next_legacy,
        "name": name,
        "detail": detail,
        "message": "创建事件成功"
    })))
}

async fn update_novel_event(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((project_legacy_id, event_legacy_id)): Path<(i32, i32)>,
    Json(body): Json<UpdateNovelEventBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 || event_legacy_id <= 0 {
        return Err(ApiError::BadRequest("ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Verify ownership and get event UUID
    let event_row: Option<(Uuid, Uuid)> = sqlx::query_as(
        r#"
        SELECT e.id, p.id
        FROM app_novel_event e
        INNER JOIN app_project p ON p.id = e.project_id
        WHERE p.legacy_id = $1 AND p.owner_user_id = $2 AND e.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(event_legacy_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (event_uuid, project_uuid) = event_row.ok_or(ApiError::NotFound)?;

    // Build update
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

    // Update chapter associations if provided
    if let Some(chapter_ids) = &body.chapter_ids {
        // Delete existing associations
        sqlx::query("DELETE FROM app_novel_event_chapter WHERE event_id = $1")
            .bind(event_uuid)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // Insert new associations
        if !chapter_ids.is_empty() {
            let valid_novels: Vec<(Uuid, i32)> = sqlx::query_as(
                "SELECT id, legacy_id FROM app_novel WHERE project_id = $1 AND legacy_id = ANY($2)",
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

            for (novel_uuid, _legacy_id) in valid_novels {
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

async fn delete_novel_event(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((project_legacy_id, event_legacy_id)): Path<(i32, i32)>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 || event_legacy_id <= 0 {
        return Err(ApiError::BadRequest("ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_novel_event e
        USING app_project p
        WHERE e.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND e.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(event_legacy_id)
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

async fn batch_delete_novel_events(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_legacy_id): Path<i32>,
    Json(body): Json<BatchDeleteEventsBody>,
) -> Result<JsonResponse<BatchDeleteEventsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("请先选择需要删除的事件".into()));
    }
    if body.ids.len() > MAX_EVENT_BATCH_DELETE {
        return Err(ApiError::BadRequest(format!(
            "ids must contain at most {MAX_EVENT_BATCH_DELETE} entries",
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
        DELETE FROM app_novel_event e
        USING app_project p
        WHERE e.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND e.legacy_id = ANY($3)
        "#,
    )
    .bind(project_legacy_id)
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

// Legacy POST route matching old API shape
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyGetEventsBody {
    project_id: i32,
    page: u32,
    limit: u32,
    #[serde(default)]
    search: Option<String>,
}

async fn post_get_events(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyGetEventsBody>,
) -> Result<JsonResponse<Value>, ApiError> {
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

    let lim = i64::from(body.limit).min(MAX_EVENT_LIST_LIMIT);
    let off = i64::from(body.page.saturating_sub(1)) * lim;
    let search_pat = search_ilike(body.search);
    let search_ref = search_pat.as_deref();

    // Count
    let total = {
        let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
            "SELECT COUNT(DISTINCT e.id)::BIGINT
             FROM app_novel_event e
             INNER JOIN app_project p ON p.id = e.project_id
             WHERE p.legacy_id = ",
        );
        qb.push_bind(body.project_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        if let Some(pat) = search_ref {
            qb.push(" AND e.name ILIKE ");
            qb.push_bind(pat);
        }
        qb.build_query_scalar::<i64>()
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };

    // List with chapters
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT 
            e.legacy_id as "id!",
            e.name as "event_name!",
            e.detail,
            e.create_time_ms as "create_time!",
            COALESCE(
                ARRAY_AGG(n.chapter_index ORDER BY n.chapter_index) 
                FILTER (WHERE n.chapter_index IS NOT NULL),
                ARRAY[]::INTEGER[]
            ) as "chapters!: Vec<i32>"
        FROM app_novel_event e
        INNER JOIN app_project p ON p.id = e.project_id
        LEFT JOIN app_novel_event_chapter ec ON ec.event_id = e.id
        LEFT JOIN app_novel n ON n.id = ec.novel_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(body.project_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_ref {
        qb.push(" AND e.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(
        " GROUP BY e.id, e.legacy_id, e.name, e.detail, e.create_time_ms
          ORDER BY e.create_time_ms DESC NULLS LAST, e.legacy_id DESC
          LIMIT ",
    );
    qb.push_bind(lim);
    qb.push(" OFFSET ");
    qb.push_bind(off);

    #[derive(Debug, FromRow, Serialize)]
    struct LegacyEventRow {
        id: i32,
        #[serde(rename = "eventName")]
        event_name: String,
        detail: Option<String>,
        #[serde(rename = "createTime")]
        create_time: i64,
        chapters: Vec<i32>,
    }

    let rows: Vec<LegacyEventRow> = qb
        .build_query_as::<LegacyEventRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(serde_json::json!({
        "list": rows,
        "total": total
    })))
}

async fn post_batch_delete_events(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchDeleteEventsBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("ids must not be empty".into()));
    }
    if body.ids.len() > MAX_EVENT_BATCH_DELETE {
        return Err(ApiError::BadRequest(format!(
            "ids must contain at most {MAX_EVENT_BATCH_DELETE} entries",
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

    sqlx::query(
        r#"
        DELETE FROM app_novel_event e
        USING app_project p
        WHERE e.project_id = p.id
          AND p.owner_user_id = $1
          AND e.legacy_id = ANY($2)
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

    Ok(JsonResponse(serde_json::json!({
        "message": "删除事件成功"
    })))
}

pub fn router() -> Router<AppState> {
    Router::new()
        // RESTful routes
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/novel-events",
            get(list_novel_events).post(create_novel_event),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/novel-events/{event_legacy_id}",
            delete(delete_novel_event).patch(update_novel_event),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/novel-events/batch-delete",
            post(batch_delete_novel_events),
        )
        // Legacy POST routes matching old API
        .route("/api/v1/novels/events/get-events", post(post_get_events))
        .route(
            "/api/v1/novels/events/batch-delete",
            post(post_batch_delete_events),
        )
}
