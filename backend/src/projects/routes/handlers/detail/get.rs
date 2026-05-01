//! 单项目详情（含剧本摘要列表）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::{ProjectDetailResponse, ProjectRow, ScriptBrief};

pub(crate) async fn get_project_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectDetailResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let project = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, numeric_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms,
               art_style_pack, story_style_pack
        FROM app_project
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_id)
    .bind(uid)
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
