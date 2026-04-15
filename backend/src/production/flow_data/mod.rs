//! 制作流程 JSON 加载与项目/剧本归属解析。
//!
//! 供 **`/api/v1/production/get-flow-data`** 与 Harness 工具共用，与 **`production`** 路由模块解耦（共享领域逻辑而非 HTTP 树）。
//!
//! **归属**：剧本级 UUID 解析使用 [`crate::scope::owned_script_scope`]；本模块再读取 `app_script.content` 等制作流所需字段。

use serde_json::Value;
use uuid::Uuid;

use crate::error::ApiError;
use crate::scope;

mod compose;
mod rows;

/// Resolve caller-owned project + script UUIDs from stable integer ids (Electron-era keys).
pub(crate) async fn resolve_owned_production_scope(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(Uuid, Uuid, Option<String>), ApiError> {
    let scope = scope::owned_script_scope(pool, uid, project_numeric_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let script_content = rows::fetch_script_content(pool, scope.script_id).await?;
    Ok((scope.project_id, scope.script_id, script_content))
}

async fn load_production_flow_json(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    script_id: Uuid,
    script_content: Option<String>,
) -> Result<Value, ApiError> {
    let saved = rows::fetch_saved_flow(pool, project_id, script_id).await?;
    let asset_rows = rows::fetch_asset_rows(pool, project_id, script_id).await?;
    let storyboard_rows = rows::fetch_storyboard_rows(pool, script_id).await?;

    let root_assets = compose::build_root_assets(&asset_rows);
    let storyboard_items = compose::build_storyboard_items(saved.as_object(), storyboard_rows);
    Ok(compose::merge_flow(
        saved,
        script_content,
        root_assets,
        storyboard_items,
    ))
}

pub(crate) async fn load_owned_production_flow_json(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<Value, ApiError> {
    let (project_id, script_id, script_content) =
        resolve_owned_production_scope(pool, uid, project_numeric_id, script_numeric_id).await?;
    load_production_flow_json(pool, project_id, script_id, script_content).await
}
