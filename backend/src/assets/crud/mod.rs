//! 资产的 REST CRUD 操作、角景列表和脚本-资产关联。
//!
//! 子模块：
//! - `create` — 创建资产
//! - `detail` — 获取资产详情
//! - `list` — 分页列出资产
//! - `patch_delete` — 更新或删除资产
//! - `corner_scape` — 角景资产查询
//! - `links` — 脚本-资产关联管理
//! - `resolve` — 资产 ID 解析辅助函数
//!
//! 资产图片的 CRUD 位于 [`super::crud_images`]。

mod corner_scape;
mod create;
mod detail;
mod links;
mod list;
mod patch_delete;
mod resolve;

pub(crate) use corner_scape::list_corner_scape_assets;
pub(crate) use create::create_project_asset;
pub(crate) use detail::get_project_asset_by_legacy;
pub(crate) use links::{link_script_to_asset, unlink_script_from_asset};
pub(crate) use list::list_project_assets;
pub(crate) use patch_delete::{delete_project_asset_by_legacy, patch_project_asset_by_legacy};
pub use resolve::{next_asset_image_sort_index, resolve_asset_id_for_job};
pub(crate) use resolve::{resolve_owned_asset_id, resolve_owned_asset_id_and_metadata};
