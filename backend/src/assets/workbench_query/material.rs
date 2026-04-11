//! 素材板数据（**`POST …/assets/workbench/material-data`**）。

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

async fn run_get_material_data(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_numeric_id: i32,
) -> Result<LegacyGetMaterialDataResponse, ApiError> {
    let mut data: Vec<LegacyMaterialAssetItem> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
          a.name AS name,
          COALESCE(sel.file_path, '') AS file_path,
          a.asset_type AS asset_type
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN LATERAL (
          SELECT ai.file_path
          FROM app_asset_image ai
          WHERE ai.asset_id = a.id
          ORDER BY
            CASE
              WHEN ai.legacy_image_id = (
                CASE
                  WHEN jsonb_typeof(a.metadata->'imageId') = 'number'
                    THEN (a.metadata->>'imageId')::integer
                  ELSE NULL
                END
              ) THEN 0
              ELSE 1
            END,
            ai.sort_index ASC,
            ai.created_at ASC,
            ai.id ASC
          LIMIT 1
        ) sel ON TRUE
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.asset_type = 'clip'
        ORDER BY a.create_time_ms DESC NULLS LAST, a.legacy_id DESC
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    data.push(LegacyMaterialAssetItem {
        id: 0,
        name: "Toonflow片尾".into(),
        file_path: String::new(),
        asset_type: "clip".into(),
    });

    let video: Vec<LegacyMaterialVideoItem> = sqlx::query_as(
        r#"
        SELECT
          v.legacy_id AS id,
          COALESCE(v.file_path, '') AS file_path,
          (
            SELECT vt.legacy_id
            FROM app_video_track vt
            WHERE vt.project_id = v.project_id
              AND (vt.select_video_id = v.legacy_id OR vt.video_id = v.id)
            ORDER BY vt.updated_at DESC, vt.created_at DESC, vt.id DESC
            LIMIT 1
          ) AS video_track_id
        FROM app_video v
        INNER JOIN app_project p ON p.id = v.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND v.state IN ('生成成功', '已完成', 'succeeded', 'completed')
        ORDER BY v.legacy_id DESC
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(LegacyGetMaterialDataResponse { data, video })
}

pub(crate) async fn post_project_workbench_material_data(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(_body): Json<WorkbenchEmptyBody>,
) -> Result<Json<LegacyGetMaterialDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let project_numeric_id = ensure_owned_project_numeric_id(pool, uid, project_id).await?;
    let out = run_get_material_data(pool, uid, project_numeric_id).await?;
    Ok(Json(out))
}
