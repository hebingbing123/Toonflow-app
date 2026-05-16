use uuid::Uuid;

use crate::error::ApiError;
use crate::narrative::storyboards::ADV_LOCK_STORYBOARD_NUMERIC_ID;

use super::super::ids::storyboard_numeric_ids_from_base;
use super::super::types::StoryboardInsertDraft;

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

pub(in crate::production::workbench::storyboard) async fn insert_storyboards_with_next_numeric_ids(
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
