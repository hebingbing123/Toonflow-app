use super::style_compact::{
    collapse_local_framing_stable_tracking, selected_style_fragment_is_generic_restrained_mood,
    selected_style_fragment_is_low_gain_motion, selected_style_fragment_is_low_gain_voice,
};
use super::style_rank::{
    extract_selected_memory_style_note_for_storyboard, selected_video_style_value_from_content,
};
use super::*;

pub(super) fn selected_video_style_value(row: &AgentMemoryRow) -> Option<String> {
    if let Some(value) = extract_key_value(&row.content, "style") {
        return compact_video_style_prompt_note(&value)
            .map(|note| collapse_local_framing_stable_tracking(&note));
    }
    extract_key_value(&row.content, "note").and_then(|note| {
        if is_low_signal_selected_memory_note(&note) {
            return None;
        }
        compact_video_style_prompt_note(&note)
            .map(|note| collapse_local_framing_stable_tracking(&note))
            .or_else(|| {
                extract_key_value(&row.content, "note")
                    .map(|raw| clip_prompt_fragment(&raw, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
            })
    })
}

pub(super) fn selected_video_delivery_value_from_note(note: &str) -> Option<String> {
    let mut performance = None;
    let mut voice = None;
    for fragment in split_prompt_note_fragments(note) {
        if performance.is_none() && fragment.starts_with("表演") {
            performance = Some(fragment);
            continue;
        }
        if voice.is_none() && fragment.starts_with("语气") {
            voice = Some(fragment);
        }
    }

    match (performance.as_deref(), voice.as_deref()) {
        (Some(performance), Some(voice)) => {
            compact_selected_memory_delivery_style(Some(performance), Some(voice))
                .or_else(|| Some(performance.to_string()))
                .or_else(|| Some(voice.to_string()))
        }
        (Some(_), None) => performance,
        (None, Some(_)) => voice,
        (None, None) => None,
    }
}

pub(super) fn delivery_style_value_from_content(content: &str) -> Option<String> {
    extract_key_value(content, "delivery")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
}

pub(super) fn selected_video_delivery_value_from_content(content: &str) -> Option<String> {
    delivery_style_value_from_content(content)
        .or_else(|| {
            extract_key_value(content, "style")
                .and_then(|value| selected_video_delivery_value_from_note(&value))
        })
        .or_else(|| {
            extract_key_value(content, "note")
                .and_then(|value| selected_video_delivery_value_from_note(&value))
        })
        .filter(|value| !value.is_empty())
}

pub(super) fn should_prefer_selected_delivery_for_storyboard(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    storyboard_row
        .and_then(|storyboard_row| {
            storyboard_row
                .video_desc
                .as_deref()
                .and_then(parse_structured_storyboard_description)
                .map(|fields| {
                    selected_memory_has_visible_speech_performance_risk(
                        &fields,
                        storyboard_row.prompt.as_deref(),
                    ) || storyboard_is_fragile_emotional_turn(&fields)
                })
        })
        .unwrap_or(false)
}

pub(super) fn summary_style_memory_value_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    if !matches!(
        row.name.as_str(),
        SCRIPT_VIDEO_STYLE_MEMORY_NAME | PROJECT_VIDEO_STYLE_MEMORY_NAME
    ) {
        return selected_video_style_value(row);
    }

    let should_prefer_delivery = storyboard_row
        .and_then(|storyboard_row| {
            storyboard_row
                .video_desc
                .as_deref()
                .and_then(parse_structured_storyboard_description)
                .map(|fields| {
                    selected_memory_has_visible_speech_performance_risk(
                        &fields,
                        storyboard_row.prompt.as_deref(),
                    ) || storyboard_is_fragile_emotional_turn(&fields)
                })
        })
        .unwrap_or(false);

    if should_prefer_delivery {
        if let Some(delivery) = delivery_style_value_from_content(&row.content) {
            return Some(delivery);
        }
    }

    extract_key_value(&row.content, "style")
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| !value.is_empty())
        .or_else(|| {
            extract_key_value(&row.content, "note")
                .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
                .filter(|value| !value.is_empty())
        })
}

pub(super) fn generation_brief_style_memory_value(row: &AgentMemoryRow) -> Option<String> {
    extract_key_value(&row.content, "style")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
}

pub(super) fn storyboard_is_fragile_emotional_turn(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.action.as_str(),
        fields.dialogue.as_str(),
        fields.mood.as_str(),
    ]
    .into_iter()
    .any(|field| {
        ["哽咽", "发哽", "含泪", "泪", "哭", "发颤", "颤声", "鼻音"]
            .iter()
            .any(|keyword| field.contains(keyword))
    })
}

pub(super) fn role_style_memory_value_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let fallback = selected_video_style_value(row);
    if !matches!(
        row.name.as_str(),
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME | PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME
    ) {
        return fallback;
    }

    let should_prefer_delivery = storyboard_row
        .and_then(|storyboard_row| {
            storyboard_row
                .video_desc
                .as_deref()
                .and_then(parse_structured_storyboard_description)
                .map(|fields| {
                    selected_memory_has_visible_speech_performance_risk(
                        &fields,
                        storyboard_row.prompt.as_deref(),
                    )
                })
        })
        .unwrap_or(false);

    if should_prefer_delivery {
        if let Some(delivery) = delivery_style_value_from_content(&row.content) {
            return Some(delivery);
        }
    }

    fallback
}

