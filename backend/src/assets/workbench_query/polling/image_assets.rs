use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::crud::require_asset_project_read_scope;
use super::super::super::models::*;
use super::validate::validate_polling_ids;

async fn run_polling_image_assets(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    ids: &[i32],
) -> Result<Vec<WorkbenchPollingImageAssetsItem>, ApiError> {
    if ids.is_empty() {
        return Ok(Vec::new());
    }

    let rows: Vec<WorkbenchPollingImageAssetsItem> = sqlx::query_as(
        r#"
        SELECT
          a.numeric_id AS id,
          ai.state AS state,
          ai.file_path AS file_path
        FROM app_asset a
        INNER JOIN app_asset_image ai
          ON ai.asset_id = a.id
         AND ai.numeric_image_id = (
           CASE
             WHEN jsonb_typeof(a.metadata->'imageId') = 'number'
               THEN (a.metadata->>'imageId')::integer
             ELSE NULL
           END
         )
        WHERE a.project_id = $1
          AND a.numeric_id = ANY($2)
          AND ai.state <> '生成中'
        ORDER BY a.numeric_id ASC
        "#,
    )
    .bind(project_id)
    .bind(ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows)
}

pub(crate) async fn post_project_workbench_polling_image_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchPollingImageAssetsBody>,
) -> Result<Json<Vec<WorkbenchPollingImageAssetsItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_polling_ids(&body.ids)?;
    let pool = state.require_pool()?;
    require_asset_project_read_scope(&state, uid, project_id).await?;
    let rows = run_polling_image_assets(pool, project_id, &body.ids).await?;
    Ok(Json(rows))
}
