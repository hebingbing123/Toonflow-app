//! 父子资产树：COUNT、父行、子行与组装。

mod assemble;
mod fetch;

use crate::assets::models::*;
use crate::assets::utils::MAX_ASSET_LIST_LIMIT;
use crate::error::ApiError;

use assemble::build_nested_assets_response;
use fetch::{count_nested_assets, fetch_child_rows, fetch_parent_rows};

pub(super) async fn run_get_assets_api(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_numeric_id: i32,
    body: &WorkbenchNestedAssetsBody,
) -> Result<WorkbenchGetAssetsApiResponse, ApiError> {
    let asset_type = body.asset_type.trim().to_lowercase();
    let page = body.page.unwrap_or(1);
    let limit = body.limit.unwrap_or(10);
    let limit = i64::from(limit).min(MAX_ASSET_LIST_LIMIT);
    let offset = i64::from(page - 1) * limit;

    let name_pattern = body
        .name
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| format!("%{s}%"));

    let total = count_nested_assets(
        pool,
        uid,
        project_numeric_id,
        &asset_type,
        name_pattern.as_deref(),
    )
    .await?;

    let parents = fetch_parent_rows(
        pool,
        uid,
        project_numeric_id,
        &asset_type,
        name_pattern.as_deref(),
        limit,
        offset,
    )
    .await?;

    let children = fetch_child_rows(
        pool,
        uid,
        project_numeric_id,
        &asset_type,
        name_pattern.as_deref(),
    )
    .await?;

    Ok(build_nested_assets_response(
        total,
        parents,
        children,
        project_numeric_id,
    ))
}
