//! Text transformation logic for video prompts

use super::super::super::*;
use super::super::*;

pub fn resolve_video_prompt_description(
    description: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> Option<String> {
    let description = description
        .map(normalize_prompt_text)
        .filter(|text| !text.is_empty());
    if description.is_some() {
        return description;
    }
    context.and_then(|ctx| {
        ctx.storyboard_video_desc
            .as_deref()
            .map(normalize_prompt_text)
            .filter(|text| !text.is_empty())
            .or_else(|| {
                ctx.storyboard_prompt
                    .as_deref()
                    .map(normalize_prompt_text)
                    .filter(|text| !text.is_empty())
            })
    })
}

pub fn resolve_video_prompt_duration(
    duration_hint: Option<i32>,
    description: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> i32 {
    if let Some(value) = duration_hint.filter(|value| *value > 0) {
        return value.clamp(2, 16);
    }
    if let Some(parsed) = resolve_video_prompt_description(description, context)
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .and_then(|fields| fields.duration_seconds)
    {
        return parsed.clamp(2, 16);
    }
    if let Some(parsed) = context
        .and_then(|ctx| ctx.storyboard_duration.as_deref())
        .and_then(parse_positive_int)
    {
        return parsed.clamp(2, 16);
    }
    5
}

pub fn director_performance_fragment_is_generic_proactive_hint(fragment: &str) -> bool {
    matches!(
        normalize_prompt_text(fragment).as_str(),
        "眼神先动再开口"
            | "开口前先压住气息"
            | "尾音带轻颤"
            | "气息带情绪起伏"
            | "眼神嘴角细微递进"
    )
}

pub fn director_performance_fragment_is_generic_face_carryover(fragment: &str) -> bool {
    matches!(
        normalize_prompt_text(fragment).as_str(),
        "神情内敛" | "眼神深沉" | "唇线收紧" | "神情低落" | "眼神黯淡" | "眉心轻蹙"
    )
}

pub fn lighting_fragment_retains_specific_detail(fragment: &str, lighting: &str) -> bool {
    let body = normalize_prompt_text(fragment.trim_start_matches("光影"));
    let lighting = normalize_prompt_text(lighting);
    body.contains(&lighting)
        && normalize_prompt_text(&body.replace(&lighting, ""))
            .chars()
            .count()
            >= 2
}

fn low_signal_compacted_lighting_fragment(fragment: &str) -> bool {
    matches!(
        normalize_prompt_text(fragment).as_str(),
        "光影层次" | "光影质感" | "光影氛围"
    )
}

pub fn restore_reference_guardrail_style_detail(
    compacted_note: &str,
    original_note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> String {
    let Some(fields) = structured_fields else {
        return compacted_note.to_string();
    };
    let Some(pressure) = constraint_pressure else {
        return compacted_note.to_string();
    };
    if !pressure.has_lighting_guardrail {
        return compacted_note.to_string();
    }

    let Some(original_lighting) = split_prompt_note_fragments(original_note)
        .find(|fragment| {
            fragment.starts_with("光影")
                && fragment.contains(&fields.lighting)
                && lighting_fragment_retains_specific_detail(fragment, &fields.lighting)
        })
        .map(|fragment| fragment.to_string())
    else {
        return compacted_note.to_string();
    };

    let restored = split_prompt_note_fragments(compacted_note)
        .map(|fragment| {
            if fragment.starts_with("光影")
                && low_signal_compacted_lighting_fragment(&fragment)
                && fragment != original_lighting
            {
                original_lighting.clone()
            } else {
                fragment
            }
        })
        .collect::<Vec<_>>();

    if restored.is_empty() {
        compacted_note.to_string()
    } else {
        restored.join("，")
    }
}

pub fn compact_expanded_visual_memory_fragment(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    memory_budget_tier: VideoPromptMemoryBudgetTier,
) -> Option<String> {
    if memory_budget_tier != VideoPromptMemoryBudgetTier::Expanded {
        return None;
    }

    if fragment.starts_with("光影") {
        let trimmed = trim_style_fragment_against_storyboard_fields(fragment, fields)?;
        return (trimmed != fragment
            && lighting_fragment_retains_specific_detail(fragment, &fields.lighting))
        .then_some(trimmed);
    }

    None
}

pub fn memory_fragment_has_high_signal_voice_detail(fragment: &str) -> bool {
    ["气息", "换气", "哽咽", "发颤", "尾音", "压低"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

pub fn performance_fragment_has_unique_micro_detail(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    [
        "喉结", "吞咽", "呼吸", "鼻息", "眼尾", "眼眶", "眼睫", "嘴角", "眉心", "眉梢", "唇线",
        "唇角", "眨眼", "下颌",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

pub fn preserve_high_signal_performance_fragment(
    trimmed: Option<String>,
    original_fragment: &str,
) -> Option<String> {
    let Some(trimmed) = trimmed else {
        return performance_fragment_has_unique_micro_detail(original_fragment)
            .then(|| original_fragment.to_string());
    };

    let original_body = original_fragment.trim_start_matches("表演");
    let trimmed_body = trimmed.trim_start_matches("表演");
    if PERFORMANCE_SHARED_KEYWORD_FAMILIES.iter().any(|family| {
        family.iter().any(|keyword| original_body.contains(keyword))
            && !family.iter().any(|keyword| trimmed_body.contains(keyword))
    }) && !performance_fragment_has_unique_micro_detail(&trimmed)
    {
        performance_fragment_has_unique_micro_detail(original_fragment)
            .then(|| original_fragment.to_string())
    } else {
        Some(trimmed)
    }
}

pub fn generic_motion_style_fragment(fragment: &str) -> bool {
    let body = normalize_prompt_text(fragment.trim_start_matches("动作"));
    matches!(
        body.as_str(),
        "自然"
            | "从容克制"
            | "克制自然"
            | "缓慢优雅"
            | "简洁平滑"
            | "缓慢"
            | "轻盈"
            | "利落"
            | "轻缓克制"
    )
}
