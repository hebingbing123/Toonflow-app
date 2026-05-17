//! 制作工作台 HTTP 处理器（**`/api/v1/production/*`**）。

pub mod assets;
pub(crate) mod confirm_storyboard_candidates;
pub mod edit_image;
pub mod flow;
pub(crate) mod generation_guards;
pub(crate) mod generation_profile;
pub mod meta;
pub mod storyboard;
pub mod storyboard_media_op;
pub mod storyboard_ops;
pub mod track;
pub mod video;
pub mod video_prompt_memory;
pub mod voiceover;
pub mod voiceover_preview;

#[allow(unused_imports)]
pub(crate) use confirm_storyboard_candidates::__path_post_workbench_confirm_storyboard_candidates;
pub(in crate::production) use confirm_storyboard_candidates::post_workbench_confirm_storyboard_candidates;

#[allow(unused_imports)]
pub(crate) use storyboard_media_op::__path_post_workbench_storyboard_media_op;
pub(in crate::production) use storyboard_media_op::post_workbench_storyboard_media_op;
