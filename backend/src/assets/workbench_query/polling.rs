//! 资产图片 / prompt 轮询（项目 UUID 路径）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::crud::ensure_owned_project_pk;
use super::super::models::*;

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
        WHERE p.owner_user_id = $1
          AND p.id = $2
          AND a.numeric_id = ANY($3)
          AND ai.state <> '生成中'
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
    if !body.ids.is_empty() {
        if body.ids.len() > 200 {
            return Err(ApiError::BadRequest(
                "ids must have at most 200 rows".into(),
            ));
        }
        if body.ids.iter().any(|id| *id <= 0) {
            return Err(ApiError::BadRequest("each ids[] must be positive".into()));
        }
    }
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    let rows = run_polling_image_assets(pool, uid, project_id, &body.ids).await?;
    Ok(Json(rows))
}

async fn run_polling_prompt_assets(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_id: Uuid,
    ids: &[i32],
) -> Result<Vec<WorkbenchPollingPromptAssetsItem>, ApiError> {
    if ids.is_empty() {
        return Ok(Vec::new());
    }

    let rows: Vec<WorkbenchPollingPromptAssetsItem> = sqlx::query_as(
        r#"
        SELECT
          a.numeric_id AS id,
          a.name AS name,
          a.asset_type AS asset_type,
          COALESCE(
            CASE pj.status
              WHEN 'queued' THEN '生成中'
              WHEN 'running' THEN '生成中'
              WHEN 'succeeded' THEN '已完成'
              WHEN 'failed' THEN '失败'
              WHEN 'cancelled' THEN '已取消'
              ELSE NULL
            END,
            '已完成'
          ) AS prompt_state
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN LATERAL (
          SELECT j.status
          FROM app_generation_job j
          WHERE j.owner_user_id = $1
            AND j.kind IN ('asset.polish.prompt', 'asset.polish.batch')
            AND (
              (
                j.kind = 'asset.polish.prompt'
                AND NULLIF(j.payload->>'asset_numeric_id', '')::integer = a.numeric_id
              )
              OR (
                j.kind = 'asset.polish.batch'
                AND EXISTS (
                  SELECT 1
                  FROM jsonb_array_elements(COALESCE(j.payload->'items', '[]'::jsonb)) it
                  WHERE NULLIF(it->>'asset_numeric_id', '')::integer = a.numeric_id
                )
              )
            )
          ORDER BY j.updated_at DESC, j.created_at DESC, j.id DESC
          LIMIT 1
        ) pj ON TRUE
        WHERE p.owner_user_id = $1
          AND p.id = $2
          AND a.numeric_id = ANY($3)
          AND COALESCE(
            CASE pj.status
              WHEN 'queued' THEN '生成中'
              WHEN 'running' THEN '生成中'
              WHEN 'succeeded' THEN '已完成'
              WHEN 'failed' THEN '失败'
              WHEN 'cancelled' THEN '已取消'
              ELSE NULL
            END,
            '已完成'
          ) <> '生成中'
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

pub(crate) async fn post_project_workbench_polling_prompt_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchPollingPromptAssetsBody>,
) -> Result<Json<Vec<WorkbenchPollingPromptAssetsItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if !body.ids.is_empty() {
        if body.ids.len() > 200 {
            return Err(ApiError::BadRequest(
                "ids must have at most 200 rows".into(),
            ));
        }
        if body.ids.iter().any(|id| *id <= 0) {
            return Err(ApiError::BadRequest("each ids[] must be positive".into()));
        }
    }
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    let rows = run_polling_prompt_assets(pool, uid, project_id, &body.ids).await?;
    Ok(Json(rows))
}
