//! 父子资产树查询（项目 UUID 路径：**`POST …/assets/workbench/nested`**）。

use std::collections::HashMap;

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::crud::ensure_owned_project_numeric_id;
use super::super::models::*;
use super::super::MAX_ASSET_LIST_LIMIT;

async fn run_get_assets_api(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_numeric_id: i32,
    body: &WorkbenchNestedAssetsBody,
) -> Result<LegacyGetAssetsApiResponse, ApiError> {
    let asset_type = body.asset_type.trim().to_lowercase();
    let page = body.page.unwrap_or(1);
    let limit = body.limit.unwrap_or(10);
    let limit = i64::from(limit).min(MAX_ASSET_LIST_LIMIT);
    let offset = i64::from(page - 1) * limit;

    let name_pattern = body
        .name
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| format!("%{s}%"));

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::BIGINT
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND a.asset_type = $3
          AND (
            NOT (a.metadata ? 'assetsId')
            OR jsonb_typeof(a.metadata->'assetsId') = 'null'
          )
          AND (
            $4::text IS NULL
            OR a.name ILIKE $4
          )
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .bind(&asset_type)
    .bind(name_pattern.as_deref())
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let parents: Vec<LegacyGetAssetsApiDbRow> = sqlx::query_as(
        r#"
        SELECT
          a.numeric_id AS id,
          CASE
            WHEN COALESCE(a.metadata->>'projectId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'projectId')::integer
            ELSE NULL
          END AS project_id,
          a.asset_type,
          a.name,
          CASE
            WHEN COALESCE(a.metadata->>'assetsId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'assetsId')::integer
            ELSE NULL
          END AS assets_id,
          CASE
            WHEN COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'imageId')::integer
            ELSE NULL
          END AS image_id,
          ai.file_path,
          ai.state,
          ai.metadata->>'errorReason' AS error_reason
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN app_asset_image ai
          ON ai.asset_id = a.id
         AND ai.numeric_image_id = CASE
           WHEN COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
             THEN (a.metadata->>'imageId')::integer
           ELSE NULL
         END
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND a.asset_type = $3
          AND (
            NOT (a.metadata ? 'assetsId')
            OR jsonb_typeof(a.metadata->'assetsId') = 'null'
          )
          AND (
            $4::text IS NULL
            OR a.name ILIKE $4
          )
        ORDER BY a.numeric_id ASC
        LIMIT $5 OFFSET $6
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .bind(&asset_type)
    .bind(name_pattern.as_deref())
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let children: Vec<LegacyGetAssetsApiDbRow> = sqlx::query_as(
        r#"
        SELECT
          a.numeric_id AS id,
          CASE
            WHEN COALESCE(a.metadata->>'projectId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'projectId')::integer
            ELSE NULL
          END AS project_id,
          a.asset_type,
          a.name,
          CASE
            WHEN COALESCE(a.metadata->>'assetsId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'assetsId')::integer
            ELSE NULL
          END AS assets_id,
          CASE
            WHEN COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'imageId')::integer
            ELSE NULL
          END AS image_id,
          ai.file_path,
          ai.state,
          ai.metadata->>'errorReason' AS error_reason
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN app_asset_image ai
          ON ai.asset_id = a.id
         AND ai.numeric_image_id = CASE
           WHEN COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
             THEN (a.metadata->>'imageId')::integer
           ELSE NULL
         END
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND a.asset_type = $3
          AND (
            a.metadata ? 'assetsId'
            AND jsonb_typeof(a.metadata->'assetsId') <> 'null'
          )
          AND (
            $4::text IS NULL
            OR a.name ILIKE $4
          )
        ORDER BY a.numeric_id ASC
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .bind(&asset_type)
    .bind(name_pattern.as_deref())
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut child_map: HashMap<i32, Vec<LegacyGetAssetsApiChildItem>> = HashMap::new();
    for row in children {
        let child = LegacyGetAssetsApiChildItem {
            id: row.id,
            project_id: row.project_id.unwrap_or(project_numeric_id),
            asset_type: row.asset_type,
            name: row.name,
            assets_id: row.assets_id,
            image_id: row.image_id,
            src: row.file_path.clone(),
            file_path: row.file_path,
            state: row.state,
            error_reason: row.error_reason,
        };
        if let Some(parent_id) = child.assets_id {
            child_map.entry(parent_id).or_default().push(child);
        }
    }

    let data = parents
        .into_iter()
        .map(|row| LegacyGetAssetsApiParentItem {
            id: row.id,
            project_id: row.project_id.unwrap_or(project_numeric_id),
            asset_type: row.asset_type,
            name: row.name,
            assets_id: row.assets_id,
            image_id: row.image_id,
            src: row.file_path.clone(),
            file_path: row.file_path,
            state: row.state,
            error_reason: row.error_reason,
            son_assets: child_map.remove(&row.id).unwrap_or_default(),
        })
        .collect();

    Ok(LegacyGetAssetsApiResponse { data, total })
}

pub(crate) async fn post_project_workbench_nested_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchNestedAssetsBody>,
) -> Result<Json<LegacyGetAssetsApiResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let asset_type = body.asset_type.trim().to_lowercase();
    if asset_type != "role" && asset_type != "scene" && asset_type != "tool" {
        return Err(ApiError::BadRequest(
            "type must be role, scene, or tool".into(),
        ));
    }
    let page = body.page.unwrap_or(1);
    let limit = body.limit.unwrap_or(10);
    if page <= 0 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }
    if limit <= 0 {
        return Err(ApiError::BadRequest("limit must be >= 1".into()));
    }
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let project_numeric_id = ensure_owned_project_numeric_id(pool, uid, project_id).await?;
    let out = run_get_assets_api(pool, uid, project_numeric_id, &body).await?;
    Ok(Json(out))
}
