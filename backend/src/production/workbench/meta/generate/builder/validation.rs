//! Prompt builder and diagnostics logic.

use super::super::builder_parts::continuity::compact::compact_continuity_note;
use super::super::*;
use super::*;

pub fn storyboard_supports_voice_style(fields: &StructuredStoryboardDescription) -> bool {
    if !storyboard_dialogue_is_empty(&fields.dialogue) {
        return true;
    }

    let normalized_action = normalize_prompt_text(&fields.action);
    if normalized_action.is_empty() {
        return false;
    }

    [
        "开口",
        "说",
        "说道",
        "说出",
        "低声",
        "轻声",
        "呢喃",
        "哽咽",
        "吸气",
        "呼吸",
        "欲言又止",
    ]
    .iter()
    .any(|keyword| normalized_action.contains(keyword))
}

pub fn should_use_compact_opening_clause(
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> bool {
    structured_fields.is_some_and(video_prompt_scene_is_grounded_low_risk)
}

pub fn should_use_compact_prompt_labels(
    structured_fields: Option<&StructuredStoryboardDescription>,
    has_reference_frame: bool,
    context: Option<&VideoPromptContext>,
    _role_anchors: &[String],
    _scene_anchors: &[String],
    _tool_anchors: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    if should_use_compact_opening_clause(structured_fields) {
        return true;
    }

    let Some(fields) = structured_fields else {
        return false;
    };
    if !has_reference_frame {
        return false;
    }

    let has_any_continuity_note = context.is_some_and(|ctx| {
        ctx.continuity_notes
            .iter()
            .any(|note| !normalize_prompt_text(note).is_empty())
    });
    let has_effective_continuity_note = context.is_some_and(|ctx| {
        video_prompt_has_effective_continuity_note_for_budget(&ctx.continuity_notes, Some(fields))
    });
    let has_axis_specific_continuity_note = context.is_some_and(|ctx| {
        ctx.continuity_notes.iter().any(|note| {
            let normalized = normalize_prompt_text(note);
            normalized.contains("跳轴")
                || normalized.contains("站位")
                || normalized.contains("视线方向")
        })
    });
    let has_delivery_memory = context.is_some_and(|ctx| {
        ctx.memory_style_notes
            .iter()
            .any(|note| memory_style_anchor_has_delivery_signal(note))
    });

    if has_axis_specific_continuity_note {
        return false;
    }

    (has_any_continuity_note
        || has_effective_continuity_note
        || constraint_pressure.is_some_and(|pressure| pressure.forces_compact_memory))
        && (video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
            || (has_delivery_memory && !storyboard_dialogue_is_empty(&fields.dialogue))
            || current_storyboard_is_fragile_emotional_turn(fields)
            || constraint_pressure.is_some_and(|pressure| pressure.forces_compact_memory))
}

pub fn video_prompt_has_effective_continuity_note_for_budget(
    notes: &[String],
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> bool {
    notes.iter().any(|note| {
        compact_continuity_note(note, structured_fields, &[]).is_some_and(|compacted| {
            continuity_note_matches_storyboard_risk(&compacted, structured_fields)
        })
    })
}

pub fn video_prompt_scene_needs_emotional_memory(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "哭",
                "泪",
                "哽咽",
                "颤",
                "停顿",
                "压抑",
                "克制",
                "愤怒",
                "惊慌",
                "紧张",
                "崩溃",
                "隐忍",
                "欲言又止",
                "迟疑",
                "回头",
                "犹豫",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub fn video_prompt_scene_is_grounded_low_risk(fields: &StructuredStoryboardDescription) -> bool {
    !video_prompt_scene_has_motion_risk(fields)
        && !video_prompt_scene_has_lighting_risk(fields)
        && !video_prompt_scene_needs_emotional_memory(fields)
}

pub fn should_compact_decorative_style_anchors(
    structured_fields: Option<&StructuredStoryboardDescription>,
    has_reference_frame: bool,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    let Some(fields) = structured_fields else {
        return false;
    };
    if should_yield_decorative_style_to_reference_frame(
        fields,
        has_reference_frame,
        constraint_pressure,
    ) {
        return true;
    }
    let Some(pressure) = constraint_pressure
        .filter(|pressure| pressure.forces_compact_memory && pressure.has_active_guardrail())
    else {
        return false;
    };

    video_prompt_scene_needs_dialogue_performance_memory(fields, Some(pressure))
        || current_storyboard_is_fragile_emotional_turn(fields)
        || (pressure.has_identity_guardrail && video_prompt_scene_needs_identity_memory(fields))
}

pub fn should_yield_decorative_style_to_reference_frame(
    fields: &StructuredStoryboardDescription,
    has_reference_frame: bool,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    has_reference_frame
        && !constraint_pressure.is_some_and(|pressure| {
            pressure.has_lighting_guardrail || pressure.has_motion_guardrail
        })
        && (video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
            || current_storyboard_is_fragile_emotional_turn(fields))
}

pub fn should_keep_environment_style_anchor_under_pressure(
    fields: &StructuredStoryboardDescription,
    pressure: VideoPromptConstraintPressure,
) -> bool {
    video_prompt_scene_has_lighting_risk(fields)
        && !pressure.has_dialogue_guardrail
        && !pressure.has_identity_guardrail
}

pub fn should_keep_motion_style_anchor_under_pressure(
    fields: &StructuredStoryboardDescription,
    pressure: VideoPromptConstraintPressure,
) -> bool {
    video_prompt_scene_has_motion_risk(fields)
        && !pressure.has_dialogue_guardrail
        && !pressure.has_emotion_guardrail
        && !current_storyboard_is_fragile_emotional_turn(fields)
}

pub fn expanded_visual_memory_fragment_should_bypass_storyboard_trim(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    memory_budget_tier: VideoPromptMemoryBudgetTier,
) -> bool {
    if memory_budget_tier != VideoPromptMemoryBudgetTier::Expanded
        || !(video_prompt_scene_has_lighting_risk(fields)
            || video_prompt_scene_needs_emotional_memory(fields))
    {
        return false;
    }

    if fragment.starts_with("光影") {
        return lighting_fragment_retains_specific_detail(fragment, &fields.lighting);
    }

    fragment.starts_with("环境")
}

pub fn video_prompt_scene_needs_dialogue_performance_memory(
    fields: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    !storyboard_dialogue_is_empty(&fields.dialogue)
        && storyboard_supports_voice_style(fields)
        && (video_prompt_scene_needs_identity_memory(fields)
            || current_storyboard_is_fragile_emotional_turn(fields)
            || constraint_pressure.is_some_and(|pressure| {
                pressure.has_dialogue_guardrail || pressure.has_identity_guardrail
            }))
}

pub fn video_prompt_scene_needs_identity_lighting_pair_memory(
    fields: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    video_prompt_scene_needs_identity_memory(fields)
        && video_prompt_scene_has_lighting_risk(fields)
        && constraint_pressure.is_some_and(|pressure| {
            pressure.has_identity_guardrail || pressure.has_lighting_guardrail
        })
}

pub fn video_prompt_scene_needs_delivery_lighting_pair_memory(
    fields: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    video_prompt_scene_has_lighting_risk(fields)
        && (video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
            || current_storyboard_is_fragile_emotional_turn(fields))
        && constraint_pressure.is_some_and(|pressure| {
            pressure.has_lighting_guardrail
                || pressure.has_dialogue_guardrail
                || pressure.has_emotion_guardrail
                || pressure.prefer_visual_continuity_memory_recall
        })
}

pub fn memory_style_fragment_should_yield_to_negative_pressure(
    fragment: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    let Some(pressure) = constraint_pressure.filter(|pressure| pressure.has_active_guardrail())
    else {
        return false;
    };

    let normalized = normalize_prompt_text(fragment);
    let family = style_note_fragment_family(&normalized);
    match family {
        Some("情绪") => {
            (pressure.has_emotion_guardrail || pressure.has_identity_guardrail)
                && mood_fragment_is_generic_carryover(
                    normalize_prompt_text(normalized.trim_start_matches("情绪")).as_str(),
                )
        }
        Some("语气") => {
            if structured_fields.is_some_and(|fields| !storyboard_supports_voice_style(fields)) {
                return true;
            }
            !memory_fragment_has_high_signal_voice_detail(&normalized)
                && (pressure.has_dialogue_guardrail
                    || pressure.has_emotion_guardrail
                    || pressure.has_identity_guardrail)
        }
        Some("声场") => {
            pressure.has_dialogue_guardrail
                || pressure.has_motion_guardrail
                || pressure.has_emotion_guardrail
                || pressure.has_identity_guardrail
        }
        Some("环境") => {
            pressure.has_identity_guardrail
                || pressure.has_lighting_guardrail
                    && !["反光", "逆光", "霓虹", "雨丝", "玻璃", "水痕", "影"]
                        .iter()
                        .any(|keyword| normalized.contains(keyword))
        }
        Some("动作") => {
            (pressure.has_motion_guardrail || pressure.has_identity_guardrail)
                && generic_motion_style_fragment(&normalized)
        }
        Some("镜头") => {
            pressure.has_blocking_guardrail && is_local_framing_only_fragment(&normalized)
        }
        _ => false,
    }
}

pub fn voice_fragment_token_is_generic_mood_carryover(token: &str) -> bool {
    matches!(
        token,
        "克制" | "平静" | "冷静" | "沉静" | "从容" | "隐忍" | "压抑"
    )
}

pub fn mood_fragment_is_generic_carryover(body: &str) -> bool {
    matches!(
        body,
        "克制"
            | "隐忍"
            | "压抑"
            | "平静"
            | "冷静"
            | "沉静"
            | "从容"
            | "隐忍克制"
            | "克制隐忍"
            | "压抑克制"
            | "克制压抑"
            | "平静克制"
            | "克制平静"
            | "冷静克制"
            | "克制冷静"
    )
}

pub fn project_director_mood_fragment_is_generic_carryover(mood: &str) -> bool {
    matches!(
        normalize_prompt_text(mood).as_str(),
        "克制" | "隐忍" | "压抑" | "沉静" | "冷静" | "隐忍克制" | "克制隐忍"
    )
}
