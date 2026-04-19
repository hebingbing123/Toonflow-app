use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::ProjectsSummaryResponse;

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
