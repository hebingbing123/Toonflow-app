use axum::{
    extract::{Query, State},
    http::{HeaderMap, StatusCode},
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::common::{trim_opt, ADV_LOCK_PROJECT_NUMERIC_ID};
use super::super::types::{
    CreateProjectBody, ListProjectsQuery, ProjectRow, ProjectsSummaryResponse,
};

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
          director_manual, mode, video_ratio, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, '{}'::jsonb)
        RETURNING id, numeric_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms
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
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

pub(crate) async fn list_projects(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListProjectsQuery>,
) -> Result<Json<Vec<ProjectRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let limit = query.limit.unwrap_or(20).clamp(1, 100);
    let offset = query.offset.unwrap_or(0).max(0);

    let rows = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, numeric_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms
        FROM app_project
        WHERE owner_user_id = $1
        ORDER BY create_time_ms DESC NULLS LAST, numeric_id DESC
        LIMIT $2 OFFSET $3
        "#,
    )
    .bind(uid)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

pub(crate) async fn projects_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ProjectsSummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let row: (i64, i64, i64, i64, i64, i64, i64) = sqlx::query_as(
        r#"
        SELECT
            (SELECT COUNT(*)::bigint FROM app_project WHERE owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_script s
             INNER JOIN app_project p ON s.project_id = p.id
             WHERE p.owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_storyboard sb
             INNER JOIN app_script s ON sb.script_id = s.id
             INNER JOIN app_project p ON s.project_id = p.id
             WHERE p.owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_novel n
             INNER JOIN app_project p ON p.id = n.project_id
             WHERE p.owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_asset a
             INNER JOIN app_project p ON p.id = a.project_id
             WHERE p.owner_user_id = $1 AND a.asset_type = 'role'),
            (SELECT COUNT(*)::bigint FROM app_art_style WHERE owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_asset a
             INNER JOIN app_project p ON p.id = a.project_id
             WHERE p.owner_user_id = $1)
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let video_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND status = 'succeeded'
          AND (kind ILIKE '%video%' OR kind ILIKE '%workbench%')
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ProjectsSummaryResponse {
        project_count: row.0,
        script_count: row.1,
        storyboard_count: row.2,
        novel_count: row.3,
        role_count: row.4,
        art_style_count: row.5,
        asset_count: row.6,
        video_count,
    }))
}
