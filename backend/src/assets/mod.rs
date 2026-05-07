//! 资产模块：项目范围的 `app_asset` HTTP API 和 `app_script_asset` 关联。
//!
//! 子模块：
//! - `models` — 请求/响应类型
//! - `utils` — 共享工具函数与常量
//! - `router` — 路由注册
//! - `workbench_write` — **`…/projects/{project_id}/assets/workbench/*`** 写入（添加/更新/保存/删除）
//! - `workbench_query` — 同上路径前缀下的查询/轮询/上传 clip
//! - `crud` — REST CRUD 资产操作、角景、脚本-资产关联
//! - `crud_images` — 资产图片 REST CRUD
//! - `generate` — 遗留 `/api/assetsGenerate/*` 入队和取消

mod crud;
mod crud_images;
mod generate;
pub mod models;
mod openapi;
mod router;
pub(super) mod utils;
mod workbench_query;
mod workbench_write;

pub use crud::{
    next_asset_image_sort_index, resolve_asset_id_for_job,
    resolve_owned_script_linked_asset_row_for_job,
};

/// Shared by other domains (e.g. narrative novels) that scope rows by **`app_project.id`**.
pub(crate) use crud::{ensure_owned_project_numeric_id, ensure_owned_project_pk};

pub use openapi::AssetsSchemasOpenApi;
pub use router::router;

// ── Module-level public constant (used by other crate modules) ───────────────
pub(crate) const ADV_LOCK_ASSET_NUMERIC: i64 = 884_422_004;

// ── Tests ────────────────────────────────────────────────────────────────────
#[cfg(test)]
mod tests;
