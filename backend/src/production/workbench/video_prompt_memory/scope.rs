use super::*;

pub(super) fn selected_video_memory_scope(content: &str) -> Option<SelectedVideoMemoryScope> {
    let storyboard_ids = extract_key_value(content, "storyboardIds")?;
    Some(SelectedVideoMemoryScope {
        storyboard_ids,
        prompt_seed: extract_key_value(content, "promptSeed"),
    })
}

#[allow(dead_code)]
pub(super) fn memory_matches_rejected_video_risk_tags(
    content: &str,
    storyboard_tags: &[String],
) -> bool {
    if storyboard_tags.is_empty() {
        return false;
    }
    let memory_tags = extract_rejected_video_risk_tags(content);
    !memory_tags.is_empty()
        && memory_tags
            .iter()
            .any(|memory_tag| storyboard_tags.iter().any(|tag| tag == memory_tag))
}

pub(crate) fn storyboard_prompt_seed(row: &StoryboardPromptSeedRow) -> Option<String> {
    let prompt = row
        .prompt
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let video_desc = row
        .video_desc
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let duration = row
        .duration
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let source = [prompt, video_desc, duration].join("\n");
    if source.trim().is_empty() {
        return None;
    }

    let mut hasher = Sha256::new();
    hasher.update(source.as_bytes());
    let hex = format!("{:x}", hasher.finalize());
    Some(hex[..12].to_string())
}

pub(super) fn memory_matches_storyboard(content: &str, storyboard_numeric_id: i32) -> bool {
    extract_storyboard_ids(content).contains(&storyboard_numeric_id)
}

fn memory_matches_prompt_seed(content: &str, current_prompt_seed: Option<&str>) -> bool {
    match current_prompt_seed {
        Some(seed) if !seed.is_empty() => {
            extract_key_value(content, "promptSeed").as_deref() == Some(seed)
        }
        _ => true,
    }
}

pub(super) fn memory_matches_prompt_seed_with_fallback(
    content: &str,
    current_prompt_seed: Option<&str>,
    allow_unseeded_fallback: bool,
) -> bool {
    if memory_matches_prompt_seed(content, current_prompt_seed) {
        return true;
    }
    allow_unseeded_fallback
        && matches!(current_prompt_seed, Some(seed) if !seed.is_empty())
        && extract_key_value(content, "promptSeed").is_none()
}

pub(super) fn has_exact_prompt_seed_memory_match(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    names: &[&str],
) -> bool {
    matches!(current_prompt_seed, Some(seed) if !seed.is_empty())
        && rows.iter().any(|row| {
            names.iter().any(|name| row.name == *name)
                && memory_matches_storyboard(&row.content, storyboard_numeric_id)
                && memory_matches_prompt_seed(&row.content, current_prompt_seed)
        })
}

pub(super) fn storyboard_distance_from_memory_content(
    content: &str,
    storyboard_numeric_id: i32,
) -> Option<i32> {
    if storyboard_numeric_id <= 0 {
        return None;
    }
    extract_storyboard_ids(content)
        .into_iter()
        .map(|id| (storyboard_numeric_id - id).abs())
        .min()
}
