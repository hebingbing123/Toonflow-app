use super::*;

pub(in crate::production::workbench::meta::generate) fn resolve_observation_filter_style_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let role_notes = select_subject_role_video_style_memory_notes_for_storyboard(
        rows,
        subject_candidates,
        storyboard_row,
    )
    .into_iter()
    .filter_map(|note| compact_contextual_video_style_note(&note, storyboard_row))
    .collect::<Vec<_>>();
    let prioritized_notes = select_prioritized_video_style_note(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
    )
    .into_iter()
    .filter_map(|note| compact_contextual_video_style_note(&note, storyboard_row))
    .collect::<Vec<_>>();
    let summary_notes = select_contextual_observation_summary_style_note(
        rows,
        storyboard_row,
        subject_candidates,
        constraint_pressure,
    )
    .into_iter()
    .collect::<Vec<_>>();

    select_pressure_prioritized_observation_filter_style_note(
        &role_notes,
        &prioritized_notes,
        &summary_notes,
        storyboard_row,
        constraint_pressure,
    )
    .or_else(|| role_notes.into_iter().next())
    .or_else(|| prioritized_notes.into_iter().next())
    .or_else(|| summary_notes.into_iter().next())
}

pub(in crate::production::workbench::meta::generate) fn select_contextual_observation_summary_style_note(
    rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let storyboard_row = storyboard_row?;
    let context = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let normalized_subject_candidates = subject_candidates
        .iter()
        .map(|value| normalize_prompt_text(value))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    let mut candidates = rows
        .iter()
        .filter_map(|row| {
            let (scope_priority, subject_priority) = match row.name.as_str() {
                "script_role_video_style_memory" => (
                    0u8,
                    memory_subject_match_priority(&row.content, &normalized_subject_candidates),
                ),
                "project_role_video_style_memory" => (
                    1u8,
                    memory_subject_match_priority(&row.content, &normalized_subject_candidates),
                ),
                "script_video_style_memory" => (2u8, usize::MAX),
                "project_video_style_memory" => (3u8, usize::MAX),
                _ => return None,
            };
            if scope_priority <= 1 && subject_priority == usize::MAX {
                return None;
            }

            let note = contextual_style_memory_value_for_storyboard(row, Some(storyboard_row))
                .or_else(|| extract_key_value(&row.content, "note"))?;
            let compacted =
                compact_guardrail_sensitive_style_note(&note, storyboard_row, constraint_pressure)
                    .or_else(|| compact_contextual_video_style_note(&note, Some(storyboard_row)))?;
            let evidence = observation_style_note_context_evidence(&note, &context).max(
                observation_style_note_context_evidence(&compacted, &context),
            );
            let compacted = rank_observation_summary_style_note_fragments(
                &compacted,
                &context,
                constraint_pressure,
            )?;
            let min_evidence = observation_summary_style_note_min_evidence(
                &compacted,
                &context,
                scope_priority,
                subject_priority,
                constraint_pressure,
            );
            let fragment_score =
                observation_summary_style_note_score(&compacted, &context, constraint_pressure);
            (evidence >= min_evidence).then_some((
                subject_priority,
                scope_priority,
                evidence,
                fragment_score,
                compacted,
            ))
        })
        .collect::<Vec<_>>();
    let locked_subject_priority = candidates
        .iter()
        .map(|(subject_priority, ..)| *subject_priority)
        .filter(|priority| *priority != usize::MAX)
        .min();
    if let Some(locked_subject_priority) = locked_subject_priority {
        candidates.retain(|(subject_priority, ..)| *subject_priority == locked_subject_priority);
    }

    candidates
        .into_iter()
        .max_by(
            |(left_subject, left_scope, left_evidence, left_score, left_note),
             (right_subject, right_scope, right_evidence, right_score, right_note)| {
                left_evidence
                    .cmp(right_evidence)
                    .then(left_score.cmp(right_score))
                    .then_with(|| right_subject.cmp(left_subject))
                    .then_with(|| right_scope.cmp(left_scope))
                    .then_with(|| right_note.chars().count().cmp(&left_note.chars().count()))
            },
        )
        .map(|(_, _, _, _, note)| note)
}

pub(in crate::production::workbench::meta::generate) fn observation_summary_style_note_min_evidence(
    compacted_note: &str,
    context: &StructuredStoryboardDescription,
    scope_priority: u8,
    subject_priority: usize,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> usize {
    if scope_priority > 1 || subject_priority == usize::MAX {
        return 2;
    }

    let scene_needs_subject_locked_memory = video_prompt_scene_needs_identity_memory(context)
        || video_prompt_scene_needs_emotional_memory(context)
        || constraint_pressure.is_some_and(|pressure| {
            pressure.has_identity_guardrail
                || pressure.has_dialogue_guardrail
                || pressure.has_emotion_guardrail
        });
    if !scene_needs_subject_locked_memory {
        return 2;
    }

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
            let evidence = observation_style_note_context_evidence(&fragment, context);
            (evidence > 0).then_some((
                observation_summary_style_fragment_score(&fragment, context, constraint_pressure),
                evidence,
                fragment.chars().count(),
                fragment,
            ))
        })
        .collect::<Vec<_>>();
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

    (!selected.is_empty()).then(|| selected.join("，"))
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
    let evidence = observation_style_note_context_evidence(fragment, context) as i32;
    score_memory_style_fragment_for_lean_tier(fragment, Some(context), constraint_pressure)
        + evidence * 12
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub(in crate::production::workbench::meta::generate) enum ObservationFilterStyleCandidateSource {
    Summary,
    Prioritized,
    Role,
}

