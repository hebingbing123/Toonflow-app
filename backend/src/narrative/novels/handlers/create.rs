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
use crate::state::AppState;

use super::super::dto::{CreateNovelBody, NovelRow};
use super::super::ADV_LOCK_NOVEL_NUMERIC;

use super::list::trim_opt;

async fn create_novel_inner(
    pool: &PgPool,
    project_uuid: Uuid,
    body: CreateNovelBody,
) -> Result<(StatusCode, Json<NovelRow>), ApiError> {
    let chapter_index = body.chapter_index.unwrap_or(0);
    let reel = trim_opt(body.reel);
    let chapter = body.chapter.unwrap_or_default();
    let chapter_data = body.chapter_data.unwrap_or_default();

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_NOVEL_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
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
          project_id, numeric_id, chapter_index, reel, chapter, chapter_data,
          event, event_state, error_reason, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, NULL, 0, NULL, $7, '{}'::jsonb)
        RETURNING id, numeric_id, chapter_index, reel, chapter, chapter_data,
                  event, event_state, error_reason, create_time_ms
        "#,
    )
    .bind(project_uuid)
    .bind(next_numeric_id)
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

pub(crate) async fn create_novel_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CreateNovelBody>,
) -> Result<(StatusCode, Json<NovelRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    create_novel_inner(pool, project_id, body).await
}
