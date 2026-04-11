//! 遗留轮询端点 — 查询图片和提示词资产状态。
//!
//! 提供 polling-image-assets 和 polling-prompt-assets 端点，
//! 用于客户端轮询资产生成和提示词优化的状态。

use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::models::*;

pub(crate) async fn post_legacy_polling_image_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyPollingImageAssetsBody>,
) -> Result<Json<Vec<LegacyPollingImageAssetsItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ids.is_empty() {
        return Ok(Json(Vec::new()));
    }
    if body.ids.len() > 200 {
        return Err(ApiError::BadRequest(
            "ids must have at most 200 rows".into(),
        ));
    }
    if body.ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("each ids[] must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows: Vec<LegacyPollingImageAssetsItem> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
          ai.state AS state,
          ai.file_path AS file_path
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_asset_image ai
          ON ai.asset_id = a.id
         AND ai.legacy_image_id = (
           CASE
             WHEN jsonb_typeof(a.metadata->'imageId') = 'number'
               THEN (a.metadata->>'imageId')::integer
             ELSE NULL
           END
         )
        WHERE p.owner_user_id = $1
          AND a.legacy_id = ANY($2)
          AND ai.state <> '生成中'
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(uid)
    .bind(&body.ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}

pub(crate) async fn post_legacy_polling_prompt_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyPollingPromptAssetsBody>,
) -> Result<Json<Vec<LegacyPollingPromptAssetsItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ids.is_empty() {
        return Ok(Json(Vec::new()));
    }
    if body.ids.len() > 200 {
        return Err(ApiError::BadRequest(
            "ids must have at most 200 rows".into(),
        ));
    }
    if body.ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("each ids[] must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows: Vec<LegacyPollingPromptAssetsItem> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
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
                AND NULLIF(j.payload->>'asset_legacy_id', '')::integer = a.legacy_id
              )
              OR (
                j.kind = 'asset.polish.batch'
                AND EXISTS (
                  SELECT 1
                  FROM jsonb_array_elements(COALESCE(j.payload->'items', '[]'::jsonb)) it
                  WHERE NULLIF(it->>'asset_legacy_id', '')::integer = a.legacy_id
                )
              )
            )
          ORDER BY j.updated_at DESC, j.created_at DESC, j.id DESC
          LIMIT 1
        ) pj ON TRUE
        WHERE p.owner_user_id = $1
          AND a.legacy_id = ANY($2)
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
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(uid)
    .bind(&body.ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}
