use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;
use crate::workspaces::ensure_personal_workspace;

use super::super::super::types::{ListProjectsQuery, ProjectRow};

#[utoipa::path(
    get,
    path = "/api/v1/projects",
    operation_id = "listProjectsV1",
    tag = "projects",
    params(ListProjectsQuery),
    responses(
        (status = 200, description = "OK", body = Vec<ProjectRow>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_projects(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListProjectsQuery>,
) -> Result<Json<Vec<ProjectRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let personal = ensure_personal_workspace(pool, uid).await?;

    let limit = query.limit.unwrap_or(20).clamp(1, 100);
    let offset = query.offset.unwrap_or(0).max(0);

    let scope_workspace_id: uuid::Uuid = sqlx::query_scalar(
        r#"
        SELECT COALESCE(
          (
            SELECT p.current_workspace_id
            FROM public.app_user_profile p
            WHERE p.user_id = $1
              AND p.current_workspace_id IS NOT NULL
              AND EXISTS (
                SELECT 1
                FROM public.app_workspace_member m
                WHERE m.workspace_id = p.current_workspace_id
                  AND m.user_id = $1
              )
            LIMIT 1
          ),
          $2
        ) AS workspace_id
        "#,
    )
    .bind(uid)
    .bind(personal.workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let rows = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, workspace_id, numeric_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms,
               art_style_pack, story_style_pack,
               target_market, target_platforms, duration_strategy,
               voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy
        FROM app_project
        WHERE workspace_id = $1
        ORDER BY create_time_ms DESC NULLS LAST, numeric_id DESC
        LIMIT $2 OFFSET $3
        "#,
    )
    .bind(scope_workspace_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}
