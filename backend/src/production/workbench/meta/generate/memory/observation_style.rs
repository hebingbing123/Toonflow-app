use super::*;

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

fn compact_observation_filter_candidate(
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
        restore_observation_delivery_signal_if_compaction_overtrims(note, &compacted, context)
    };
    let compacted = rank_observation_summary_style_note_fragments(
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
                restore_observation_delivery_signal_if_compaction_overtrims(
                    &note, &compacted, &context,
                )
            };
            let evidence = observation_style_note_context_evidence(&note, &context).max(
                observation_style_note_context_evidence(&candidate_note, &context),
            );
            let compacted = if bypass_compaction {
                Some(candidate_note.clone())
            } else {
                rank_observation_summary_style_note_fragments(
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
                    restore_observation_delivery_signal_if_compaction_overtrims(
                        &note, &compacted, &context,
                    )
                };
                let evidence = observation_style_note_context_evidence(&note, &context).max(
                    observation_style_note_context_evidence(&candidate_note, &context),
                );
                let compacted = if bypass_compaction {
                    Some(candidate_note.clone())
                } else {
                    rank_observation_summary_style_note_fragments(
                        &candidate_note,
                        &context,
                        constraint_pressure,
                    )
                }
                .or_else(|| Some(candidate_note.clone()))?;
                if summary_style_note_only_repeats_storyboard_fields(&compacted, &context) {
                    return None;
                }
                let min_evidence = observation_summary_style_note_min_evidence(
                    &compacted,
                    &context,
                    0,
                    0,
                    constraint_pressure,
                );
                let fragment_score =
                    observation_summary_style_note_score(&compacted, &context, constraint_pressure);
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
            let fragment =
                normalize_observation_contextual_fragment(&fragment, context, constraint_pressure)?;
            let evidence = observation_style_note_context_evidence(&fragment, context);
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
        for fragment in observation_summary_subject_locked_fallback_fragments(note, context) {
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
        for fragment in observation_summary_subject_locked_fallback_fragments(note, context) {
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
                Some(strip_observation_voice_mood_tail(&trimmed))
            })
            .collect::<Vec<_>>();
        if !delivery_fragments.is_empty() {
            selected = sort_style_note_fragments_for_output(&delivery_fragments.join("，"))
                .unwrap_or(selected);
        }
    }
    supplement_observation_summary_voice_fragment(note, &selected, context, max_chars)
}

fn normalize_observation_contextual_fragment(
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

fn strip_observation_voice_mood_tail(fragment: &str) -> String {
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

fn observation_summary_subject_locked_fallback_fragments(
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

fn supplement_observation_summary_voice_fragment(
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
        observation_voice_fragment_from_source_note(source_note, context).filter(|fragment| {
            !style_fragment_is_low_gain_hidden_speech_voice(fragment, context, "")
                && !style_fragment_is_low_gain_mood_carryover(fragment, context)
        });
    let performance_is_low_detail = selected_fragments
        .iter()
        .filter(|fragment| fragment.starts_with("表演"))
        .all(|fragment| score_memory_fragment_human_performance_detail(fragment, Some("表演")) < 3);
    if performance_is_low_detail {
        return observation_voice_fragment_from_source_note(source_note, context)
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

fn observation_voice_fragment_from_source_note(
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
                strip_observation_voice_mood_tail(&fragment)
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

fn restore_observation_delivery_signal_if_compaction_overtrims(
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
                let chosen_note = restore_observation_delivery_signal_if_compaction_overtrims(
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
            restore_observation_delivery_signal_if_compaction_overtrims(note, &compacted, &fields);
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
