use super::super::*;

pub(in crate::production::workbench::meta::generate) fn normalize_observation_contextual_fragment(
    fragment: &str,
    context: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    if fragment.starts_with("语气") && !storyboard_supports_voice_style(context) {
        return None;
    }

    if fragment.starts_with("表演")
        && (score_memory_fragment_human_performance_detail(fragment, Some("表演")) >= 3
            || observation_performance_fragment_has_delivery_signal(fragment))
        && constraint_pressure.is_some_and(|pressure| {
            pressure.has_dialogue_guardrail
                || pressure.has_emotion_guardrail
                || pressure.has_identity_guardrail
        })
    {
        return Some(fragment.to_string());
    }

    let trimmed = trim_style_fragment_against_storyboard_fields(fragment, context)
        .unwrap_or_else(|| fragment.to_string());

    if trimmed.starts_with("语气") {
        let normalized = if memory_fragment_has_high_signal_voice_detail(
            normalize_prompt_text(&trimmed).as_str(),
        ) {
            trimmed
        } else {
            strip_observation_voice_mood_tail(&trimmed)
        };
        return (!style_fragment_is_low_gain_hidden_speech_voice(&normalized, context, "")
            && !style_fragment_is_low_gain_mood_carryover(&normalized, context))
        .then_some(normalized);
    }

    if trimmed.starts_with("表演")
        && score_memory_fragment_human_performance_detail(&trimmed, Some("表演")) < 3
        && normalize_prompt_text(&trimmed) == normalize_prompt_text(fragment)
        && video_prompt_scene_needs_dialogue_performance_memory(context, None)
    {
        return None;
    }

    Some(trimmed)
}

