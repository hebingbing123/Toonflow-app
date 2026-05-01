use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::common::{trim_opt, ADV_LOCK_PROJECT_NUMERIC_ID};
use super::super::super::types::{CreateProjectBody, ProjectRow};

pub(crate) async fn create_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateProjectBody>,
) -> Result<(StatusCode, Json<ProjectRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_PROJECT_NUMERIC_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_project
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        INSERT INTO app_project (
          owner_user_id, numeric_id, name, intro, project_type,
          image_model, image_quality, video_model, art_style,
          director_manual, mode, video_ratio, create_time_ms, metadata,
          art_style_pack, story_style_pack
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, '{}'::jsonb, $14, $15)
        RETURNING id, numeric_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms,
                  art_style_pack, story_style_pack
        "#,
    )
    .bind(uid)
    .bind(next_numeric_id)
    .bind(trim_opt(body.name))
    .bind(trim_opt(body.intro))
    .bind(trim_opt(body.project_type))
    .bind(trim_opt(body.image_model))
    .bind(trim_opt(body.image_quality))
    .bind(trim_opt(body.video_model))
    .bind(trim_opt(body.art_style))
    .bind(trim_opt(body.director_manual))
    .bind(trim_opt(body.mode))
    .bind(trim_opt(body.video_ratio))
    .bind(now_ms)
    .bind(trim_opt(body.art_style_pack))
    .bind(trim_opt(body.story_style_pack))
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}