pub(in crate::production::workbench::meta::generate) fn select_pressure_prioritized_observation_filter_style_note(
    role_notes: &[String],
    prioritized_notes: &[String],
    summary_notes: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let pressure = constraint_pressure
        .filter(|pressure| pressure.forces_compact_memory && pressure.has_active_guardrail())?;
    let storyboard_row = storyboard_row?;
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let mut best: Option<(i32, usize, ObservationFilterStyleCandidateSource, String)> = None;

    let mut consider = |note: &String, source: ObservationFilterStyleCandidateSource| {
        let compacted =
            compact_guardrail_sensitive_style_note(note, storyboard_row, Some(pressure))
                .or_else(|| compact_contextual_video_style_note(note, Some(storyboard_row)));
        let Some(compacted) = compacted else {
            return;
        };
        let score =
            score_compacted_style_note_against_constraint_pressure(&compacted, &fields, pressure)
                + match source {
                    ObservationFilterStyleCandidateSource::Role => 2,
                    ObservationFilterStyleCandidateSource::Prioritized => 1,
                    ObservationFilterStyleCandidateSource::Summary => 0,
                };
        let len = compacted.chars().count();

        match &best {
            Some((best_score, best_len, best_source, best_note))
                if *best_score > score
                    || (*best_score == score
                        && (*best_len < len
                            || (*best_len == len
                                && (*best_source > source
                                    || (*best_source == source && best_note <= &compacted))))) => {}
            _ => best = Some((score, len, source, compacted)),
        }
    };

    for note in role_notes {
        consider(note, ObservationFilterStyleCandidateSource::Role);
    }
    for note in prioritized_notes {
        consider(note, ObservationFilterStyleCandidateSource::Prioritized);
    }
    for note in summary_notes {
        consider(note, ObservationFilterStyleCandidateSource::Summary);
    }

    best.map(|(_, _, _, note)| note)
}

pub(in crate::production::workbench::meta::generate) fn observation_style_note_context_evidence(
    style_note: &str,
    context: &StructuredStoryboardDescription,
) -> usize {
    let note = normalize_prompt_text(style_note);
    let mut evidence = 0usize;

    let mood = normalize_prompt_text(&context.mood);
    if (!mood.is_empty() && note.contains(&mood))
        || style_note_matches_mood_keyword(&note, &context.mood)
    {
        evidence += 1;
    }

    let lighting = normalize_prompt_text(&context.lighting);
    if !lighting.is_empty() && note.contains(&lighting) {
        evidence += 1;
    }

    let shot = normalize_prompt_text(&context.shot);
    let camera_move = normalize_prompt_text(&context.camera_move);
    if (!shot.is_empty() && note.contains(&shot))
        || (!camera_move.is_empty() && note.contains(&camera_move))
    {
        evidence += 1;
    }

    let action = normalize_prompt_text(&context.action);
    let dialogue = normalize_prompt_text(&context.dialogue);
    if style_note_matches_shared_keyword_family(
        &note,
        &[action.as_str(), dialogue.as_str()],
        PERFORMANCE_SHARED_KEYWORD_FAMILIES,
    ) {
        evidence += 1;
    }
    if style_note_matches_shared_keyword_family(
        &note,
        &[action.as_str(), dialogue.as_str()],
        VOICE_SHARED_KEYWORD_FAMILIES,
    ) {
        evidence += 1;
    }

    let sound = normalize_prompt_text(&context.sound);
    if style_note_matches_shared_keyword_family(
        &note,
        &[sound.as_str()],
        SOUND_SHARED_KEYWORD_FAMILIES,
    ) || (!sound.is_empty() && note.contains(&sound))
    {
        evidence += 1;
    }

    evidence
}

pub(in crate::production::workbench::meta::generate) fn style_note_matches_shared_keyword_family(
    note: &str,
    fields: &[&str],
    families: &[&[&str]],
) -> bool {
    let normalized_fields = fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
        .collect::<Vec<_>>();
    !normalized_fields.is_empty()
        && families.iter().any(|family| {
            family.iter().any(|keyword| note.contains(keyword))
                && normalized_fields
                    .iter()
                    .any(|field| family.iter().any(|keyword| field.contains(keyword)))
        })
}

pub(in crate::production::workbench::meta::generate) fn style_note_matches_mood_keyword(
    note: &str,
    mood: &str,
) -> bool {
    let normalized_mood = normalize_prompt_text(mood);
    !normalized_mood.is_empty()
        && ["克制", "隐忍", "压抑", "平静", "冷静", "从容", "沉静"]
            .iter()
            .any(|keyword| normalized_mood.contains(keyword) && note.contains(keyword))
}

#[cfg_attr(not(test), allow(dead_code))]
pub(in crate::production::workbench::meta::generate) fn video_prompt_observation_conflicts_with_style(
    observation_note: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    negative_constraint_conflicts_with_storyboard_style(
        observation_note.trim(),
        selected_style_note,
        storyboard_row,
    )
}

pub(in crate::production::workbench::meta::generate) fn video_prompt_observation_is_irrelevant_to_storyboard(
    observation_note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    canonical_observation_note(observation_note) == "avoid lip-sync mismatch"
        && storyboard_row.is_some_and(storyboard_lacks_visible_speech_performance_risk)
}
