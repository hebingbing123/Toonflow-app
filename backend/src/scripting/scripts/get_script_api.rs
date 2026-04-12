//! `POST …/projects/{project_id}/scripts/get-script-api` — list scripts with optional name filter and related assets.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::types::{
    GetScriptApiNameBody, GetScriptApiRelatedAssetBrief, GetScriptApiResponse,
    GetScriptApiScriptListItem, GetScriptApiScriptRow,
};

pub(super) async fn get_script_api_for_project_uuid(
    pool: &PgPool,
    project_uuid: Uuid,
    name: Option<String>,
) -> Result<GetScriptApiResponse, ApiError> {
    let name_sub = name
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_lowercase());

    let scripts: Vec<GetScriptApiScriptRow> = if let Some(ref sub) = name_sub {
        sqlx::query_as::<_, GetScriptApiScriptRow>(
            r#"
            SELECT s.id, s.numeric_id, s.name, s.content, s.extract_state, s.error_reason, s.create_time_ms
            FROM app_script s
            WHERE s.project_id = $1
              AND s.name IS NOT NULL
              AND POSITION($2 IN LOWER(s.name)) > 0
            ORDER BY s.numeric_id ASC
            "#,
        )
        .bind(project_uuid)
        .bind(sub)
        .fetch_all(pool)
        .await
    } else {
        sqlx::query_as::<_, GetScriptApiScriptRow>(
            r#"
            SELECT s.id, s.numeric_id, s.name, s.content, s.extract_state, s.error_reason, s.create_time_ms
            FROM app_script s
            WHERE s.project_id = $1
            ORDER BY s.numeric_id ASC
            "#,
        )
        .bind(project_uuid)
        .fetch_all(pool)
        .await
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if scripts.is_empty() {
        return Ok(GetScriptApiResponse { data: vec![] });
    }

    let ids: Vec<Uuid> = scripts.iter().map(|s| s.id).collect();

    #[derive(Debug, sqlx::FromRow)]
    struct GetScriptApiAssetLinkRow {
        script_id: Uuid,
        #[sqlx(rename = "numeric_id")]
        numeric_id: i32,
        name: String,
    }

    let links: Vec<GetScriptApiAssetLinkRow> = sqlx::query_as::<_, GetScriptApiAssetLinkRow>(
        r#"
        SELECT sa.script_id, a.numeric_id, a.name
        FROM app_script_asset sa
        INNER JOIN app_asset a ON a.id = sa.asset_id
        WHERE sa.script_id = ANY($1)
        ORDER BY a.numeric_id ASC
        "#,
    )
    .bind(&ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut by_script: std::collections::HashMap<Uuid, Vec<GetScriptApiRelatedAssetBrief>> =
        std::collections::HashMap::new();
    for row in links {
        by_script
            .entry(row.script_id)
            .or_default()
            .push(GetScriptApiRelatedAssetBrief {
                id: row.numeric_id,
                name: row.name,
            });
    }

    let data = scripts
        .into_iter()
        .map(|s| {
            let related_assets = by_script.remove(&s.id).unwrap_or_default();
            GetScriptApiScriptListItem {
                id: s.numeric_id,
                name: s.name,
                content: s.content,
                extract_state: s.extract_state,
                error_reason: s.error_reason,
                create_time_ms: s.create_time_ms,
                related_assets,
            }
        })
        .collect();

    Ok(GetScriptApiResponse { data })
}

pub(super) async fn post_get_script_api_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<GetScriptApiNameBody>,
) -> Result<Json<GetScriptApiResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let response = get_script_api_for_project_uuid(pool, project_id, body.name).await?;
    Ok(Json(response))
}
