use axum::{
    extract::{Json, Path, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::dto::{
    GenerateNovelEventsBody, NovelEventExtractionRow, NovelOkMessageResponse,
};
use super::super::super::extraction::{
    resolve_event_extraction_prompt, run_novel_event_extraction_task,
};
use super::super::super::MAX_GENERATE_EVENTS_CONCURRENCY;

pub(crate) async fn post_generate_novel_events_for_project(
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
        SELECT n.id, p.numeric_id AS project_numeric_id, n.chapter_index, n.reel, n.chapter, n.chapter_data
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
        run_novel_event_extraction_task(
            pool_clone,
            uid,
            llm,
            http_client,
            prompt,
            novels,
            concurrency,
        )
        .await;
    });

    Ok(JsonResponse(NovelOkMessageResponse {
        message: "生成事件成功",
    }))
}
