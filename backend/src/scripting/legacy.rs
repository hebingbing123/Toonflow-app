//! 遗留 `POST /api/script/getScrptApi` — 列出项目下的脚本及其关联资产摘要。

use axum::{
    extract::{Json, Path, State},
    http::HeaderMap,
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetScriptApiBody {
    project_id: i32,
    #[serde(default)]
    name: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct GetScriptApiNameBody {
    #[serde(default)]
    name: Option<String>,
}

#[derive(Debug, FromRow)]
struct ScriptListRow {
    id: Uuid,
    legacy_id: i32,
    name: Option<String>,
    content: Option<String>,
    extract_state: Option<i32>,
    error_reason: Option<String>,
    create_time_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
struct RelatedAssetBrief {
    id: i32,
    name: String,
}

#[derive(Debug, Serialize)]
struct LegacyScriptListItem {
    id: i32,
    name: Option<String>,
    content: Option<String>,
    #[serde(rename = "extractState")]
    extract_state: Option<i32>,
    #[serde(rename = "errorReason")]
    error_reason: Option<String>,
    #[serde(rename = "createTime")]
    create_time_ms: Option<i64>,
    #[serde(rename = "relatedAssets")]
    related_assets: Vec<RelatedAssetBrief>,
}

#[derive(Debug, Serialize)]
struct GetScriptApiResponse {
    data: Vec<LegacyScriptListItem>,
}

async fn get_script_api_for_project_uuid(
    pool: &PgPool,
    project_uuid: Uuid,
    name: Option<String>,
) -> Result<GetScriptApiResponse, ApiError> {
    let name_sub = name
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_lowercase());

    let scripts: Vec<ScriptListRow> = if let Some(ref sub) = name_sub {
        sqlx::query_as::<_, ScriptListRow>(
            r#"
            SELECT s.id, s.legacy_id, s.name, s.content, s.extract_state, s.error_reason, s.create_time_ms
            FROM app_script s
            WHERE s.project_id = $1
              AND s.name IS NOT NULL
              AND POSITION($2 IN LOWER(s.name)) > 0
            ORDER BY s.legacy_id ASC
            "#,
        )
        .bind(project_uuid)
        .bind(sub)
        .fetch_all(pool)
        .await
    } else {
        sqlx::query_as::<_, ScriptListRow>(
            r#"
            SELECT s.id, s.legacy_id, s.name, s.content, s.extract_state, s.error_reason, s.create_time_ms
            FROM app_script s
            WHERE s.project_id = $1
            ORDER BY s.legacy_id ASC
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

    #[derive(Debug, FromRow)]
    struct AssetLinkRow {
        script_id: Uuid,
        legacy_id: i32,
        name: String,
    }

    let links: Vec<AssetLinkRow> = sqlx::query_as::<_, AssetLinkRow>(
        r#"
        SELECT sa.script_id, a.legacy_id, a.name
        FROM app_script_asset sa
        INNER JOIN app_asset a ON a.id = sa.asset_id
        WHERE sa.script_id = ANY($1)
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(&ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut by_script: std::collections::HashMap<Uuid, Vec<RelatedAssetBrief>> =
        std::collections::HashMap::new();
    for row in links {
        by_script
            .entry(row.script_id)
            .or_default()
            .push(RelatedAssetBrief {
                id: row.legacy_id,
                name: row.name,
            });
    }

    let data = scripts
        .into_iter()
        .map(|s| {
            let related_assets = by_script.remove(&s.id).unwrap_or_default();
            LegacyScriptListItem {
                id: s.legacy_id,
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

async fn post_get_script_api_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<GetScriptApiNameBody>,
) -> Result<JsonResponse<GetScriptApiResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let response = get_script_api_for_project_uuid(pool, project_id, body.name).await?;
    Ok(JsonResponse(response))
}

async fn post_get_script_api(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetScriptApiBody>,
) -> Result<JsonResponse<GetScriptApiResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let project_uuid: Uuid = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(body.project_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let response = get_script_api_for_project_uuid(pool, project_uuid, body.name).await?;
    Ok(JsonResponse(response))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/projects/{project_id}/scripts/get-script-api",
            post(post_get_script_api_for_project),
        )
        .route("/api/v1/scripts/get-script-api", post(post_get_script_api))
}
