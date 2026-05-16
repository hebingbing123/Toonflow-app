//! 工作台添加 / 删除视频轨。

mod add_track;
mod delete_track;

pub(crate) use add_track::__path_post_workbench_add_track;
pub(in crate::production) use add_track::post_workbench_add_track;
pub(crate) use delete_track::__path_post_workbench_delete_track;
pub(in crate::production) use delete_track::post_workbench_delete_track;
