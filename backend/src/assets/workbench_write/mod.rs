//! 资产变更辅助端点（**`POST …/projects/{project_id}/assets/workbench/*`**）。

mod add_update;
mod delete;
mod save;

pub(super) use add_update::{
    post_project_workbench_add_assets, post_project_workbench_update_assets,
};
pub(super) use delete::{
    post_project_workbench_batch_delete_assets, post_project_workbench_del_assets,
    post_project_workbench_del_image,
};
pub(super) use save::post_project_workbench_save_assets;
