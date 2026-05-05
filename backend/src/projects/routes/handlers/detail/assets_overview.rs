//! 项目级统一资产总览（C5）：按 **`asset_type`** 分组，附带 **`candidate_status`** 与关联剧本 **`numeric_id`**。
//!
//! 分镜维度的资产挂载暂无一等 FK；**`linked_script_numeric_ids`** 通过 **`app_script_asset`** 推导，供 Space / 制作编排引用。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use sqlx::FromRow;
use std::collections::HashMap;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::{
    AssetsOverviewCandidateCounts, AssetsOverviewItem, AssetsOverviewTypeGroup,
    ProjectAssetsOverviewResponse,
};

#[derive(Debug, FromRow)]
struct AssetOverviewDbRow {
    asset_id: Uuid,
    numeric_id: i32,
    name: String,
    asset_type: String,
    candidate_status: Option<String>,
    script_numeric_ids: Vec<i32>,
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/assets-overview",
    operation_id = "getProjectAssetsOverviewByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectAssetsOverviewResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_assets_overview_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectAssetsOverviewResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let row: Option<(Uuid,)> = sqlx::query_as(
        r#"
        SELECT id
        FROM app_project
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (resolved_id,) = row.ok_or(ApiError::NotFound)?;

    let rows: Vec<AssetOverviewDbRow> = sqlx::query_as(
        r#"
        SELECT
          a.id AS asset_id,
          a.numeric_id,
          a.name,
          a.asset_type,
          a.candidate_status,
          COALESCE(
            ARRAY_AGG(DISTINCT s.numeric_id) FILTER (WHERE s.numeric_id IS NOT NULL),
            ARRAY[]::integer[]
          ) AS script_numeric_ids
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id AND p.owner_user_id = $2
        LEFT JOIN app_script_asset sa ON sa.asset_id = a.id
        LEFT JOIN app_script s ON s.id = sa.script_id AND s.project_id = a.project_id
        WHERE a.project_id = $1
        GROUP BY a.id, a.numeric_id, a.name, a.asset_type, a.candidate_status
        ORDER BY a.asset_type ASC, a.numeric_id ASC
        "#,
    )
    .bind(resolved_id)
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_count = rows.len() as i64;
    let mut pending = 0_i64;
    let mut linked = 0_i64;
    let mut ignored = 0_i64;
    let mut unset = 0_i64;

    let mut by_type: HashMap<String, Vec<AssetsOverviewItem>> = HashMap::new();

    for r in rows {
        match r.candidate_status.as_deref() {
            Some("pending") => pending += 1,
            Some("linked") => linked += 1,
            Some("ignored") => ignored += 1,
            None => unset += 1,
            Some(_) => unset += 1,
        }

        let item = AssetsOverviewItem {
            asset_id: r.asset_id,
            numeric_id: r.numeric_id,
            name: r.name,
            asset_type: r.asset_type.clone(),
            candidate_status: r.candidate_status,
            linked_script_numeric_ids: r.script_numeric_ids,
        };

        by_type.entry(r.asset_type).or_default().push(item);
    }

    let type_order = ["role", "scene", "tool"];
    let mut by_asset_type: Vec<AssetsOverviewTypeGroup> = Vec::new();
    for t in type_order {
        if let Some(items) = by_type.remove(t) {
            by_asset_type.push(AssetsOverviewTypeGroup {
                asset_type: t.to_string(),
                items,
            });
        }
    }
    for (t, items) in by_type {
        by_asset_type.push(AssetsOverviewTypeGroup {
            asset_type: t,
            items,
        });
    }

    Ok(Json(ProjectAssetsOverviewResponse {
        schema_version: 1,
        total_count,
        candidate_counts: AssetsOverviewCandidateCounts {
            pending,
            linked,
            ignored,
            unset,
        },
        by_asset_type,
    }))
}
