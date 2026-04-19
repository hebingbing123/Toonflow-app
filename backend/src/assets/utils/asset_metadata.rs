use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::super::models::WorkbenchOwnedAssetMetaRow;

pub(in crate::assets) async fn resolve_owned_asset_metadata(
    pool: &PgPool,
    uid: Uuid,
    asset_numeric_id: i32,
) -> Result<WorkbenchOwnedAssetMetaRow, ApiError> {
    let row: Option<WorkbenchOwnedAssetMetaRow> = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(uid)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or(ApiError::NotFound)
}
