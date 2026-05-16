//! 视觉手册磁盘读写（`data/skills/art_skills`）。

mod read;
mod write;

pub(crate) use read::load_visual_manual;
pub(crate) use write::{sync_visual_images, write_visual_slots};
