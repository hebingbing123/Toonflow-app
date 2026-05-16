//! 小说事件更新、删除、批量删除与生成抽取任务。

mod delete;
mod generate;
mod update;

pub(crate) use delete::{batch_delete_novel_events_for_project, delete_novel_event_for_project};
pub(crate) use generate::post_generate_novel_events_for_project;
pub(crate) use update::update_novel_event_for_project;
