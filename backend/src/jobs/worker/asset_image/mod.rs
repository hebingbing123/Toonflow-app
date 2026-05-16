//! 图片生成任务（`asset.generate.*`）— OpenAI 图片 API + `app_asset_image` 行。

mod batch;
mod common;
mod generate;
mod production;

pub(super) use batch::run_asset_generate_batch;
pub(super) use generate::run_asset_generate_image;
