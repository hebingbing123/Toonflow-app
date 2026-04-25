use std::path::Path;

use super::super::{SkillContentResponse, MAX_SKILL_BINARY_BYTES, MAX_SKILL_BYTES};
use super::errors::SkillReadError;
use super::paths::{safe_join_under_root, skills_root};

fn mime_for_skill_image(path: &Path) -> Option<&'static str> {
    let ext = path.extension()?.to_str()?;
    Some(match ext.to_ascii_lowercase().as_str() {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "svg" => "image/svg+xml",
        _ => return None,
    })
}

/// Read a single Markdown skill by path relative to `data/skills` (same rules as HTTP `GET .../skills/content`).
pub(crate) fn read_skill_markdown(relative: &str) -> Result<SkillContentResponse, SkillReadError> {
    let root = skills_root();
    if !root.is_dir() {
        return Err(SkillReadError::SkillsDirMissing);
    }
    let resolved = safe_join_under_root(&root, relative)?;
    if !resolved.is_file() {
        return Err(SkillReadError::NotFound);
    }
    let meta = std::fs::metadata(&resolved)
        .map_err(|e| SkillReadError::Io(format!("cannot stat skill: {e}")))?;
    if meta.len() > MAX_SKILL_BYTES {
        return Err(SkillReadError::TooLarge);
    }
    let content = std::fs::read_to_string(&resolved)
        .map_err(|e| SkillReadError::Io(format!("cannot read skill: {e}")))?;
    let rel = resolved
        .strip_prefix(&root)
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|_| relative.to_string());
    Ok(SkillContentResponse { path: rel, content })
}

fn extract_markdown_section(content: &str, heading: &str) -> Option<String> {
    let heading = heading.trim();
    if heading.is_empty() {
        return Some(content.to_string());
    }

    let lines: Vec<&str> = content.lines().collect();
    let mut start_idx: Option<usize> = None;
    let mut start_level: usize = 0;

    for (idx, line) in lines.iter().enumerate() {
        let trimmed = line.trim();
        if !trimmed.starts_with('#') {
            continue;
        }
        let level = trimmed.chars().take_while(|c| *c == '#').count();
        if level == 0 || level >= trimmed.len() {
            continue;
        }
        let title = trimmed[level..].trim();
        if title == heading {
            start_idx = Some(idx);
            start_level = level;
            break;
        }
    }

    let start = start_idx?;
    let mut end = lines.len();
    for (idx, line) in lines.iter().enumerate().skip(start + 1) {
        let trimmed = line.trim();
        if !trimmed.starts_with('#') {
            continue;
        }
        let level = trimmed.chars().take_while(|c| *c == '#').count();
        if level > 0 && level <= start_level {
            end = idx;
            break;
        }
    }

    Some(lines[start..end].join("\n").trim().to_string())
}

/// Read only one Markdown section by exact heading text, keeping the heading line.
pub(crate) fn read_skill_markdown_section(
    relative: &str,
    heading: &str,
) -> Result<SkillContentResponse, SkillReadError> {
    let doc = read_skill_markdown(relative)?;
    let content = extract_markdown_section(&doc.content, heading)
        .ok_or_else(|| SkillReadError::SectionNotFound(heading.to_string()))?;
    Ok(SkillContentResponse {
        path: doc.path,
        content,
    })
}

/// Read a regular file under `data/skills` as bytes (images only). Same path safety as Markdown reads.
pub(crate) fn read_skill_binary(relative: &str) -> Result<(Vec<u8>, &'static str), SkillReadError> {
    let root = skills_root();
    if !root.is_dir() {
        return Err(SkillReadError::SkillsDirMissing);
    }
    let resolved = safe_join_under_root(&root, relative)?;
    if !resolved.is_file() {
        return Err(SkillReadError::NotFound);
    }
    let mime = mime_for_skill_image(&resolved).ok_or_else(|| {
        SkillReadError::BadPath(
            "only image files are allowed (png, jpg, jpeg, gif, webp, svg)".into(),
        )
    })?;
    let meta = std::fs::metadata(&resolved)
        .map_err(|e| SkillReadError::Io(format!("cannot stat skill file: {e}")))?;
    if meta.len() > MAX_SKILL_BINARY_BYTES {
        return Err(SkillReadError::TooLargeBinary);
    }
    let content = std::fs::read(&resolved)
        .map_err(|e| SkillReadError::Io(format!("cannot read skill file: {e}")))?;
    Ok((content, mime))
}

#[cfg(test)]
mod tests {
    use super::extract_markdown_section;

    #[test]
    fn extracts_top_level_markdown_section_until_next_peer() {
        let content = "# A\nbody-a\n## A.1\nchild\n# B\nbody-b\n";
        let section = extract_markdown_section(content, "A").unwrap();
        assert_eq!(section, "# A\nbody-a\n## A.1\nchild");
    }

    #[test]
    fn extracts_nested_markdown_section_until_same_or_higher_level() {
        let content = "# A\nbody-a\n## Target\nwanted\n### Detail\nmore\n## Next\nstop\n";
        let section = extract_markdown_section(content, "Target").unwrap();
        assert_eq!(section, "## Target\nwanted\n### Detail\nmore");
    }

    #[test]
    fn missing_section_returns_none() {
        let content = "# A\nbody-a\n";
        assert!(extract_markdown_section(content, "Missing").is_none());
    }
}