fn observation_performance_fragment_has_delivery_signal(fragment: &str) -> bool {
    fragment.starts_with("表演")
        && [
            "轻声", "低声", "哽咽", "尾音", "发颤", "克制", "呢喃", "短促",
        ]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn strip_observation_voice_mood_tail(
    fragment: &str,
) -> String {
    let Some(body) = fragment.strip_prefix("语气") else {
        return fragment.to_string();
    };
    let mut trimmed = normalize_prompt_text(body);
    for keyword in ["克制", "隐忍", "压抑", "沉静", "冷静"] {
        if !trimmed.contains(keyword) {
            continue;
        }
        let candidate = normalize_prompt_text(&trimmed.replace(keyword, ""));
        if candidate.chars().count() >= 2 {
            trimmed = candidate;
        }
    }
    if trimmed == body {
        fragment.to_string()
    } else {
        format!("语气{trimmed}")
    }
}

pub(in crate::production::workbench::meta::generate) fn restore_observation_delivery_signal_if_compaction_overtrims(
    original: &str,
    compacted: &str,
    context: &StructuredStoryboardDescription,
) -> String {
    let original_fragments = split_prompt_note_fragments(original).collect::<Vec<_>>();
    let compacted_fragments = split_prompt_note_fragments(compacted).collect::<Vec<_>>();
    let original_has_performance = original_fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let original_has_voice = original_fragments
        .iter()
        .any(|fragment| fragment.starts_with("语气"));
    let compacted_has_performance = compacted_fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let compacted_has_voice = compacted_fragments
        .iter()
        .any(|fragment| fragment.starts_with("语气"));
    if original_has_performance
        && original_has_voice
        && compacted_has_performance
        && !compacted_has_voice
        && video_prompt_scene_needs_dialogue_performance_memory(context, None)
    {
        return original.to_string();
    }

    let original_single_performance = (original_fragments.len() == 1)
        .then(|| original_fragments.first().cloned())
        .flatten()
        .filter(|fragment| fragment.starts_with("表演"));
    let compacted_single_performance = (compacted_fragments.len() == 1)
        .then(|| compacted_fragments.first().cloned())
        .flatten()
        .filter(|fragment| fragment.starts_with("表演"));
    if let (Some(original_fragment), Some(compacted_fragment)) =
        (original_single_performance, compacted_single_performance)
    {
        let original_has_delivery_suffix = [
            "轻声", "低声", "哽咽", "尾音", "发颤", "克制", "呢喃", "短促",
        ]
        .iter()
        .any(|keyword| original_fragment.contains(keyword));
        if original_has_delivery_suffix
            && original_fragment != compacted_fragment
            && (video_prompt_scene_needs_dialogue_performance_memory(context, None)
                || current_storyboard_is_fragile_emotional_turn(context))
        {
            return original.to_string();
        }
    }

    let original_voice_family = original_fragments
        .iter()
        .find(|fragment| fragment.starts_with("语气"))
        .and_then(|fragment| style_voice_family_for_generate(fragment));
    let compacted_voice_family = compacted_fragments
        .iter()
        .find(|fragment| fragment.starts_with("语气"))
        .and_then(|fragment| style_voice_family_for_generate(fragment));
    let original_has_high_signal_voice = original_fragments.iter().any(|fragment| {
        fragment.starts_with("语气")
            && memory_fragment_has_high_signal_voice_detail(
                normalize_prompt_text(fragment).as_str(),
            )
    });
    let original_voice_fragment = original_fragments
        .iter()
        .find(|fragment| fragment.starts_with("语气"))
        .cloned();
    let compacted_voice_fragment = compacted_fragments
        .iter()
        .find(|fragment| fragment.starts_with("语气"))
        .cloned();
    if original_has_high_signal_voice
        && (original_voice_family.is_some() && compacted_voice_family != original_voice_family
            || original_voice_fragment != compacted_voice_fragment)
    {
        return original.to_string();
    }

    compacted.to_string()
}

pub(in crate::production::workbench::meta::generate) fn supplement_observation_summary_voice_fragment(
    source_note: &str,
    selected_note: &str,
    context: &StructuredStoryboardDescription,
    max_chars: usize,
) -> Option<String> {
    let mut selected_fragments = split_prompt_note_fragments(selected_note).collect::<Vec<_>>();
    let has_sound = selected_fragments
        .iter()
        .any(|fragment| fragment.starts_with("声场"));
    if has_sound {
        selected_fragments.retain(|fragment| {
            !fragment.starts_with("语气")
                || (!matches!(
                    normalize_prompt_text(fragment).as_str(),
                    "语气低声" | "语气轻声" | "语气低声克制" | "语气轻声克制"
                ) && !style_fragment_is_low_gain_hidden_speech_voice(fragment, context, "")
                    && !style_fragment_is_low_gain_mood_carryover(fragment, context))
        });
        let normalized = sort_style_note_fragments_for_output(&selected_fragments.join("，"))
            .unwrap_or_else(|| selected_note.to_string());
        if normalized != selected_note {
            return Some(normalized);
        }
    }

    let has_performance = selected_fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let has_voice = selected_fragments
        .iter()
        .any(|fragment| fragment.starts_with("语气"));
    if !has_performance || has_voice || !storyboard_supports_voice_style(context) {
        return Some(selected_note.to_string());
    }
    if selected_note_is_self_sufficient_delivery_performance(selected_note) {
        return Some(selected_note.to_string());
    }

    let voice_fragment =
        super::filter::observation_voice_fragment_from_source_note(source_note, context).filter(
            |fragment| {
                !style_fragment_is_low_gain_hidden_speech_voice(fragment, context, "")
                    && !style_fragment_is_low_gain_mood_carryover(fragment, context)
            },
        );
    let performance_is_low_detail = selected_fragments
        .iter()
        .filter(|fragment| fragment.starts_with("表演"))
        .all(|fragment| score_memory_fragment_human_performance_detail(fragment, Some("表演")) < 3);
    if performance_is_low_detail {
        return super::filter::observation_voice_fragment_from_source_note(source_note, context)
            .or_else(|| Some(selected_note.to_string()));
    }

    let Some(voice_fragment) = voice_fragment else {
        return Some(selected_note.to_string());
    };

    let merged =
        sort_style_note_fragments_for_output(&format!("{selected_note}，{voice_fragment}"))?;
    (merged.chars().count() <= max_chars)
        .then_some(merged)
        .or_else(|| Some(selected_note.to_string()))
}

fn selected_note_is_self_sufficient_delivery_performance(selected_note: &str) -> bool {
    let fragments = split_prompt_note_fragments(selected_note).collect::<Vec<_>>();
    if fragments.len() != 1 {
        return false;
    }

    let fragment = &fragments[0];
    fragment.starts_with("表演")
        && [
            "轻声", "低声", "哽咽", "尾音", "发颤", "克制", "呢喃", "短促",
        ]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn observation_summary_subject_locked_fallback_fragments(
    note: &str,
    context: &StructuredStoryboardDescription,
) -> Vec<String> {
    let needs_subject_locked_memory = video_prompt_scene_needs_identity_memory(context)
        || video_prompt_scene_needs_emotional_memory(context)
        || video_prompt_scene_needs_dialogue_performance_memory(context, None);
    if !needs_subject_locked_memory {
        return Vec::new();
    }

    split_prompt_note_fragments(note)
        .filter_map(|fragment| {
            let trimmed = trim_style_fragment_against_storyboard_fields(&fragment, context)?;
            let is_high_signal_performance = fragment.starts_with("表演")
                && score_memory_fragment_human_performance_detail(&fragment, Some("表演")) >= 3;
            let is_high_signal_voice = fragment.starts_with("语气")
                && storyboard_supports_voice_style(context)
                && memory_fragment_has_high_signal_voice_detail(
                    normalize_prompt_text(&fragment).as_str(),
                );
            if is_high_signal_performance {
                return Some(trimmed);
            }
            is_high_signal_voice.then_some(fragment)
        })
        .collect()
}
