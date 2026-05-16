mod facade;
mod persist;

pub(crate) use facade::{ensure_script_scoped_asset_exists, generate_and_store_asset_image};
pub(crate) use persist::generate_and_store_asset_image_for_row;
