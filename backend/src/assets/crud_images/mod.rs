//! 资产图片 REST CRUD 操作。
//!
//! 处理 `app_asset_image` 行的列表、获取、文件、创建、更新和删除操作。
//! 端点路径：`/api/v1/projects/{project_id}/assets/{asset_numeric_id}/images`

mod file;
mod list;
mod mutate;

pub(super) use file::get_project_asset_image_file_for_project;
pub(super) use list::{get_project_asset_image_for_project, list_project_asset_images_for_project};
pub(super) use mutate::{
    create_project_asset_image_for_project, delete_project_asset_image_for_project,
    patch_project_asset_image_for_project,
};
