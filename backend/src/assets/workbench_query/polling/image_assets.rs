use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::crud::ensure_owned_project_pk;
use super::super::super::models::*;
use super::validate::validate_polling_ids;

async fn run_polling_image_assets(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
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
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_asset_image ai
          ON ai.asset_id = a.id
         AND ai.numeric_image_id = (
           CASE
             WHEN jsonb_typeof(a.metadata->'imageId') = 'number'
               THEN (a.metadata->>'imageId')::integer
             ELSE NULL
           END
         )
        WHERE p.id = $2
          AND a.numeric_id = ANY($3)
          AND ai.state <> '生成中'
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
        ORDER BY a.numeric_id ASC
        "#,
    )
    .bind(uid)
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
    ensure_owned_project_pk(pool, uid, project_id).await?;
    let rows = run_polling_image_assets(pool, uid, project_id, &body.ids).await?;
    Ok(Json(rows))
}
