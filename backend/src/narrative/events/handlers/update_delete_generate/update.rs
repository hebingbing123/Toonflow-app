use axum::{
    extract::{Json, Path, State},
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

use super::super::super::dto::UpdateNovelEventBody;

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

pub(crate) async fn update_novel_event_for_project(
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
