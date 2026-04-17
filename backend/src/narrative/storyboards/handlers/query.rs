use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope;
use crate::state::AppState;

use super::super::dto::StoryboardRow;
use super::common::fetch_storyboard_row;

pub(in crate::narrative::storyboards) async fn list_by_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<Vec<StoryboardRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let oip = scope::owned_script_in_project(pool, uid, project_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let rows = sqlx::query_as::<_, StoryboardRow>(
        r#"
        SELECT
          sb.id, sb.script_id, sb.numeric_id, sb.numeric_script_id, sb.prompt, sb.file_path,
          sb.duration, sb.state, sb.track_id, sb.reason, sb.track, sb.video_desc,
          sb.should_generate_image, sb.numeric_project_id, sb.flow_id, sb.sb_index, sb.create_time_ms
        FROM app_storyboard sb
        WHERE sb.script_id = $1
        ORDER BY sb.sb_index ASC NULLS LAST, sb.numeric_id ASC
        "#,
    )
    .bind(oip.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}

pub(in crate::narrative::storyboards) async fn get_by_numeric_id_for_project(
    State(state): State<AppState>,
    Path((project_id, storyboard_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<StoryboardRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let storyboard_id =
        super::common::resolve_owned_storyboard_id(pool, uid, project_id, storyboard_numeric_id)
            .await?;
    let row = fetch_storyboard_row(pool, storyboard_id).await?;

    Ok(Json(row))
}
