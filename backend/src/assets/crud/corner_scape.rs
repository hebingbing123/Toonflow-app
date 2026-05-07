//! `POST …/assets/corner-scape` — assets missing `assetsId` in metadata, with history images.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use serde_json::Value;
use sqlx::{Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::models::*;
use super::super::utils::normalize_corner_types_filter;
use super::resolve::ensure_owned_project_pk;

async fn list_corner_scape_assets_inner(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    body: CornerScapeBody,
) -> Result<Json<CornerScapeResponse>, ApiError> {
    let type_filter = normalize_corner_types_filter(body.types)?;

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT
          a.id,
          a.numeric_id,
          a.name,
          a.asset_type,
          a.description,
          a.create_time_ms,
          a.metadata,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'id', i.id,
                  'file_path', i.file_path,
                  'state', i.state,
                  'sort_index', i.sort_index,
                  'numeric_image_id', i.numeric_image_id
                )
                ORDER BY i.sort_index ASC, i.created_at ASC
              )
              FROM app_asset_image i
              WHERE i.asset_id = a.id
                AND i.state = '已完成'
            ),
            '[]'::jsonb
          ) AS history_images
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = "#,
    );
    qb.push_bind(project_id);
    qb.push(
        r#"
          AND (
            NOT (a.metadata ? 'assetsId')
            OR jsonb_typeof(a.metadata->'assetsId') = 'null'
          )
        "#,
    );
    if let Some(types) = type_filter.as_ref() {
        qb.push(" AND a.asset_type IN (");
        let mut sep = qb.separated(", ");
        for t in types {
            sep.push_bind(t);
        }
        qb.push(")");
    }
    qb.push(
        r#"
        ORDER BY CASE a.asset_type
          WHEN 'role' THEN 1
          WHEN 'scene' THEN 2
          WHEN 'tool' THEN 3
          ELSE 4
        END,
        a.numeric_id ASC
        "#,
    );

    let rows: Vec<CornerScapeDbRow> = qb
        .build_query_as()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = rows
        .into_iter()
        .map(|r| CornerScapeAssetItem {
            id: r.id,
            numeric_id: r.numeric_id,
            name: r.name,
            asset_type: r.asset_type,
            description: r.description,
            create_time_ms: r.create_time_ms,
            metadata: r.metadata.0,
            history_images: match r.history_images.0 {
                Value::Array(a) => a,
                _ => Vec::new(),
            },
        })
        .collect();

    Ok(Json(CornerScapeResponse { items }))
}

pub(crate) async fn list_corner_scape_assets_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CornerScapeBody>,
) -> Result<Json<CornerScapeResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let _ = normalize_corner_types_filter(body.types.clone())?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    list_corner_scape_assets_inner(pool, project_id, body).await
}
