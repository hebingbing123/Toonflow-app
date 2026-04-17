use uuid::Uuid;

use crate::error::ApiError;
use crate::narrative::storyboards::ADV_LOCK_STORYBOARD_NUMERIC_ID;
use crate::production::workbench::common as workbench_common;
use crate::production::workbench::storyboard_ops::ProductionStoryboardItem;
use crate::scope;
use crate::state::AppState;

#[derive(Debug, Clone, PartialEq, Eq)]
pub(super) struct StoryboardInsertDraft {
    pub(super) prompt: String,
    pub(super) duration: i32,
}

#[derive(Debug)]
pub(super) struct StoryboardPreviewData {
    pub(super) file_path: Option<String>,
    pub(super) prompt: Option<String>,
}

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

pub(super) fn normalize_storyboard_prompt(prompt: &str) -> Result<String, ApiError> {
    let prompt = prompt.trim();
    if prompt.is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }
    Ok(prompt.to_string())
}

pub(super) fn normalize_storyboard_image_url(image_url: &str) -> Result<String, ApiError> {
    let image_url = image_url.trim();
    if image_url.is_empty() {
        return Err(ApiError::BadRequest("imageUrl must not be empty".into()));
    }
    Ok(image_url.to_string())
}

async fn resolve_owned_script_id(
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

async fn resolve_owned_storyboard_id(
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

pub(super) async fn require_owned_script_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
) -> Result<Uuid, ApiError> {
    require_positive_project_script(project_id, script_id)?;
    resolve_owned_script_id(pool, uid, project_id, script_id).await
}

pub(super) async fn require_owned_storyboard_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<Uuid, ApiError> {
    require_positive_scope_ids(project_id, script_id, storyboard_id)?;
    resolve_owned_storyboard_id(pool, uid, project_id, script_id, storyboard_id).await
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

pub(super) async fn fetch_owned_storyboard_item(
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

pub(super) async fn list_owned_storyboard_items_by_script(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
) -> Result<Vec<ProductionStoryboardItem>, ApiError> {
    let script_uuid = require_owned_script_id(pool, uid, project_id, script_id).await?;
    list_storyboard_items_by_script(pool, script_uuid).await
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

pub(super) async fn update_owned_storyboard_info(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    prompt: &str,
    duration: Option<i32>,
) -> Result<(), ApiError> {
    let storyboard_uuid =
        require_owned_storyboard_id(pool, uid, project_id, script_id, storyboard_id).await?;
    update_storyboard_info(pool, storyboard_uuid, prompt, duration).await
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

pub(super) async fn remove_owned_storyboard_frame(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<(), ApiError> {
    let storyboard_uuid =
        require_owned_storyboard_id(pool, uid, project_id, script_id, storyboard_id).await?;
    remove_storyboard_frame(pool, storyboard_uuid).await
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

pub(super) async fn update_owned_storyboard_image_url(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    image_url: &str,
) -> Result<(), ApiError> {
    let storyboard_uuid =
        require_owned_storyboard_id(pool, uid, project_id, script_id, storyboard_id).await?;
    update_storyboard_image_url(pool, storyboard_uuid, image_url).await
}

pub(super) async fn fetch_storyboard_preview_data(
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

pub(super) async fn fetch_owned_storyboard_preview_data(
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

async fn insert_storyboard_row(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    script_uuid: Uuid,
    numeric_script_id: i32,
    numeric_id: i32,
    draft: &StoryboardInsertDraft,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_storyboard (
            script_id, numeric_id, numeric_script_id, prompt, duration,
            state, sb_index, created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, '草稿', $6, NOW(), NOW())
        "#,
    )
    .bind(script_uuid)
    .bind(numeric_id)
    .bind(numeric_script_id)
    .bind(&draft.prompt)
    .bind(draft.duration)
    .bind(numeric_id)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

fn storyboard_numeric_ids_from_base(base_numeric_id: i32, count: usize) -> Vec<i32> {
    (0..count)
        .map(|idx| base_numeric_id + idx as i32 + 1)
        .collect()
}

pub(super) async fn insert_storyboards_with_next_numeric_ids(
    pool: &sqlx::PgPool,
    script_uuid: Uuid,
    numeric_script_id: i32,
    drafts: &[StoryboardInsertDraft],
) -> Result<Vec<i32>, ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_STORYBOARD_NUMERIC_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let base_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) FROM app_storyboard"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let storyboard_ids = storyboard_numeric_ids_from_base(base_numeric_id, drafts.len());
    for (storyboard_id, draft) in storyboard_ids.iter().copied().zip(drafts.iter()) {
        insert_storyboard_row(
            &mut tx,
            script_uuid,
            numeric_script_id,
            storyboard_id,
            draft,
        )
        .await?;
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(storyboard_ids)
}

pub(super) async fn insert_owned_storyboards_with_next_numeric_ids(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    drafts: &[StoryboardInsertDraft],
) -> Result<Vec<i32>, ApiError> {
    let script_uuid = require_owned_script_id(pool, uid, project_id, script_id).await?;
    insert_storyboards_with_next_numeric_ids(pool, script_uuid, script_id, drafts).await
}

#[cfg(test)]
mod tests {
    use super::{
        normalize_storyboard_image_url, normalize_storyboard_prompt,
        storyboard_numeric_ids_from_base,
    };
    use crate::error::ApiError;

    #[test]
    fn storyboard_numeric_ids_from_base_starts_after_base_id() {
        assert_eq!(storyboard_numeric_ids_from_base(41, 3), vec![42, 43, 44]);
    }

    #[test]
    fn storyboard_numeric_ids_from_base_allows_empty_batch() {
        assert!(storyboard_numeric_ids_from_base(9, 0).is_empty());
    }

    #[test]
    fn normalize_storyboard_prompt_trims_value() {
        let prompt = normalize_storyboard_prompt("  opening frame  ").unwrap();
        assert_eq!(prompt, "opening frame");
    }

    #[test]
    fn normalize_storyboard_prompt_rejects_blank_value() {
        let err = normalize_storyboard_prompt("   ").unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "prompt must not be empty"
        ));
    }

    #[test]
    fn normalize_storyboard_image_url_trims_value() {
        let image_url =
            normalize_storyboard_image_url("  https://example.com/frame.png  ").unwrap();
        assert_eq!(image_url, "https://example.com/frame.png");
    }

    #[test]
    fn normalize_storyboard_image_url_rejects_blank_value() {
        let err = normalize_storyboard_image_url(" ").unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "imageUrl must not be empty"
        ));
    }
}
