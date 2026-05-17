//! 分镜编辑、删帧、更新 URL。

mod handlers;
mod types;

#[cfg(test)]
mod tests;

pub(crate) use handlers::{
    __path_post_storyboard_edit_info, __path_post_storyboard_remove_frame,
    __path_post_storyboard_set_character, __path_post_storyboard_update_duration,
    __path_post_storyboard_update_live_action_reference, __path_post_storyboard_update_url,
};
pub(in crate::production) use handlers::{
    post_storyboard_edit_info, post_storyboard_remove_frame, post_storyboard_set_character,
    post_storyboard_update_duration, post_storyboard_update_live_action_reference,
    post_storyboard_update_url,
};
