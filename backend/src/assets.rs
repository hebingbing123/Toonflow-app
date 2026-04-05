//! Project-scoped **`app_asset`** HTTP API and **`app_script_asset`** links (legacy listing / **`o_scriptAssets`** parity).

use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    routing::{get, post, put},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{types::Json as SqlxJson, FromRow, PgPool, Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::json_patch::{parse_optional_text_field, FieldPatch};
use crate::state::AppState;

const ADV_LOCK_ASSET_LEGACY: i64 = 884_422_004;
const MAX_ASSET_LIST_LIMIT: i64 = 200;

#[derive(Debug, FromRow, Serialize)]
pub struct AssetRow {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct ListAssetsQuery {
    /// When set, only assets linked to this script (**`app_script.legacy_id`**) within the project.
    #[serde(default)]
    pub script_legacy_id: Option<i32>,
    /// **`role`**, **`tool`**, or **`scene`** (legacy getAssetsApi **`type`**).
    #[serde(default)]
    pub asset_type: Option<String>,
    /// Case-insensitive substring match on **`name`** (SQL **`ILIKE`**).
    #[serde(default)]
    pub name: Option<String>,
    /// 1-based page when **`limit`** is set (default **1**).
    #[serde(default)]
    pub page: Option<u32>,
    /// Page size; omit for an unpaged list (all matching rows).
    #[serde(default)]
    pub limit: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct ListAssetsResponse {
    pub items: Vec<AssetRow>,
    pub total: i64,
}

/// Legacy **`POST /api/cornerScape/getAllAssets`**: top-level project assets (no child **`assetsId`** in
/// promoted **`metadata`**), ordered **role → scene → tool**. **`history_images`** is reserved (empty until
/// image rows exist in Postgres); **`metadata`** retains legacy snapshot fields (e.g. **`imageId`**).
#[derive(Debug, Serialize)]
pub struct CornerScapeAssetItem {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
    pub metadata: Value,
    pub history_images: Vec<Value>,
}

#[derive(Debug, Serialize)]
pub struct CornerScapeResponse {
    pub items: Vec<CornerScapeAssetItem>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct CornerScapeBody {
    /// When set and non-empty, restrict to these **`app_asset.asset_type`** values (**`role`**, **`scene`**, **`tool`**).
    #[serde(default)]
    types: Option<Vec<String>>,
}

#[derive(Debug, FromRow)]
struct CornerScapeDbRow {
    id: Uuid,
    legacy_id: i32,
    name: String,
    asset_type: String,
    description: Option<String>,
    create_time_ms: Option<i64>,
    metadata: SqlxJson<Value>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct CreateAssetBody {
    name: String,
    #[serde(rename = "type")]
    asset_type: String,
    #[serde(default)]
    description: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct PatchAssetBody {
    #[serde(default)]
    name: Option<Value>,
    #[serde(default)]
    description: Option<Value>,
    #[serde(default)]
    asset_type: Option<Value>,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets",
            get(list_project_assets).post(create_project_asset),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/corner-scape",
            post(list_corner_scape_assets),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}",
            get(get_project_asset_by_legacy)
                .patch(patch_project_asset_by_legacy)
                .delete(delete_project_asset_by_legacy),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/scripts/{script_legacy_id}/assets/{asset_legacy_id}",
            put(link_script_to_asset).delete(unlink_script_from_asset),
        )
}

/// Resolves **`app_script.id`** and **`app_asset.id`** when both belong to the same owned project.
async fn resolve_script_and_asset_in_project(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
    script_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<(Uuid, Uuid), ApiError> {
    let row: Option<(Uuid, Uuid)> = sqlx::query_as(
        r#"
        SELECT s.id, a.id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        INNER JOIN app_asset a ON a.project_id = p.id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND s.legacy_id = $3
          AND a.legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(script_legacy_id)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or(ApiError::NotFound)
}

async fn link_script_to_asset(
    State(state): State<AppState>,
    Path((project_legacy_id, script_legacy_id, asset_legacy_id)): Path<(i32, i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || script_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let (script_id, asset_id) = resolve_script_and_asset_in_project(
        pool,
        uid,
        project_legacy_id,
        script_legacy_id,
        asset_legacy_id,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_script_asset (script_id, asset_id)
        VALUES ($1, $2)
        ON CONFLICT (script_id, asset_id) DO NOTHING
        "#,
    )
    .bind(script_id)
    .bind(asset_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}

async fn unlink_script_from_asset(
    State(state): State<AppState>,
    Path((project_legacy_id, script_legacy_id, asset_legacy_id)): Path<(i32, i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || script_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let (script_id, asset_id) = resolve_script_and_asset_in_project(
        pool,
        uid,
        project_legacy_id,
        script_legacy_id,
        asset_legacy_id,
    )
    .await?;

    let res = sqlx::query(r#"DELETE FROM app_script_asset WHERE script_id = $1 AND asset_id = $2"#)
        .bind(script_id)
        .bind(asset_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn create_project_asset(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<CreateAssetBody>,
) -> Result<(StatusCode, Json<AssetRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }

    let name = body.name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let t = body.asset_type.trim().to_lowercase();
    if t != "role" && t != "tool" && t != "scene" {
        return Err(ApiError::BadRequest(
            "type must be role, tool, or scene".into(),
        ));
    }

    let desc = body
        .description
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2"#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let exists: bool = sqlx::query_scalar(
        r#"SELECT EXISTS (SELECT 1 FROM app_asset WHERE project_id = $1 AND name = $2)"#,
    )
    .bind(project_uuid)
    .bind(&name)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if exists {
        tx.rollback().await.ok();
        return Err(ApiError::Conflict(
            "an asset with this name already exists in the project".into(),
        ));
    }

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_LEGACY)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(legacy_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        INSERT INTO app_asset (
          project_id, legacy_id, name, asset_type, description, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
        RETURNING id, legacy_id, name, asset_type, description, create_time_ms
        "#,
    )
    .bind(project_uuid)
    .bind(next_legacy)
    .bind(&name)
    .bind(&t)
    .bind(desc)
    .bind(now_ms)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

fn normalize_list_asset_type_filter(raw: Option<String>) -> Result<Option<String>, ApiError> {
    let Some(s) = raw else {
        return Ok(None);
    };
    let t = s.trim().to_lowercase();
    if t.is_empty() {
        return Ok(None);
    }
    if t != "role" && t != "tool" && t != "scene" {
        return Err(ApiError::BadRequest(
            "asset_type must be role, tool, or scene".into(),
        ));
    }
    Ok(Some(t))
}

fn normalize_name_ilike(raw: Option<String>) -> Option<String> {
    raw.and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(format!("%{t}%"))
        }
    })
}

/// Returns **`None`** when the filter is absent or empty (no type restriction).
fn normalize_corner_types_filter(
    raw: Option<Vec<String>>,
) -> Result<Option<Vec<String>>, ApiError> {
    let Some(list) = raw else {
        return Ok(None);
    };
    if list.is_empty() {
        return Ok(None);
    }
    let mut out = Vec::new();
    for s in list {
        let t = s.trim().to_lowercase();
        if t != "role" && t != "scene" && t != "tool" {
            return Err(ApiError::BadRequest(format!(
                "types entries must be role, scene, or tool (got {s:?})"
            )));
        }
        out.push(t);
    }
    Ok(Some(out))
}

async fn list_corner_scape_assets(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<CornerScapeBody>,
) -> Result<Json<CornerScapeResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }

    let type_filter = normalize_corner_types_filter(body.types)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(project_legacy_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
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
        a.legacy_id ASC
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
            legacy_id: r.legacy_id,
            name: r.name,
            asset_type: r.asset_type,
            description: r.description,
            create_time_ms: r.create_time_ms,
            metadata: r.metadata.0,
            history_images: Vec::new(),
        })
        .collect();

    Ok(Json(CornerScapeResponse { items }))
}

async fn count_project_assets_filtered(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    script_legacy_id: Option<i32>,
    asset_type: Option<&str>,
    name_ilike: Option<&str>,
) -> Result<i64, ApiError> {
    let mut qb: QueryBuilder<Postgres> = if let Some(sid) = script_legacy_id {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT COUNT(DISTINCT a.id)::BIGINT
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            INNER JOIN app_script_asset sa ON sa.asset_id = a.id
            INNER JOIN app_script s ON s.id = sa.script_id AND s.project_id = a.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb.push(" AND s.legacy_id = ");
        qb.push_bind(sid);
        qb
    } else {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT COUNT(a.id)::BIGINT
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb
    };
    if let Some(t) = asset_type {
        qb.push(" AND a.asset_type = ");
        qb.push_bind(t);
    }
    if let Some(pat) = name_ilike {
        qb.push(" AND a.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn select_project_assets_filtered(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    script_legacy_id: Option<i32>,
    asset_type: Option<&str>,
    name_ilike: Option<&str>,
    limit_offset: Option<(i64, i64)>,
) -> Result<Vec<AssetRow>, ApiError> {
    let mut qb: QueryBuilder<Postgres> = if let Some(sid) = script_legacy_id {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT DISTINCT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            INNER JOIN app_script_asset sa ON sa.asset_id = a.id
            INNER JOIN app_script s ON s.id = sa.script_id AND s.project_id = a.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb.push(" AND s.legacy_id = ");
        qb.push_bind(sid);
        qb
    } else {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb
    };
    if let Some(t) = asset_type {
        qb.push(" AND a.asset_type = ");
        qb.push_bind(t);
    }
    if let Some(pat) = name_ilike {
        qb.push(" AND a.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(" ORDER BY a.legacy_id ASC ");
    if let Some((lim, off)) = limit_offset {
        qb.push(" LIMIT ");
        qb.push_bind(lim);
        qb.push(" OFFSET ");
        qb.push_bind(off);
    }
    qb.build_query_as::<AssetRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn list_project_assets(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    Query(query): Query<ListAssetsQuery>,
    headers: HeaderMap,
) -> Result<Json<ListAssetsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }

    if let Some(sid) = query.script_legacy_id {
        if sid <= 0 {
            return Err(ApiError::BadRequest(
                "script_legacy_id must be positive when set".into(),
            ));
        }
        let script_ok: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS (
              SELECT 1
              FROM app_script s
              INNER JOIN app_project p ON p.id = s.project_id
              WHERE p.legacy_id = $1
                AND p.owner_user_id = $2
                AND s.legacy_id = $3
            )
            "#,
        )
        .bind(project_legacy_id)
        .bind(uid)
        .bind(sid)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if !script_ok {
            return Err(ApiError::NotFound);
        }
    }

    let type_filter = normalize_list_asset_type_filter(query.asset_type)?;
    let name_pat = normalize_name_ilike(query.name);
    let type_ref = type_filter.as_deref();
    let name_ref = name_pat.as_deref();

    let limit_clamped = match query.limit {
        None => None,
        Some(0) => {
            return Err(ApiError::BadRequest(
                "limit must be positive or omitted".into(),
            ));
        }
        Some(l) => Some(i64::from(l).min(MAX_ASSET_LIST_LIMIT)),
    };

    if query.page.is_some() && limit_clamped.is_none() {
        let p = query.page.unwrap_or(1);
        if p != 1 {
            return Err(ApiError::BadRequest(
                "page is only valid together with limit".into(),
            ));
        }
    }

    let page = query.page.unwrap_or(1);
    if page == 0 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }

    let limit_offset = limit_clamped.map(|lim| {
        let off = i64::from(page.saturating_sub(1)) * lim;
        (lim, off)
    });

    let (items, total) = if limit_offset.is_some() {
        let total = count_project_assets_filtered(
            pool,
            project_legacy_id,
            uid,
            query.script_legacy_id,
            type_ref,
            name_ref,
        )
        .await?;
        let items = select_project_assets_filtered(
            pool,
            project_legacy_id,
            uid,
            query.script_legacy_id,
            type_ref,
            name_ref,
            limit_offset,
        )
        .await?;
        (items, total)
    } else {
        let items = select_project_assets_filtered(
            pool,
            project_legacy_id,
            uid,
            query.script_legacy_id,
            type_ref,
            name_ref,
            None,
        )
        .await?;
        let total = items.len() as i64;
        (items, total)
    };

    Ok(Json(ListAssetsResponse { items, total }))
}

async fn get_project_asset_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        SELECT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

fn parse_asset_type_patch(v: Option<Value>) -> Result<FieldPatch<String>, ApiError> {
    let p = parse_optional_text_field(v, "asset_type")?;
    match &p {
        FieldPatch::Absent => Ok(FieldPatch::Absent),
        FieldPatch::Set(None) => Err(ApiError::BadRequest(
            "asset_type cannot be null; omit or set role|tool|scene".into(),
        )),
        FieldPatch::Set(Some(s)) => {
            let t = s.trim().to_lowercase();
            if t != "role" && t != "tool" && t != "scene" {
                return Err(ApiError::BadRequest(
                    "asset_type must be role, tool, or scene".into(),
                ));
            }
            Ok(FieldPatch::Set(Some(t)))
        }
    }
}

async fn patch_project_asset_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchAssetBody>,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let name_patch = parse_optional_text_field(body.name, "name")?;
    let desc_patch = parse_optional_text_field(body.description, "description")?;
    let type_patch = parse_asset_type_patch(body.asset_type)?;

    if matches!(name_patch, FieldPatch::Absent)
        && matches!(desc_patch, FieldPatch::Absent)
        && matches!(type_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: name, description, asset_type".into(),
        ));
    }

    let current = sqlx::query_as::<_, AssetRow>(
        r#"
        SELECT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let new_name = match &name_patch {
        FieldPatch::Absent => current.name.clone(),
        FieldPatch::Set(v) => v.clone().unwrap_or_default(),
    };
    if new_name.trim().is_empty() {
        return Err(ApiError::BadRequest("name cannot be empty".into()));
    }

    let new_desc = match &desc_patch {
        FieldPatch::Absent => current.description.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_type = match &type_patch {
        FieldPatch::Absent => current.asset_type.clone(),
        FieldPatch::Set(Some(t)) => t.clone(),
        FieldPatch::Set(None) => {
            return Err(ApiError::BadRequest(
                "asset_type cannot be null; omit or set role|tool|scene".into(),
            ));
        }
    };

    if matches!(&name_patch, FieldPatch::Set(_)) && new_name != current.name {
        let clash: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS (
              SELECT 1
              FROM app_asset a
              INNER JOIN app_project p ON p.id = a.project_id
              WHERE p.legacy_id = $1
                AND p.owner_user_id = $2
                AND a.name = $3
                AND a.legacy_id <> $4
            )
            "#,
        )
        .bind(project_legacy_id)
        .bind(uid)
        .bind(&new_name)
        .bind(asset_legacy_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if clash {
            return Err(ApiError::Conflict(
                "another asset in this project already uses that name".into(),
            ));
        }
    }

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        UPDATE app_asset a
        SET name = $1,
            description = $2,
            asset_type = $3,
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.legacy_id = $4
          AND p.owner_user_id = $5
          AND a.legacy_id = $6
        RETURNING a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
        "#,
    )
    .bind(&new_name)
    .bind(&new_desc)
    .bind(&new_type)
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn delete_project_asset_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let res = sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_asset_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<PatchAssetBody>(r#"{"name":"a","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn create_asset_body_accepts_minimal() {
        let b: CreateAssetBody = serde_json::from_str(r#"{"name":"Hero","type":"role"}"#).unwrap();
        assert_eq!(b.name, "Hero");
        assert_eq!(b.asset_type, "role");
    }
}
