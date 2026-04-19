//! 与 [`super::super::crud_images`] 和后台任务共享的辅助函数。
//!
//! 资产 ID 解析（UUID 项目段）与元数据解析；队列侧仍可按 **`project_numeric_id`** 解析（见 **`resolve_asset_id_for_job`**）。

mod job_asset;
mod owned_asset;
mod project_access;

pub use job_asset::{
    next_asset_image_sort_index, resolve_asset_id_for_job,
    resolve_owned_script_linked_asset_row_for_job,
};
pub(crate) use owned_asset::{
    resolve_owned_asset_id_and_metadata_for_project, resolve_owned_asset_id_for_project,
};
pub(crate) use project_access::{ensure_owned_project_numeric_id, ensure_owned_project_pk};
