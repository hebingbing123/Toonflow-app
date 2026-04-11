//! 分页项目资产列表（`GET …/assets`）。
//!
//! 支持按类型、名称过滤的分页查询。

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use sqlx::{PgPool, Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::models::*;
use super::super::{normalize_list_asset_type_filter, normalize_name_ilike, MAX_ASSET_LIST_LIMIT};

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

pub(crate) async fn list_project_assets(
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
