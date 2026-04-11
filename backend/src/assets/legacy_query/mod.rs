//! 资产工作台查询（**`POST …/projects/{project_id}/assets/workbench/*`**）。

mod batch_generation;
mod get_assets_api;
mod get_image;
mod material;
mod polling;
mod upload_clip;

pub(crate) use batch_generation::post_project_workbench_batch_generation_data;
pub(crate) use get_assets_api::post_project_workbench_nested_assets;
pub(crate) use get_image::post_project_workbench_image_bundle;
pub(crate) use material::post_project_workbench_material_data;
pub(crate) use polling::{
    post_project_workbench_polling_image_assets, post_project_workbench_polling_prompt_assets,
};
pub(crate) use upload_clip::post_project_workbench_upload_clip;
