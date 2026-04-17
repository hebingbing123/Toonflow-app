use uuid::Uuid;

use crate::error::ApiError;
use crate::production::workbench::storyboard_ops::ProductionStoryboardItem;

use super::super::scope::{require_owned_script_id, require_owned_storyboard_id};
use super::super::types::StoryboardPreviewData;

pub(in crate::production::workbench::storyboard) async fn fetch_storyboard_item(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
) -> Result<ProductionStoryboardItem, ApiError> {
    sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index
        FROM app_storyboard sb
        WHERE sb.id = $1
        "#,
    )
    .bind(storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

pub(in crate::production::workbench::storyboard) async fn list_storyboard_items_by_script(
    pool: &sqlx::PgPool,
    script_id: Uuid,
) -> Result<Vec<ProductionStoryboardItem>, ApiError> {
    sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index
        FROM app_storyboard sb
        WHERE sb.script_id = $1
        ORDER BY sb.sb_index ASC
        "#,
    )
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(in crate::production::workbench::storyboard) async fn fetch_owned_storyboard_item(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<ProductionStoryboardItem, ApiError> {
    let storyboard_uuid =
        require_owned_storyboard_id(pool, uid, project_id, script_id, storyboard_id).await?;
    fetch_storyboard_item(pool, storyboard_uuid).await
}

pub(in crate::production::workbench::storyboard) async fn list_owned_storyboard_items_by_script(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
) -> Result<Vec<ProductionStoryboardItem>, ApiError> {
    let script_uuid = require_owned_script_id(pool, uid, project_id, script_id).await?;
    list_storyboard_items_by_script(pool, script_uuid).await
}

pub(in crate::production::workbench::storyboard) async fn fetch_storyboard_preview_data(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
) -> Result<StoryboardPreviewData, ApiError> {
    let (file_path, prompt): (Option<String>, Option<String>) =
        sqlx::query_as(r#"SELECT file_path, prompt FROM app_storyboard WHERE id = $1"#)
            .bind(storyboard_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(StoryboardPreviewData { file_path, prompt })
}

pub(in crate::production::workbench::storyboard) async fn fetch_owned_storyboard_preview_data(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<StoryboardPreviewData, ApiError> {
    let storyboard_uuid =
        require_owned_storyboard_id(pool, uid, project_id, script_id, storyboard_id).await?;
    fetch_storyboard_preview_data(pool, storyboard_uuid).await
}
