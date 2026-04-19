//! 工作台视频轨添加与删除。

mod handlers;
mod types;

pub(crate) use handlers::{__path_post_workbench_add_track, __path_post_workbench_delete_track};
pub(in crate::production) use handlers::{post_workbench_add_track, post_workbench_delete_track};
