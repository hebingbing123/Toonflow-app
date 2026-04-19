//! 分镜 PATCH / DELETE（按项目 UUID + numeric id）。

mod delete;
mod handlers;
mod patch;

pub(in crate::narrative::storyboards) use handlers::{
    delete_by_numeric_id_for_project, patch_by_numeric_id_for_project,
};
