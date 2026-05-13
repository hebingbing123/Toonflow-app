//! 资产列表业务逻辑（校验、分页、聚合计数）。

use axum::Json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{bad_request_i18n, ApiError};
use crate::scope;

use super::super::super::models::*;
use super::super::super::utils::{
    normalize_list_asset_type_filter, normalize_name_ilike, MAX_ASSET_LIST_LIMIT,
};
use super::filtered::{count_project_assets_filtered, select_project_assets_filtered};

pub(super) async fn list_project_assets_inner(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    query: ListAssetsQuery,
) -> Result<Json<ListAssetsResponse>, ApiError> {
    if let Some(sid) = query.script_numeric_id {
        if sid <= 0 {
            return Err(bad_request_i18n(
                "script_numeric_id must be positive when set",
                "script_numeric_id 设置时必须为正数",
            ));
        }
        scope::owned_script_in_project(pool, uid, project_id, sid)
            .await
            .map_err(|e| e.into_api_error())?;
    }

    let type_filter = normalize_list_asset_type_filter(query.asset_type)?;
    let name_pat = normalize_name_ilike(query.name);
    let type_ref = type_filter.as_deref();
    let name_ref = name_pat.as_deref();

    let limit_clamped = match query.limit {
        None => None,
        Some(0) => {
            return Err(bad_request_i18n(
                "limit must be positive or omitted",
                "limit 必须为正数，或省略该字段",
            ));
        }
        Some(l) => Some(i64::from(l).min(MAX_ASSET_LIST_LIMIT)),
    };

    if query.page.is_some() && limit_clamped.is_none() {
        let p = query.page.unwrap_or(1);
        if p != 1 {
            return Err(bad_request_i18n(
                "page is only valid together with limit",
                "page 只能与 limit 一起使用",
            ));
        }
    }

    let page = query.page.unwrap_or(1);
    if page == 0 {
        return Err(bad_request_i18n("page must be >= 1", "page 必须大于等于 1"));
    }

    let limit_offset = limit_clamped.map(|lim| {
        let off = i64::from(page.saturating_sub(1)) * lim;
        (lim, off)
    });

    let (items, total) = if limit_offset.is_some() {
        let total = count_project_assets_filtered(
            pool,
            project_id,
            uid,
            query.script_numeric_id,
            type_ref,
            name_ref,
        )
        .await?;
        let items = select_project_assets_filtered(
            pool,
            project_id,
            uid,
            query.script_numeric_id,
            type_ref,
            name_ref,
            limit_offset,
        )
        .await?;
        (items, total)
    } else {
        let items = select_project_assets_filtered(
            pool,
            project_id,
            uid,
            query.script_numeric_id,
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
