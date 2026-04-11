//! Legacy POST asset read/query operations (get-assets-api, get-image, upload-clip, material, polling).

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
