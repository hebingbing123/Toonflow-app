use super::super::*;

pub(in crate::production::workbench::meta::generate) fn observation_summary_style_note_min_evidence(
    compacted_note: &str,
    context: &StructuredStoryboardDescription,
    scope_priority: u8,
    subject_priority: usize,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> usize {
    let scene_needs_subject_locked_memory = video_prompt_scene_needs_identity_memory(context)
        || video_prompt_scene_needs_emotional_memory(context)
        || constraint_pressure.is_some_and(|pressure| {
            pressure.has_identity_guardrail
                || pressure.has_dialogue_guardrail
                || pressure.has_emotion_guardrail
        });
    let has_high_signal_subject_detail = split_prompt_note_fragments(compacted_note).any(
        |fragment| match style_note_fragment_family(&fragment) {
            Some("表演") => {
                score_memory_fragment_human_performance_detail(&fragment, Some("表演")) >= 3
            }
            Some("语气") => {
                storyboard_supports_voice_style(context)
                    && memory_fragment_has_high_signal_voice_detail(
                        normalize_prompt_text(&fragment).as_str(),
                    )
            }
            _ => false,
        },
    );

    if scope_priority > 1 || subject_priority == usize::MAX {
        return usize::from(
            !scene_needs_subject_locked_memory
                || !has_high_signal_subject_detail
                || constraint_pressure.is_none(),
        ) + 1;
    }

    if !scene_needs_subject_locked_memory {
        return 2;
    }

    if has_high_signal_subject_detail {
        1
    } else {
        2
    }
}

pub(in crate::production::workbench::meta::generate) fn rank_observation_summary_style_note_fragments(
    note: &str,
    context: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let max_chars = if constraint_pressure
        .is_some_and(|pressure| pressure.forces_compact_memory && pressure.has_active_guardrail())
    {
        VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS
    } else {
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS
    };
    let max_fragments = if max_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS {
        2
    } else {
        3
    };

    let mut scored = split_prompt_note_fragments(note)
        .filter_map(|fragment| {
            let fragment = super::compact::normalize_observation_contextual_fragment(
                &fragment,
                context,
                constraint_pressure,
            )?;
            let evidence =
                super::r#match::observation_style_note_context_evidence(&fragment, context);
            (evidence > 0).then_some((
                observation_summary_style_fragment_score(&fragment, context, constraint_pressure),
                evidence,
                fragment.chars().count(),
                fragment,
            ))
        })
        .collect::<Vec<_>>();
    if constraint_pressure.is_some_and(|pressure| {
        pressure.has_dialogue_guardrail
            || pressure.has_identity_guardrail
            || pressure.has_emotion_guardrail
    }) {
        for fragment in
            super::compact::observation_summary_subject_locked_fallback_fragments(note, context)
        {
            if scored
                .iter()
                .any(|(_, _, _, existing)| existing == &fragment)
            {
                continue;
            }
            scored.push((
                observation_summary_style_fragment_score(&fragment, context, constraint_pressure)
                    + 100,
                0,
                fragment.chars().count(),
                fragment,
            ));
        }
    }
    scored.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(b.1.cmp(&a.1))
            .then(a.2.cmp(&b.2))
            .then(a.3.cmp(&b.3))
    });

    let mut selected: Vec<String> = Vec::new();
    let mut used_chars = 0usize;
    for (_, _, _, fragment) in scored {
        if selected
            .iter()
            .any(|existing| style_note_fragment_conflicts_or_overlaps(existing, &fragment))
        {
            continue;
        }
        let separator_chars = usize::from(!selected.is_empty());
        let next_chars = used_chars + separator_chars + fragment.chars().count();
        if next_chars > max_chars {
            continue;
        }
        used_chars = next_chars;
        selected.push(fragment);
        if selected.len() >= max_fragments {
            break;
        }
    }

    if selected.is_empty() {
        for fragment in
            super::compact::observation_summary_subject_locked_fallback_fragments(note, context)
        {
            let separator_chars = usize::from(!selected.is_empty());
            let next_chars = used_chars + separator_chars + fragment.chars().count();
            if next_chars > max_chars {
                continue;
            }
            used_chars = next_chars;
            selected.push(fragment);
            if selected.len() >= max_fragments {
                break;
            }
        }
    }

    let mut selected = (!selected.is_empty())
        .then(|| sort_style_note_fragments_for_output(&selected.join("，")))
        .flatten()?;
    if constraint_pressure.is_some_and(|pressure| {
        pressure.has_dialogue_guardrail
            || pressure.has_identity_guardrail
            || pressure.has_emotion_guardrail
    }) {
        let delivery_fragments = split_prompt_note_fragments(&selected)
            .filter_map(|fragment| {
                if fragment.starts_with("表演") {
                    return Some(fragment);
                }
                if !fragment.starts_with("语气") {
                    return None;
                }
                if memory_fragment_has_high_signal_voice_detail(
                    normalize_prompt_text(&fragment).as_str(),
                ) {
                    return Some(fragment);
                }
                let trimmed = trim_style_fragment_against_storyboard_fields(&fragment, context)
                    .unwrap_or(fragment);
                Some(super::compact::strip_observation_voice_mood_tail(&trimmed))
            })
            .collect::<Vec<_>>();
        if !delivery_fragments.is_empty() {
            selected = sort_style_note_fragments_for_output(&delivery_fragments.join("，"))
                .unwrap_or(selected);
        }
    }
    super::compact::supplement_observation_summary_voice_fragment(
        note, &selected, context, max_chars,
    )
}

pub(in crate::production::workbench::meta::generate) fn observation_summary_style_note_score(
    note: &str,
    context: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    split_prompt_note_fragments(note)
        .map(|fragment| {
            observation_summary_style_fragment_score(&fragment, context, constraint_pressure)
        })
        .sum()
}

pub(in crate::production::workbench::meta::generate) fn observation_summary_style_fragment_score(
    fragment: &str,
    context: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let evidence =
        super::r#match::observation_style_note_context_evidence(fragment, context) as i32;
    score_memory_style_fragment_for_lean_tier(fragment, Some(context), constraint_pressure)
        + evidence * 12
}