pub(crate) fn contextual_style_memory_value_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    match row.name.as_str() {
        SCRIPT_VIDEO_STYLE_MEMORY_NAME | PROJECT_VIDEO_STYLE_MEMORY_NAME => {
            summary_style_memory_value_for_storyboard(row, storyboard_row)
        }
        SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME | PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME => {
            generation_brief_style_memory_value(row)
        }
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME | PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => {
            role_style_memory_value_for_storyboard(row, storyboard_row)
        }
        _ => extract_selected_memory_style_note_for_storyboard(row, storyboard_row),
    }
}

pub(super) fn is_low_signal_selected_memory_note(note: &str) -> bool {
    let normalized = normalize_prompt_text(note)
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | '，' | ';' | '；' | '.' | '。' | ':' | '：')
        })
        .to_string();
    if normalized.is_empty() {
        return true;
    }

    matches!(
        normalized.as_str(),
        "当前镜头已确认" | "镜头已确认" | "当前分镜已确认" | "重复确认同镜头" | "同镜头重复确认"
    ) || ((normalized.contains("镜头") || normalized.contains("分镜"))
        && normalized.contains("确认")
        && normalized.chars().count() <= 10)
}

pub(super) fn selected_video_memory_update_would_reduce_quality_with_bias(
    existing: &str,
    incoming: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> bool {
    selected_visual_only_memory_keep_priority(existing, bias)
        > selected_visual_only_memory_keep_priority(incoming, bias)
}

pub(super) fn selected_video_memory_quality_score(content: &str) -> i32 {
    let mut score = 0;

    if let Some(raw_style) = extract_key_value(content, "style") {
        let raw_fragments = split_prompt_note_fragments(&raw_style).collect::<Vec<_>>();
        score -= selected_video_memory_style_redundancy_penalty(&raw_fragments);
    }

    if let Some(style) = selected_video_style_value_from_content(content) {
        score += 80;
        let fragments = split_prompt_note_fragments(&style).collect::<Vec<_>>();
        score += fragments
            .iter()
            .cloned()
            .map(score_selected_video_memory_style_fragment)
            .sum::<i32>();
        score -= selected_video_memory_style_redundancy_penalty(&fragments);
    }

    if let Some(note) = extract_key_value(content, "note")
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| !is_low_signal_selected_memory_note(value))
    {
        score += 20;
        score += split_prompt_note_fragments(&note)
            .map(score_selected_video_memory_note_fragment)
            .sum::<i32>();
    }

    score
}

fn selected_video_memory_style_redundancy_penalty(fragments: &[String]) -> i32 {
    if !fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"))
    {
        return 0;
    }

    fragments.iter().fold(0, |penalty, fragment| {
        if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
            if selected_style_fragment_is_low_gain_voice(&voice) {
                return penalty + 36;
            }
        }
        if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
            if selected_style_fragment_is_generic_restrained_mood(&mood) {
                return penalty + 24;
            }
        }
        if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
            if selected_style_fragment_is_low_gain_motion(&action) {
                return penalty + 24;
            }
        }
        penalty
    })
}

fn score_selected_video_memory_style_fragment(fragment: String) -> i32 {
    let fragment = normalize_prompt_text(&fragment);
    if fragment.is_empty() {
        return 0;
    }

    if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
        if selected_style_fragment_is_low_gain_voice(&voice) {
            return 2;
        }
    }
    if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
        if selected_style_fragment_is_generic_restrained_mood(&mood) {
            return 2;
        }
    }
    if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
        if selected_style_fragment_is_low_gain_motion(&action) {
            return 1;
        }
    }

    let mut score = 6;
    if fragment.starts_with("镜头") {
        score += 5;
    }
    if fragment.starts_with("情绪") {
        score += 7;
    }
    if fragment.starts_with("光影") {
        score += 5;
    }
    if fragment.starts_with("动作") {
        score += 3;
    }
    if fragment.starts_with("表演") {
        score += 10;
    }
    if fragment.starts_with("环境") {
        score += 4;
    }
    if fragment.starts_with("语气") {
        score += 9;
    }
    if fragment.starts_with("声场") {
        score += 4;
    }
    if fragment.starts_with("场景") {
        score += 2;
    }
    if fragment.starts_with("表演") || fragment.starts_with("语气") {
        score += 2;
    }
    score + fragment.chars().count().min(18) as i32 / 3
}

fn score_selected_video_memory_note_fragment(fragment: String) -> i32 {
    let fragment = normalize_prompt_text(&fragment);
    if fragment.is_empty() {
        return 0;
    }

    let mut score = 4;
    if STYLE_NOTE_PREFIXES
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
    {
        score += 3;
    }
    score + fragment.chars().count().min(18) as i32 / 6
}
