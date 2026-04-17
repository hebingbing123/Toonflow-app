use uuid::Uuid;

use crate::error::ApiError;
use crate::production::workbench::common as workbench_common;
use crate::production::workbench::storyboard_ops::ProductionStoryboardItem;
use crate::scope;
use crate::state::AppState;

pub(super) fn require_pool(state: &AppState) -> Result<&sqlx::PgPool, ApiError> {
    workbench_common::require_pool(state)
}

pub(super) fn require_positive_project_script(
    project_id: i32,
    script_id: i32,
) -> Result<(), ApiError> {
    workbench_common::require_positive_project_script(project_id, script_id)
}

pub(super) fn require_positive_scope_ids(
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<(), ApiError> {
    if project_id <= 0 || script_id <= 0 || storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId, scriptId, and storyboardId must be positive integers".into(),
        ));
    }
    Ok(())
}

pub(super) async fn resolve_owned_script_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
) -> Result<Uuid, ApiError> {
    let scope_row = scope::owned_script_scope(pool, uid, project_id, script_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok(scope_row.script_id)
}

pub(super) async fn resolve_owned_storyboard_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<Uuid, ApiError> {
    let sb =
        scope::owned_storyboard_in_script_scope(pool, uid, project_id, script_id, storyboard_id)
            .await
            .map_err(|e| e.into_api_error())?;
    Ok(sb.storyboard_id)
}

pub(super) async fn fetch_storyboard_item(
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

pub(super) async fn list_storyboard_items_by_script(
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

pub(super) async fn update_storyboard_info(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
    prompt: &str,
    duration: Option<i32>,
) -> Result<(), ApiError> {
    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET prompt = $2, duration = $3, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .bind(prompt)
    .bind(duration)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}

pub(super) async fn remove_storyboard_frame(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
) -> Result<(), ApiError> {
    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = NULL, state = NULL, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}

pub(super) async fn update_storyboard_image_url(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
    image_url: &str,
) -> Result<(), ApiError> {
    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $2, state = '已完成', updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .bind(image_url)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}
