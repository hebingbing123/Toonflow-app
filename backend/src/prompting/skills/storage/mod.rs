//! Skill files under `data/skills` (path safety, read/write/delete).

mod errors;
mod paths;
mod read;
mod write;

pub(crate) use errors::{SkillCreateError, SkillDeleteError, SkillReadError, SkillWriteError};
pub(crate) use paths::{safe_join_under_root, skills_root};
pub(crate) use read::{read_skill_binary, read_skill_markdown, read_skill_markdown_section};
pub(crate) use write::{
    create_skill_at, create_skill_markdown, delete_skill_at, delete_skill_markdown, write_skill_at,
    write_skill_markdown,
};
