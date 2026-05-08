use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::ProjectsSummaryResponse;
use super::super::super::video_count::count_completed_videos_for_member_projects;

#[utoipa::path(
    get,
    path = "/api/v1/projects/summary",
    operation_id = "projectsSummaryV1",
    tag = "projects",
    responses(
        (status = 200, description = "OK", body = ProjectsSummaryResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn projects_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ProjectsSummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let row: (i64, i64, i64, i64, i64, i64, i64) = sqlx::query_as(
        r#"
        SELECT
            (SELECT COUNT(DISTINCT p.id)::bigint
             FROM app_project p
             WHERE EXISTS (
               SELECT 1 FROM app_workspace_member wm
               WHERE wm.workspace_id = p.workspace_id AND wm.user_id = $1
             )
               AND (
                 p.owner_user_id = $1
                 OR EXISTS (
                   SELECT 1 FROM app_workspace_member wm
                   WHERE wm.workspace_id = p.workspace_id
                     AND wm.user_id = $1
                     AND wm.role IN ('owner', 'admin')
                 )
                 OR NOT EXISTS (
                   SELECT 1 FROM app_project_member pm_any
                   WHERE pm_any.project_id = p.id
                 )
                 OR EXISTS (
                   SELECT 1 FROM app_project_member pm
                   WHERE pm.project_id = p.id AND pm.user_id = $1
                 )
               )),
            (SELECT COUNT(*)::bigint
             FROM app_script s
             INNER JOIN app_project p ON s.project_id = p.id
             WHERE EXISTS (
               SELECT 1 FROM app_workspace_member wm
               WHERE wm.workspace_id = p.workspace_id AND wm.user_id = $1
             )
               AND (
                 p.owner_user_id = $1
                 OR EXISTS (
                   SELECT 1 FROM app_workspace_member wm
                   WHERE wm.workspace_id = p.workspace_id
                     AND wm.user_id = $1
                     AND wm.role IN ('owner', 'admin')
                 )
                 OR NOT EXISTS (
                   SELECT 1 FROM app_project_member pm_any
                   WHERE pm_any.project_id = p.id
                 )
                 OR EXISTS (
                   SELECT 1 FROM app_project_member pm
                   WHERE pm.project_id = p.id AND pm.user_id = $1
                 )
               )),
            (SELECT COUNT(*)::bigint
             FROM app_storyboard sb
             INNER JOIN app_script s ON sb.script_id = s.id
             INNER JOIN app_project p ON s.project_id = p.id
             WHERE EXISTS (
               SELECT 1 FROM app_workspace_member wm
               WHERE wm.workspace_id = p.workspace_id AND wm.user_id = $1
             )
               AND (
                 p.owner_user_id = $1
                 OR EXISTS (
                   SELECT 1 FROM app_workspace_member wm
                   WHERE wm.workspace_id = p.workspace_id
                     AND wm.user_id = $1
                     AND wm.role IN ('owner', 'admin')
                 )
                 OR NOT EXISTS (
                   SELECT 1 FROM app_project_member pm_any
                   WHERE pm_any.project_id = p.id
                 )
                 OR EXISTS (
                   SELECT 1 FROM app_project_member pm
                   WHERE pm.project_id = p.id AND pm.user_id = $1
                 )
               )),
            (SELECT COUNT(*)::bigint
             FROM app_novel n
             INNER JOIN app_project p ON p.id = n.project_id
             WHERE EXISTS (
               SELECT 1 FROM app_workspace_member wm
               WHERE wm.workspace_id = p.workspace_id AND wm.user_id = $1
             )
               AND (
                 p.owner_user_id = $1
                 OR EXISTS (
                   SELECT 1 FROM app_workspace_member wm
                   WHERE wm.workspace_id = p.workspace_id
                     AND wm.user_id = $1
                     AND wm.role IN ('owner', 'admin')
                 )
                 OR NOT EXISTS (
                   SELECT 1 FROM app_project_member pm_any
                   WHERE pm_any.project_id = p.id
                 )
                 OR EXISTS (
                   SELECT 1 FROM app_project_member pm
                   WHERE pm.project_id = p.id AND pm.user_id = $1
                 )
               )),
            (SELECT COUNT(*)::bigint
             FROM app_asset a
             INNER JOIN app_project p ON p.id = a.project_id
             WHERE a.asset_type = 'role'
               AND EXISTS (
                 SELECT 1 FROM app_workspace_member wm
                 WHERE wm.workspace_id = p.workspace_id AND wm.user_id = $1
               )
               AND (
                 p.owner_user_id = $1
                 OR EXISTS (
                   SELECT 1 FROM app_workspace_member wm
                   WHERE wm.workspace_id = p.workspace_id
                     AND wm.user_id = $1
                     AND wm.role IN ('owner', 'admin')
                 )
                 OR NOT EXISTS (
                   SELECT 1 FROM app_project_member pm_any
                   WHERE pm_any.project_id = p.id
                 )
                 OR EXISTS (
                   SELECT 1 FROM app_project_member pm
                   WHERE pm.project_id = p.id AND pm.user_id = $1
                 )
               )),
            (SELECT COUNT(*)::bigint FROM app_art_style WHERE owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_asset a
             INNER JOIN app_project p ON p.id = a.project_id
             WHERE EXISTS (
               SELECT 1 FROM app_workspace_member wm
               WHERE wm.workspace_id = p.workspace_id AND wm.user_id = $1
             )
               AND (
                 p.owner_user_id = $1
                 OR EXISTS (
                   SELECT 1 FROM app_workspace_member wm
                   WHERE wm.workspace_id = p.workspace_id
                     AND wm.user_id = $1
                     AND wm.role IN ('owner', 'admin')
                 )
                 OR NOT EXISTS (
                   SELECT 1 FROM app_project_member pm_any
                   WHERE pm_any.project_id = p.id
                 )
                 OR EXISTS (
                   SELECT 1 FROM app_project_member pm
                   WHERE pm.project_id = p.id AND pm.user_id = $1
                 )
               ))
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let video_count = count_completed_videos_for_member_projects(pool, uid)
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
