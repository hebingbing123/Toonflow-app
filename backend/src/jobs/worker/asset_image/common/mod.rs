//! 资产图片任务共享：下载、payload、落库。

mod download;
mod payload;
mod store;

pub(super) use payload::{payload_json_i32, AssetImageGenCtx};
pub(super) use store::{
    ensure_script_scoped_asset_exists, generate_and_store_asset_image,
    generate_and_store_asset_image_for_row,
};
