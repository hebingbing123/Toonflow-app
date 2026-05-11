use axum::{
    extract::{Json, Path, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

use super::super::super::dto::{BatchDeleteEventsBody, BatchDeleteEventsResponse};
use super::super::super::MAX_EVENT_BATCH_DELETE;

async fn delete_novel_event_core(
    pool: &PgPool,
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
          AND e.numeric_id = $2
        "#,
    )
    .bind(project_uuid)
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

pub(crate) async fn delete_novel_event_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((project_id, event_numeric_id)): Path<(Uuid, i32)>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    require_project_write_scope(&state, uid, project_id).await?;
    delete_novel_event_core(pool, project_id, event_numeric_id).await
}

async fn batch_delete_novel_events_core(
    pool: &PgPool,
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
          AND e.numeric_id = ANY($2)
        "#,
    )
    .bind(project_uuid)
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

pub(crate) async fn batch_delete_novel_events_for_project(
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
    require_project_write_scope(&state, uid, project_id).await?;
    batch_delete_novel_events_core(pool, project_id, body).await
}
