//! REST CRUD for assets, corner-scape listing, and script-asset links.
//! Asset image CRUD lives in [`super::crud_images`].

mod corner_scape;
mod create;
mod detail;
mod links;
mod list;
mod patch_delete;
mod resolve;

pub(crate) use corner_scape::list_corner_scape_assets;
pub(crate) use create::create_project_asset;
pub(crate) use detail::get_project_asset_by_legacy;
pub(crate) use links::{link_script_to_asset, unlink_script_from_asset};
pub(crate) use list::list_project_assets;
pub(crate) use patch_delete::{delete_project_asset_by_legacy, patch_project_asset_by_legacy};
pub use resolve::{next_asset_image_sort_index, resolve_asset_id_for_job};
pub(crate) use resolve::{resolve_owned_asset_id, resolve_owned_asset_id_and_metadata};
