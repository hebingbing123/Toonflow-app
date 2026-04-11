//! 遗留 POST 资产读取/查询操作。
//!
//! 子模块：
//! - `get_assets_api` — 获取资产树
//! - `get_image` — 获取资产图片
//! - `upload_clip` — 上传片段
//! - `material` — 素材数据
//! - `polling` — 轮询状态
//! - `batch_generation` — 批量生成数据

mod batch_generation;
mod get_assets_api;
mod get_image;
mod material;
mod polling;
mod upload_clip;

pub(crate) use batch_generation::post_legacy_batch_generation_data;
pub(crate) use get_assets_api::post_legacy_get_assets_api;
pub(crate) use get_image::post_legacy_get_image;
pub(crate) use material::post_legacy_get_material_data;
pub(crate) use polling::{post_legacy_polling_image_assets, post_legacy_polling_prompt_assets};
pub(crate) use upload_clip::post_legacy_upload_clip;
