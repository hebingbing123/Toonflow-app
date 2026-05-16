use std::path::{Path, PathBuf};

use super::errors::SkillReadError;

pub(crate) fn skills_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("data/skills")
}

/// Reject `..` and absolute-ish segments; build path under `root`.
pub(crate) fn safe_join_under_root(root: &Path, relative: &str) -> Result<PathBuf, SkillReadError> {
    let mut p = root.to_path_buf();
    for segment in relative.split(['/', '\\']) {
        if segment.is_empty() || segment == "." {
            continue;
        }
        if segment == ".." {
            return Err(SkillReadError::BadPath(
                "path must not contain parent segments".into(),
            ));
        }
        p.push(segment);
    }
    Ok(p)
}
