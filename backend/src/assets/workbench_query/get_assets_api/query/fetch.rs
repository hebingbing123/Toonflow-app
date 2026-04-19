use crate::assets::models::*;
use crate::error::ApiError;

pub(super) async fn count_nested_assets(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_numeric_id: i32,
    asset_type: &str,
    name_pattern: Option<&str>,
) -> Result<i64, ApiError> {
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
    .bind(asset_type)
    .bind(name_pattern)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(total)
}

pub(super) async fn fetch_parent_rows(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_numeric_id: i32,
    asset_type: &str,
    name_pattern: Option<&str>,
    limit: i64,
    offset: i64,
) -> Result<Vec<WorkbenchGetAssetsApiDbRow>, ApiError> {
    let parents: Vec<WorkbenchGetAssetsApiDbRow> = sqlx::query_as(
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
    .bind(asset_type)
    .bind(name_pattern)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(parents)
}

pub(super) async fn fetch_child_rows(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_numeric_id: i32,
    asset_type: &str,
    name_pattern: Option<&str>,
) -> Result<Vec<WorkbenchGetAssetsApiDbRow>, ApiError> {
    let children: Vec<WorkbenchGetAssetsApiDbRow> = sqlx::query_as(
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
    .bind(asset_type)
    .bind(name_pattern)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(children)
}
