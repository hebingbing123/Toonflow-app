use super::super::*;

pub(in crate::production::workbench::meta::generate) fn resolve_observation_filter_style_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let context = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description);
    let role_notes = select_subject_role_video_style_memory_notes_for_storyboard(
        rows,
        subject_candidates,
        storyboard_row,
    )
    .into_iter()
    .filter_map(|note| {
        compact_observation_filter_candidate(
            &note,
            storyboard_row,
            context.as_ref(),
            constraint_pressure,
        )
    })
    .collect::<Vec<_>>();
    let prioritized_notes = select_prioritized_video_style_note(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
    )
    .into_iter()
    .filter_map(|note| {
        compact_observation_filter_candidate(
            &note,
            storyboard_row,
            context.as_ref(),
            constraint_pressure,
        )
    })
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

pub(in crate::production::workbench::meta::generate) fn compact_observation_filter_candidate(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    context: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let storyboard_row = storyboard_row?;
    let context = context?;
    if storyboard_supports_voice_style(context) {
        let performance_is_low_detail = split_prompt_note_fragments(note)
            .find(|fragment| fragment.starts_with("表演"))
            .is_some_and(|fragment| {
                score_memory_fragment_human_performance_detail(&fragment, Some("表演")) < 3
            });
        if performance_is_low_detail {
            if let Some(voice_fragment) = observation_voice_fragment_from_source_note(note, context)
            {
                return Some(voice_fragment);
            }
        }
    }
    if observation_delivery_performance_note_should_bypass_compaction(note, constraint_pressure) {
        return Some(note.to_string());
    }

    let candidate_note = {
        let compacted =
            compact_guardrail_sensitive_style_note(note, storyboard_row, constraint_pressure)
                .or_else(|| compact_contextual_video_style_note(note, Some(storyboard_row)))?;
        super::compact::restore_observation_delivery_signal_if_compaction_overtrims(
            note, &compacted, context,
        )
    };
    let compacted = super::rank::rank_observation_summary_style_note_fragments(
        &candidate_note,
        context,
        constraint_pressure,
    )
    .or_else(|| Some(candidate_note.clone()))?;
    (!summary_style_note_only_repeats_storyboard_fields(&compacted, context)).then_some(compacted)
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

            let note = constraint_pressure
                .filter(|pressure| {
                    pressure.has_dialogue_guardrail
                        || pressure.has_emotion_guardrail
                        || pressure.has_identity_guardrail
                        || pressure.prefer_delivery_memory_recall
                })
                .and_then(|_| extract_key_value(&row.content, "delivery"))
                .or_else(|| contextual_style_memory_value_for_storyboard(row, Some(storyboard_row)))
                .or_else(|| extract_key_value(&row.content, "note"))?;
            let bypass_compaction = observation_delivery_performance_note_should_bypass_compaction(
                &note,
                constraint_pressure,
            );
            let candidate_note = if bypass_compaction {
                note.clone()
            } else {
                let compacted = compact_guardrail_sensitive_style_note(
                    &note,
                    storyboard_row,
                    constraint_pressure,
                )
                .or_else(|| compact_contextual_video_style_note(&note, Some(storyboard_row)))?;
                super::compact::restore_observation_delivery_signal_if_compaction_overtrims(
                    &note, &compacted, &context,
                )
            };
            let evidence = super::r#match::observation_style_note_context_evidence(&note, &context)
                .max(super::r#match::observation_style_note_context_evidence(
                    &candidate_note,
                    &context,
                ));
            let compacted = if bypass_compaction {
                Some(candidate_note.clone())
            } else {
                super::rank::rank_observation_summary_style_note_fragments(
                    &candidate_note,
                    &context,
                    constraint_pressure,
                )
            }
            .or_else(|| Some(candidate_note.clone()))?;
            if row.name == "script_video_style_memory"
                && summary_style_note_only_repeats_storyboard_fields(&compacted, &context)
            {
                return None;
            }
            let min_evidence = super::rank::observation_summary_style_note_min_evidence(
                &compacted,
                &context,
                scope_priority,
                subject_priority,
                constraint_pressure,
            );
            let fragment_score = super::rank::observation_summary_style_note_score(
                &compacted,
                &context,
                constraint_pressure,
            );
            (evidence >= min_evidence).then_some((
                subject_priority,
                scope_priority,
                evidence,
                fragment_score,
                compacted,
            ))
        })
        .collect::<Vec<_>>();
    let has_subject_locked_role_candidate =
        candidates
            .iter()
            .any(|(subject_priority, scope_priority, ..)| {
                *subject_priority != usize::MAX && *scope_priority <= 1
            });
    if !has_subject_locked_role_candidate && !normalized_subject_candidates.is_empty() {
        candidates.extend(
            select_subject_role_video_style_memory_notes_for_storyboard(
                rows,
                &normalized_subject_candidates,
                Some(storyboard_row),
            )
            .into_iter()
            .filter_map(|note| {
                let bypass_compaction =
                    observation_delivery_performance_note_should_bypass_compaction(
                        &note,
                        constraint_pressure,
                    );
                let candidate_note = if bypass_compaction {
                    note.clone()
                } else {
                    let compacted = compact_guardrail_sensitive_style_note(
                        &note,
                        storyboard_row,
                        constraint_pressure,
                    )
                    .or_else(|| compact_contextual_video_style_note(&note, Some(storyboard_row)))?;
                    super::compact::restore_observation_delivery_signal_if_compaction_overtrims(
                        &note, &compacted, &context,
                    )
                };
                let evidence = super::r#match::observation_style_note_context_evidence(
                    &note, &context,
                )
                .max(super::r#match::observation_style_note_context_evidence(
                    &candidate_note,
                    &context,
                ));
                let compacted = if bypass_compaction {
                    Some(candidate_note.clone())
                } else {
                    super::rank::rank_observation_summary_style_note_fragments(
                        &candidate_note,
                        &context,
                        constraint_pressure,
                    )
                }
                .or_else(|| Some(candidate_note.clone()))?;
                if summary_style_note_only_repeats_storyboard_fields(&compacted, &context) {
                    return None;
                }
                let min_evidence = super::rank::observation_summary_style_note_min_evidence(
                    &compacted,
                    &context,
                    0,
                    0,
                    constraint_pressure,
                );
                let fragment_score = super::rank::observation_summary_style_note_score(
                    &compacted,
                    &context,
                    constraint_pressure,
                );
                (evidence >= min_evidence).then_some((0, 0, evidence, fragment_score, compacted))
            }),
        );
    }
    let locked_subject_priority = candidates
        .iter()
        .map(|(subject_priority, ..)| *subject_priority)
        .filter(|priority| *priority != usize::MAX)
        .min();
    if let Some(locked_subject_priority) = locked_subject_priority {
        candidates.retain(|(subject_priority, ..)| *subject_priority == locked_subject_priority);
    }
    if constraint_pressure.is_some_and(|pressure| {
        pressure.has_dialogue_guardrail
            || pressure.has_identity_guardrail
            || pressure.has_emotion_guardrail
    }) && candidates.iter().any(|(_, _, _, _, note)| {
        split_prompt_note_fragments(note)
            .any(|fragment| fragment.starts_with("表演") || fragment.starts_with("语气"))
    }) {
        candidates.retain(|(_, _, _, _, note)| {
            split_prompt_note_fragments(note)
                .any(|fragment| fragment.starts_with("表演") || fragment.starts_with("语气"))
        });
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
    let pressure_prefers_delivery = pressure.has_dialogue_guardrail
        || pressure.has_identity_guardrail
        || pressure.has_emotion_guardrail;
    if pressure_prefers_delivery {
        let preferred = role_notes
            .iter()
            .chain(summary_notes.iter())
            .find_map(|note| {
                let compacted =
                    compact_guardrail_sensitive_style_note(note, storyboard_row, Some(pressure))
                        .or_else(|| {
                            compact_contextual_video_style_note(note, Some(storyboard_row))
                        })?;
                let chosen_note =
                    super::compact::restore_observation_delivery_signal_if_compaction_overtrims(
                        note, &compacted, &fields,
                    );
                let has_delivery_signal = split_prompt_note_fragments(&chosen_note)
                    .any(|fragment| fragment.starts_with("表演") || fragment.starts_with("语气"));
                has_delivery_signal.then_some(chosen_note)
            });
        if preferred.is_some() {
            return preferred;
        }
    }
    let mut best: Option<(i32, usize, ObservationFilterStyleCandidateSource, String)> = None;

    let mut consider = |note: &String, source: ObservationFilterStyleCandidateSource| {
        let compacted =
            compact_guardrail_sensitive_style_note(note, storyboard_row, Some(pressure))
                .or_else(|| compact_contextual_video_style_note(note, Some(storyboard_row)));
        let Some(compacted) = compacted else {
            return;
        };
        let chosen_note =
            super::compact::restore_observation_delivery_signal_if_compaction_overtrims(
                note, &compacted, &fields,
            );
        let delivery_bias = i32::from(
            (pressure.has_dialogue_guardrail
                || pressure.has_identity_guardrail
                || pressure.has_emotion_guardrail)
                && split_prompt_note_fragments(&chosen_note)
                    .any(|fragment| fragment.starts_with("表演") || fragment.starts_with("语气")),
        ) * 8;
        let score =
            score_compacted_style_note_against_constraint_pressure(&chosen_note, &fields, pressure)
                + delivery_bias
                + match source {
                    ObservationFilterStyleCandidateSource::Role => 2,
                    ObservationFilterStyleCandidateSource::Prioritized => 1,
                    ObservationFilterStyleCandidateSource::Summary => 0,
                };
        let len = chosen_note.chars().count();

        match &best {
            Some((best_score, best_len, best_source, best_note))
                if *best_score > score
                    || (*best_score == score
                        && (*best_len < len
                            || (*best_len == len
                                && (*best_source > source
                                    || (*best_source == source
                                        && best_note <= &chosen_note))))) => {}
            _ => best = Some((score, len, source, chosen_note)),
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

fn observation_delivery_performance_note_should_bypass_compaction(
    note: &str,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    constraint_pressure.is_some_and(|pressure| {
        (pressure.has_dialogue_guardrail
            || pressure.has_emotion_guardrail
            || pressure.has_identity_guardrail
            || pressure.prefer_delivery_memory_recall)
            && selected_note_is_self_sufficient_delivery_performance(note)
    })
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

pub(in crate::production::workbench::meta::generate) fn observation_voice_fragment_from_source_note(
    source_note: &str,
    context: &StructuredStoryboardDescription,
) -> Option<String> {
    if !storyboard_supports_voice_style(context) {
        return None;
    }

    split_prompt_note_fragments(source_note)
        .find(|fragment| fragment.starts_with("语气"))
        .and_then(|fragment| trim_style_fragment_against_storyboard_fields(&fragment, context))
        .map(|fragment| {
            if memory_fragment_has_high_signal_voice_detail(
                normalize_prompt_text(&fragment).as_str(),
            ) {
                fragment
            } else {
                super::compact::strip_observation_voice_mood_tail(&fragment)
            }
        })
        .or_else(|| {
            let normalized = normalize_prompt_text(source_note);
            [
                ("压低气息尾音发颤", "语气压低气息尾音发颤"),
                ("压低哽咽尾音", "语气压低哽咽尾音"),
                ("低声哽咽尾音", "语气低声哽咽尾音"),
                ("轻声哽咽尾音", "语气轻声哽咽尾音"),
                ("低声尾音发颤", "语气低声尾音发颤"),
                ("轻声尾音发颤", "语气轻声尾音发颤"),
                ("哽咽克制", "语气哽咽"),
                ("轻声克制", "语气轻声"),
                ("低声克制", "语气低声"),
                ("轻声", "语气轻声"),
                ("低声", "语气低声"),
                ("呢喃", "语气呢喃"),
                ("哽咽", "语气哽咽"),
            ]
            .into_iter()
            .find(|(marker, _)| normalized.contains(marker))
            .map(|(_, fragment)| fragment.to_string())
        })
}
