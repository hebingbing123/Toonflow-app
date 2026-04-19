//! 导演手册磁盘读写（`data/skills/story_skills`）。

mod paths;
mod read;
mod write;

pub(crate) use paths::{story_manual_dir, validate_style_key};
pub(crate) use read::load_director_manual_list;
pub(crate) use write::{sync_images, write_slots};
