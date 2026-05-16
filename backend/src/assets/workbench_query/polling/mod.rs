//! 资产图片 / prompt 轮询（项目 UUID 路径）。

mod image_assets;
mod prompt_assets;
mod validate;

pub(crate) use image_assets::post_project_workbench_polling_image_assets;
pub(crate) use prompt_assets::post_project_workbench_polling_prompt_assets;
