//! `PATCH` / `DELETE` project asset by stable numeric ids.

mod delete;
mod helpers;
mod patch;

pub(crate) use delete::delete_project_asset_for_project;
pub(crate) use patch::patch_project_asset_for_project;
