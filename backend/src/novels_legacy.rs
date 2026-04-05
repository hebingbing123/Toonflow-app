//! Legacy **`/api/novel/getNovelData`**, **`getNovelIndex`**, **`batchDeleteNovel`** as **`POST /api/v1/novels/*`**.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::novels::NovelRow;
use crate::state::AppState;

const MAX_BATCH_DELETE_NOVELS: usize = 500;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ProjectIdBody {
    project_id: i32,
}

#[derive(Debug, Serialize)]
struct LegacyNovelDataResponse {
    data: Vec<NovelRow>,
}

#[derive(Debug, Serialize)]
struct LegacyNovelIndexResponse {
    data: Vec<NovelItem>,
}

#[derive(Debug, Serialize)]
struct NovelItem {
    id: i32,
    index: i32,
    chapter: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct BatchDeleteNovelsBody {
    ids: Vec<i32>,
}

#[derive(Debug, Serialize)]
struct BatchDeleteNovelsResponse {
    message: &'static str,
}

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

async fn post_get_novel_data(
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

async fn post_get_novel_index(
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

async fn post_batch_delete_novels(
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

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/novels/get-novel-data", post(post_get_novel_data))
        .route("/api/v1/novels/get-novel-index", post(post_get_novel_index))
        .route(
            "/api/v1/novels/batch-delete",
            post(post_batch_delete_novels),
        )
}
