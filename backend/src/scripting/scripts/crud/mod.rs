//! Project-scoped script CRUD and batch-add.

mod create;
mod patch_delete;
mod read;
mod tx;

pub(super) use create::{
    create_script_under_project_for_project, post_scripts_batch_add_for_project,
};
pub(super) use patch_delete::{delete_script_for_project, patch_script_for_project};
pub(super) use read::get_script_for_project;
