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
    project_numeric_id: i32,
) -> Result<WorkbenchGetMaterialDataResponse, ApiError> {
    let mut data: Vec<WorkbenchMaterialAssetItem> = sqlx::query_as(
        r#"
        SELECT
          a.numeric_id AS id,
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
              WHEN ai.numeric_image_id = (
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
        WHERE p.numeric_id = $1
          AND a.asset_type = 'clip'
        ORDER BY a.create_time_ms DESC NULLS LAST, a.numeric_id DESC
        "#,
    )
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    data.push(WorkbenchMaterialAssetItem {
        id: 0,
        name: "Toonflow片尾".into(),
        file_path: String::new(),
        asset_type: "clip".into(),
    });

    let video: Vec<WorkbenchMaterialVideoItem> = sqlx::query_as(
        r#"
        SELECT
          v.numeric_id AS id,
          COALESCE(v.file_path, '') AS file_path,
          (
            SELECT vt.numeric_id
            FROM app_video_track vt
            WHERE vt.project_id = v.project_id
              AND (vt.select_video_id = v.numeric_id OR vt.video_id = v.id)
            ORDER BY vt.updated_at DESC, vt.created_at DESC, vt.id DESC
            LIMIT 1
          ) AS video_track_id
        FROM app_video v
        INNER JOIN app_project p ON p.id = v.project_id
        WHERE p.numeric_id = $1
          AND v.state IN ('生成成功', '已完成', 'succeeded', 'completed')
        ORDER BY v.numeric_id DESC
        "#,
    )
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(WorkbenchGetMaterialDataResponse { data, video })
}

pub(crate) async fn post_project_workbench_material_data(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(_body): Json<WorkbenchEmptyBody>,
) -> Result<Json<WorkbenchGetMaterialDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let project_numeric_id = ensure_owned_project_numeric_id(pool, uid, project_id).await?;
    let out = run_get_material_data(pool, project_numeric_id).await?;
    Ok(Json(out))
}
