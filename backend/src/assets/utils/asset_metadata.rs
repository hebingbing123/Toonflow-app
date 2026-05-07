use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::super::models::WorkbenchOwnedAssetMetaRow;

pub(in crate::assets) async fn resolve_owned_asset_metadata(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    asset_numeric_id: i32,
) -> Result<WorkbenchOwnedAssetMetaRow, ApiError> {
    let row: Option<WorkbenchOwnedAssetMetaRow> = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND a.numeric_id = $2
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $3
          )
        "#,
    )
    .bind(project_id)
    .bind(asset_numeric_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or(ApiError::NotFound)
}
