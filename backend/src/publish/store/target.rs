//! Target operations for publish store.

use sqlx::types::Json;
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::error::ApiError;
use crate::publish::types::{PublishTargetInput, PublishTargetRow};
pub(crate) async fn list_targets(
    pool: &PgPool,
    draft_id: Uuid,
) -> Result<Vec<PublishTargetRow>, ApiError> {
    sqlx::query_as::<_, PublishTargetRow>(
        r#"
        SELECT id, draft_id, platform_id, automation_mode, serial_order, extra, created_at, updated_at
        FROM app_publish_target
        WHERE draft_id = $1
        ORDER BY serial_order ASC, platform_id ASC
        "#,
    )
    .bind(draft_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn replace_targets_tx(
    tx: &mut Transaction<'_, Postgres>,
    draft_id: Uuid,
    targets: &[PublishTargetInput],
) -> Result<Vec<PublishTargetRow>, ApiError> {
    sqlx::query(r#"DELETE FROM app_publish_target WHERE draft_id = $1"#)
        .bind(draft_id)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut out = Vec::with_capacity(targets.len());
    for t in targets {
        let row = sqlx::query_as::<_, PublishTargetRow>(
            r#"
            INSERT INTO app_publish_target (draft_id, platform_id, automation_mode, serial_order, extra)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, draft_id, platform_id, automation_mode, serial_order, extra, created_at, updated_at
            "#,
        )
        .bind(draft_id)
        .bind(t.platform_id.trim())
        .bind(t.automation_mode.trim())
        .bind(t.serial_order)
        .bind(Json(t.extra.clone()))
        .fetch_one(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        out.push(row);
    }
    Ok(out)
}

pub(crate) async fn replace_targets(
    pool: &PgPool,
    draft_id: Uuid,
    targets: &[PublishTargetInput],
) -> Result<Vec<PublishTargetRow>, ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let rows = replace_targets_tx(&mut tx, draft_id, targets).await?;
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows)
}

pub(crate) async fn draft_has_semi_auto_target(
    pool: &PgPool,
    draft_id: Uuid,
) -> Result<bool, ApiError> {
    let v: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_publish_target
          WHERE draft_id = $1 AND automation_mode = 'semi_auto'
        )
        "#,
    )
    .bind(draft_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(v)
}
