//! 单项目详情（含剧本摘要列表）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

use super::super::super::types::{ProjectDetailResponse, ProjectRow, ScriptBrief};

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}",
    operation_id = "getProjectByIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectDetailResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_project_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectDetailResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    let project = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, workspace_id, numeric_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms,
               art_style_pack, story_style_pack,
               target_market, target_platforms, duration_strategy,
               voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy,
               $2 AS project_access_mode,
               $3 AS project_access_role
        FROM app_project p
        WHERE p.id = $1
        "#,
    )
    .bind(scope.id)
    .bind(scope.access_mode_label())
    .bind(scope.access_role_label())
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let scripts = sqlx::query_as::<_, ScriptBrief>(
        r#"
        SELECT numeric_id, name, extract_state
        FROM app_script
        WHERE project_id = $1
        ORDER BY numeric_id ASC
        "#,
    )
    .bind(project.id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ProjectDetailResponse { project, scripts }))
}
