//! 资产图片创建、部分更新与删除。

mod create;
mod delete;
mod patch;

pub(in crate::assets) use create::create_project_asset_image_for_project;
pub(in crate::assets) use delete::delete_project_asset_image_for_project;
pub(in crate::assets) use patch::patch_project_asset_image_for_project;
