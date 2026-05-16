//! 分镜批量/单条添加 API。

mod handlers;
mod prepare;
mod types;

#[cfg(test)]
mod tests;

pub(crate) use handlers::{__path_post_storyboard_add, __path_post_storyboard_batch_add_info};
pub(in crate::production) use handlers::{post_storyboard_add, post_storyboard_batch_add_info};
