//! 制作工作台 HTTP 处理器（**`/api/v1/production/*`**）。

pub mod assets;
pub mod edit_image;
pub mod flow;
pub mod meta;
pub mod storyboard;
pub mod storyboard_media_op;
pub mod storyboard_ops;
pub mod track;
pub mod video;
pub mod video_prompt_memory;
pub mod voiceover;

#[allow(unused_imports)]
pub(crate) use storyboard_media_op::__path_post_workbench_storyboard_media_op;
pub(in crate::production) use storyboard_media_op::post_workbench_storyboard_media_op;
