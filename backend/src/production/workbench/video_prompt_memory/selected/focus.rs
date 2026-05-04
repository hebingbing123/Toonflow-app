use super::super::style_compact::{
    selected_style_fragment_is_generic_restrained_mood, selected_style_fragment_is_low_gain_motion,
    selected_style_fragment_is_low_gain_voice,
};
use super::super::style_rank::{
    is_local_framing_only_fragment, selected_video_style_value_from_content,
};
use super::*;

pub(crate) fn compact_selected_video_memory_for_focus(
    content: &str,
    focus_tags: &[String],
) -> String {
    let bias = selected_video_memory_focus_bias_from_tags(focus_tags);
    if bias == SelectedVideoMemoryOptimizationBias::default() {
        return content.to_string();
    }

    let style = extract_key_value(content, "style");
    let delivery = extract_key_value(content, "delivery");
    let subject_present = extract_key_value(content, "subject")
        .map(|value| !normalize_prompt_text(&value).is_empty())
        .unwrap_or(false)
        || extract_key_value(content, "subjectAliases")
            .map(|value| !normalize_prompt_text(&value).is_empty())
            .unwrap_or(false);

    let compacted_style = style.as_deref().and_then(|style| {
        compact_selected_video_memory_style_for_focus(
            style,
            delivery.as_deref(),
            bias,
            subject_present,
            false,
        )
    });
    let mut rebuilt = Vec::new();

    for part in content.split('|') {
        let part = part.trim();
        if part.is_empty() {
            continue;
        }
        if part.starts_with("style=") {
            if let Some(style) = compacted_style.as_deref() {
                rebuilt.push(format!("style={style}"));
            }
            continue;
        }
        rebuilt.push(part.to_string());
    }

    rebuilt.join(" | ")
}

pub(crate) fn selected_video_memory_is_low_signal(content: &str) -> bool {
    selected_video_memory_is_scope_filler(content)
}

pub(super) fn prepare_selected_video_memory_for_storage(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let focus_tags = selected_video_memory_focus_tags_from_bias(bias);
    let compacted = if focus_tags.is_empty() {
        strip_key_from_memory_content(content, "focusTags")
    } else {
        compact_selected_video_memory_for_focus(content, &focus_tags)
    };
    if selected_video_memory_is_low_signal(&compacted) {
        return None;
    }

    let stripped = strip_key_from_memory_content(&compacted, "focusTags");
    let rebuilt_focus_tags = selected_video_memory_focus_tags_from_content_parts(
        &stripped
            .split('|')
            .map(str::trim)
            .filter(|part| !part.is_empty())
            .map(ToString::to_string)
            .collect::<Vec<_>>(),
    );

    Some(rebuild_memory_content_with_focus_tags(
        &stripped,
        &rebuilt_focus_tags,
    ))
}

pub(super) fn selected_visual_only_memory_keep_priority(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> (i32, i32, i32) {
    (
        selected_video_memory_bias_alignment_score(content, bias),
        selected_video_memory_focus_coverage_score(content, bias),
        selected_video_memory_quality_score(content),
    )
}

pub(super) fn selected_video_memory_bias_alignment_score(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };

    let mut score = 0;
    let focus_tags = selected_video_memory_focus_tags_from_content(content);
    if bias.prefer_delivery
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "delivery_realism",
            selected_video_memory_has_delivery_anchor,
        )
    {
        score += 16;
    }
    if bias.prefer_emotion
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "emotion_arc",
            selected_video_memory_has_emotion_anchor,
        )
    {
        score += 14;
    }
    if bias.prefer_identity
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "identity_continuity",
            selected_video_memory_has_identity_anchor,
        )
    {
        score += 12;
    }
    if bias.prefer_lighting
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "lighting_realism",
            selected_video_memory_has_lighting_anchor,
        )
    {
        score += 12;
    }
    score
}

pub(super) fn selected_video_memory_focus_coverage_score(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };

    let focus_tags = selected_video_memory_focus_tags_from_content(content);
    let mut score = 0;
    if bias.prefer_delivery
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "delivery_realism",
            selected_video_memory_has_delivery_anchor,
        )
    {
        score += 1;
    }
    if bias.prefer_emotion
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "emotion_arc",
            selected_video_memory_has_emotion_anchor,
        )
    {
        score += 1;
    }
    if bias.prefer_identity
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "identity_continuity",
            selected_video_memory_has_identity_anchor,
        )
    {
        score += 1;
    }
    if bias.prefer_lighting
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "lighting_realism",
            selected_video_memory_has_lighting_anchor,
        )
    {
        score += 1;
    }

    score
}

pub(super) fn selected_video_memory_tag_coverage_score(
    content: &str,
    bias: SelectedVideoMemoryOptimizationBias,
) -> i32 {
    let focus_tags = selected_video_memory_focus_tags_from_content(content);
    let mut score = 0;
    if bias.prefer_delivery && focus_tags.iter().any(|tag| tag == "delivery_realism") {
        score += 1;
    }
    if bias.prefer_emotion && focus_tags.iter().any(|tag| tag == "emotion_arc") {
        score += 1;
    }
    if bias.prefer_identity && focus_tags.iter().any(|tag| tag == "identity_continuity") {
        score += 1;
    }
    if bias.prefer_lighting && focus_tags.iter().any(|tag| tag == "lighting_realism") {
        score += 1;
    }
    score
}

pub(super) fn selected_video_memory_active_focus_mask(
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> u8 {
    let Some(bias) = bias else {
        return 0;
    };

    let mut mask = 0;
    if bias.prefer_delivery {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_DELIVERY;
    }
    if bias.prefer_emotion {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_EMOTION;
    }
    if bias.prefer_identity {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_IDENTITY;
    }
    if bias.prefer_lighting {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_LIGHTING;
    }
    mask
}

pub(super) fn selected_video_memory_focus_mask(content: &str) -> u8 {
    let mut mask = 0;
    if selected_video_memory_has_delivery_anchor(content) {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_DELIVERY;
    }
    if selected_video_memory_has_emotion_anchor(content) {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_EMOTION;
    }
    if selected_video_memory_has_identity_anchor(content) {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_IDENTITY;
    }
    if selected_video_memory_has_lighting_anchor(content) {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_LIGHTING;
    }
    mask
}

fn selected_video_memory_tag_or_anchor_matches(
    focus_tags: &[String],
    content: &str,
    tag: &str,
    anchor_check: fn(&str) -> bool,
) -> bool {
    focus_tags.iter().any(|value| value == tag) || anchor_check(content)
}

fn selected_video_memory_focus_bias_from_tags(
    focus_tags: &[String],
) -> SelectedVideoMemoryOptimizationBias {
    let mut bias = SelectedVideoMemoryOptimizationBias::default();
    for tag in focus_tags {
        match tag.as_str() {
            "delivery_realism" => bias.prefer_delivery = true,
            "emotion_arc" => bias.prefer_emotion = true,
            "identity_continuity" => bias.prefer_identity = true,
            "lighting_realism" => bias.prefer_lighting = true,
            _ => {}
        }
    }
    bias
}

pub(super) fn selected_video_memory_focus_tags_from_bias(
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Vec<String> {
    let Some(bias) = bias else {
        return Vec::new();
    };
    let mut tags = Vec::new();
    if bias.prefer_delivery {
        tags.push("delivery_realism".to_string());
    }
    if bias.prefer_emotion {
        tags.push("emotion_arc".to_string());
    }
    if bias.prefer_identity {
        tags.push("identity_continuity".to_string());
    }
    if bias.prefer_lighting {
        tags.push("lighting_realism".to_string());
    }
    tags
}

pub(super) fn selected_video_memory_focus_tags_from_content(content: &str) -> Vec<String> {
    extract_key_value(content, "focusTags")
        .map(|value| {
            value
                .split('/')
                .map(normalize_prompt_text)
                .filter(|tag| !tag.is_empty())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

pub(super) fn selected_video_memory_focus_tags_from_content_parts(parts: &[String]) -> Vec<String> {
    let style = parts
        .iter()
        .find_map(|part| part.strip_prefix("style="))
        .map(normalize_prompt_text)
        .unwrap_or_default();
    let delivery = parts
        .iter()
        .find_map(|part| part.strip_prefix("delivery="))
        .map(normalize_prompt_text)
        .unwrap_or_default();
    let note = parts
        .iter()
        .find_map(|part| part.strip_prefix("note="))
        .map(normalize_prompt_text)
        .unwrap_or_default();
    let subject_present = parts.iter().any(|part| {
        part.strip_prefix("subject=")
            .map(normalize_prompt_text)
            .filter(|value| !value.is_empty())
            .is_some()
            || part
                .strip_prefix("subjectAliases=")
                .map(normalize_prompt_text)
                .filter(|value| !value.is_empty())
                .is_some()
    });

    let combined = [style.as_str(), delivery.as_str(), note.as_str()].join(" ");
    let mut tags = Vec::new();
    let mut push_tag = |tag: &str| {
        if !tags.iter().any(|existing| existing == tag) {
            tags.push(tag.to_string());
        }
    };

    if selected_video_memory_has_delivery_anchor(&combined) {
        push_tag("delivery_realism");
    }
    if selected_video_memory_has_emotion_anchor(&combined) {
        push_tag("emotion_arc");
    }
    if subject_present || selected_video_memory_has_identity_anchor(&combined) {
        push_tag("identity_continuity");
    }
    if selected_video_memory_has_lighting_anchor(&combined) {
        push_tag("lighting_realism");
    }

    tags
}

fn strip_key_from_memory_content(content: &str, key: &str) -> String {
    content
        .split('|')
        .map(str::trim)
        .filter(|part| !part.is_empty() && !part.starts_with(&format!("{key}=")))
        .collect::<Vec<_>>()
        .join(" | ")
}

fn rebuild_memory_content_with_focus_tags(content: &str, focus_tags: &[String]) -> String {
    let mut parts = content
        .split('|')
        .map(str::trim)
        .filter(|part| !part.is_empty() && !part.starts_with("focusTags="))
        .map(ToString::to_string)
        .collect::<Vec<_>>();
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    parts.join(" | ")
}

fn selected_video_memory_has_emotion_anchor(content: &str) -> bool {
    [
        "情绪",
        "强忍泪意",
        "眼眶发红",
        "抬眼停顿",
        "垂眼停顿",
        "欲言又止",
        "呼吸发颤",
        "哽咽",
        "眉心紧锁",
        "嘴角发僵",
        "emotion",
    ]
    .into_iter()
    .any(|keyword| content.contains(keyword))
}

pub(super) fn selected_video_memory_has_identity_anchor(content: &str) -> bool {
    extract_key_value(content, "subject")
        .map(|value| !normalize_prompt_text(&value).is_empty())
        .unwrap_or(false)
        || extract_key_value(content, "subjectAliases")
            .map(|value| !normalize_prompt_text(&value).is_empty())
            .unwrap_or(false)
        || CONTINUITY_NOTE_KEYWORDS
            .iter()
            .any(|keyword| content.contains(keyword))
}

pub(super) fn selected_video_memory_has_lighting_anchor(content: &str) -> bool {
    [
        "光影",
        "光线",
        "逆光",
        "暖光",
        "冷光",
        "霓虹",
        "窗光",
        "侧逆光",
        "lighting",
    ]
    .into_iter()
    .any(|keyword| content.contains(keyword))
}

pub(super) fn selected_video_memory_semantic_dedupe_key(content: &str) -> String {
    let semantic = [
        extract_key_value(content, "delivery"),
        extract_key_value(content, "note"),
        extract_key_value(content, "avoid"),
        extract_key_value(content, "style"),
    ]
    .into_iter()
    .flatten()
    .find(|value| !normalize_prompt_text(value).is_empty())
    .unwrap_or_else(|| content.to_string());
    normalize_prompt_text(&semantic)
}

pub(super) fn selected_video_memory_storyboard_scope_key(content: &str) -> String {
    let ids = extract_storyboard_ids(content);
    if ids.is_empty() {
        return String::new();
    }
    ids.into_iter()
        .map(|id| id.to_string())
        .collect::<Vec<_>>()
        .join(",")
}

pub(super) fn selected_video_memory_has_delivery_anchor(content: &str) -> bool {
    extract_key_value(content, "delivery")
        .as_ref()
        .map(|value| !normalize_prompt_text(value).is_empty())
        .unwrap_or(false)
        || selected_video_memory_delivery_signal_count(content) > 0
}

pub(super) fn selected_video_memory_is_visual_only(content: &str) -> bool {
    !selected_video_memory_has_delivery_anchor(content)
        && selected_video_memory_visual_signal_count(content) > 0
}

fn selected_video_memory_delivery_signal_count(content: &str) -> usize {
    [
        "表演",
        "语气",
        "呼吸",
        "停顿",
        "眼神",
        "微表情",
        "哽咽",
        "喉结",
        "尾音",
        "delivery",
        "emotion",
        "expression",
    ]
    .into_iter()
    .filter(|keyword| content.contains(keyword))
    .count()
}

pub(super) fn selected_video_memory_visual_signal_count(content: &str) -> usize {
    [
        "镜头", "光影", "光线", "逆光", "暖光", "冷光", "运镜", "构图", "机位", "近景", "中景",
        "远景", "camera", "lighting", "framing",
    ]
    .into_iter()
    .filter(|keyword| content.contains(keyword))
    .count()
}

pub(super) fn selected_video_memory_is_scope_filler(content: &str) -> bool {
    let Some(style) = selected_video_style_value_from_content(content) else {
        return match extract_key_value(content, "note")
            .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        {
            Some(note) => is_low_signal_selected_memory_note(&note),
            None => true,
        };
    };

    let fragments = split_prompt_note_fragments(&style).collect::<Vec<_>>();
    if fragments.is_empty() {
        return true;
    }

    let has_specific_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            || fragment.starts_with("光影")
            || fragment.starts_with("环境")
            || fragment.starts_with("声场")
            || (fragment.starts_with("镜头") && !local_shot_framing_fragment(fragment))
    });
    if has_specific_signal {
        return false;
    }

    fragments.iter().all(|fragment| {
        fragment
            .strip_prefix("语气")
            .map(normalize_prompt_text)
            .is_some_and(|voice| selected_style_fragment_is_low_gain_voice(&voice))
            || fragment
                .strip_prefix("情绪")
                .map(normalize_prompt_text)
                .is_some_and(|mood| selected_style_fragment_is_generic_restrained_mood(&mood))
            || fragment
                .strip_prefix("动作")
                .map(normalize_prompt_text)
                .is_some_and(|action| selected_style_fragment_is_low_gain_motion(&action))
            || is_local_framing_only_fragment(fragment)
    })
}

fn compact_selected_video_memory_style_for_focus(
    style: &str,
    delivery: Option<&str>,
    bias: SelectedVideoMemoryOptimizationBias,
    subject_present: bool,
    compact_delivery_into_visual_summary: bool,
) -> Option<String> {
    let mut fragments = split_prompt_note_fragments(style).collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }

    let has_specific_performance = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let has_lighting_or_environment = fragments.iter().any(|fragment| {
        fragment.starts_with("光影") || fragment.starts_with("环境") || fragment.starts_with("声场")
    });
    let has_delivery_anchor = delivery
        .is_some_and(|value| !normalize_prompt_text(value).is_empty())
        || has_specific_performance;

    if (bias.prefer_delivery || bias.prefer_emotion) && has_delivery_anchor {
        fragments.retain(|fragment| {
            if compact_delivery_into_visual_summary
                && delivery.is_some()
                && has_lighting_or_environment
                && fragment.starts_with("表演")
            {
                return false;
            }
            if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_voice(&voice);
            }
            if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
                return !selected_style_fragment_is_generic_restrained_mood(&mood);
            }
            if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_motion(&action);
            }
            true
        });
    }

    if (bias.prefer_lighting || bias.prefer_identity) && has_lighting_or_environment {
        fragments.retain(|fragment| {
            !(is_local_framing_only_fragment(fragment)
                && (bias.prefer_lighting || (bias.prefer_identity && subject_present)))
        });
    }

    if fragments.is_empty() {
        return None;
    }

    compact_video_style_prompt_note(&fragments.join("，"))
}

pub(super) fn compact_summary_video_style_memory_for_focus(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let Some(bias) = bias else {
        return Some(content.to_string());
    };
    if bias == SelectedVideoMemoryOptimizationBias::default() {
        return Some(content.to_string());
    }

    let style = extract_key_value(content, "style")?;
    let delivery = extract_key_value(content, "delivery");
    let style = compact_selected_video_memory_style_for_focus(
        &style,
        delivery.as_deref(),
        bias,
        false,
        true,
    )?;

    let mut parts = Vec::new();
    if let Some(sample_count) =
        extract_key_value(content, "sampleCount").filter(|value| !value.is_empty())
    {
        parts.push(format!("sampleCount={sample_count}"));
    }
    parts.push(format!("style={style}"));
    if let Some(delivery) = delivery
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| !value.is_empty() && value != &style)
    {
        parts.push(format!("delivery={delivery}"));
    }
    Some(parts.join(" | "))
}
