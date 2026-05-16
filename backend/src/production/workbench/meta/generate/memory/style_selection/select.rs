use super::*;

pub(in crate::production::workbench::meta::generate) fn select_video_prompt_style_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Vec<String> {
    let current_subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let role_memory_candidates = select_subject_role_video_style_memory_notes_for_storyboard(
        rows,
        &current_subject_candidates,
        Some(storyboard_row),
    );
    let exact = select_selected_video_memory_notes_for_storyboard(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        Some(storyboard_row),
    )
    .into_iter()
    .map(|note| expand_compacted_delivery_style_note(&note))
    .filter_map(|note| {
        compact_contextual_video_style_note(&note, Some(storyboard_row)).map(|compacted| {
            super::compact::preserve_runtime_exact_camera_fragment(
                &note,
                &super::compact::supplement_compacted_voice_note(&note, &compacted, storyboard_row),
            )
        })
    })
    .collect::<Vec<_>>();
    let mut role_memory_notes = role_memory_candidates
        .iter()
        .map(|note| expand_compacted_delivery_style_note(note))
        .filter_map(|note| compact_contextual_video_style_note(&note, Some(storyboard_row)))
        .take(1)
        .collect::<Vec<_>>();
    let exact_has_high_signal_style = exact.iter().any(|note| {
        split_prompt_note_fragments(note).any(|fragment| {
            fragment.starts_with("镜头")
                || fragment.starts_with("情绪")
                || fragment.starts_with("光影")
        })
    });
    if !role_memory_notes
        .iter()
        .any(|note| split_prompt_note_fragments(note).any(|fragment| fragment.starts_with("语气")))
        && (!role_memory_notes.is_empty() || exact_has_high_signal_style)
    {
        if let Some(voice_note) = collect_subject_role_voice_support_notes(
            rows,
            &current_subject_candidates,
            storyboard_row,
        )
        .into_iter()
        .find(|note: &String| !note.is_empty())
        {
            role_memory_notes.push(voice_note);
        } else if let Some(voice_note) = role_memory_candidates
            .iter()
            .filter_map(|note| extract_compactable_role_voice_note(note, storyboard_row))
            .find(|note: &String| !note.is_empty())
        {
            role_memory_notes.push(voice_note);
        }
    }
    role_memory_notes = collapse_role_style_notes(role_memory_notes);
    let role_only = prefer_role_memory_only_for_silent_identity_scene(
        &exact,
        &role_memory_notes,
        storyboard_row,
    );
    let merged = merge_exact_and_role_style_notes_for_high_value_scene(
        &exact,
        &role_memory_notes,
        storyboard_row,
    );
    let prioritized = select_prioritized_video_style_note(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        Some(storyboard_row),
    )
    .into_iter()
    .map(|note| expand_compacted_delivery_style_note(&note))
    .filter_map(|note| compact_contextual_video_style_note(&note, Some(storyboard_row)))
    .collect::<Vec<_>>();
    let summary = [
        select_scoped_contextual_summary_style_note(
            rows,
            storyboard_row,
            constraint_pressure,
            &[
                "script_video_style_memory",
                "script_video_generation_brief_memory",
            ],
        ),
        select_scoped_contextual_summary_style_note(
            rows,
            storyboard_row,
            constraint_pressure,
            &[
                "project_video_style_memory",
                "project_video_generation_brief_memory",
            ],
        ),
    ]
    .into_iter()
    .flatten()
    .collect::<Vec<_>>();
    let neighbor = collect_neighbor_video_prompt_style_notes(
        rows,
        storyboard_numeric_id,
        &current_subject_candidates,
    )
    .into_iter()
    .map(|note| expand_compacted_delivery_style_note(&note))
    .filter_map(|note| {
        compact_neighbor_video_style_note(&note, Some(storyboard_row)).map(|compacted| {
            super::compact::supplement_compacted_voice_note(&note, &compacted, storyboard_row)
        })
    })
    .take(1)
    .collect::<Vec<_>>();
    if let Some(role_only) = role_only {
        return vec![role_only];
    }
    if let Some(merged) = merged {
        return vec![merged];
    }
    if let Some(selected) = select_pressure_prioritized_style_note_candidate(
        &exact,
        &role_memory_notes,
        &prioritized,
        &summary,
        &neighbor,
        storyboard_row,
        constraint_pressure,
    ) {
        return vec![selected];
    }
    if !exact.is_empty()
        && !super::compact::exact_style_notes_should_yield_to_role_memory(
            &exact,
            &role_memory_notes,
        )
    {
        return exact;
    }

    if !role_memory_notes.is_empty() {
        return role_memory_notes;
    }
    if !prioritized.is_empty()
        && neighbor.first().zip(prioritized.first()).is_some_and(
            |(neighbor_note, prioritized_note)| {
                style_note_fragments_subset_of(prioritized_note, neighbor_note)
            },
        )
    {
        return neighbor;
    }
    if !prioritized.is_empty() {
        return prioritized;
    }
    if !summary.is_empty() {
        return summary;
    }
    neighbor
}

pub(in crate::production::workbench::meta::generate) fn select_runtime_action_continuity_fallback(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
) -> Option<String> {
    let structured_fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description);
    rows.iter()
        .filter(|row| row.name == "auto_scope_memory")
        .filter(|row| auto_scope_memory_tool_matches_video_prompt(row.content.as_str()))
        .filter(|row| runtime_row_overlaps_storyboard(&row.content, storyboard_numeric_id))
        .filter(|row| {
            auto_scope_memory_matches_current_prompt_seed(
                row.content.as_str(),
                storyboard_numeric_id,
                current_prompt_seed,
                false,
            )
        })
        .filter_map(|row| {
            extract_key_value(&row.content, "summary")
                .or_else(|| extract_key_value(&row.content, "result"))
                .and_then(|value| {
                    compact_storyboard_memory_continuity_note(&value, structured_fields.as_ref())
                })
                .and_then(|value| compact_auto_scope_continuity_summary(&value))
        })
        .find(|note| note.contains("动作接上"))
}

fn runtime_row_overlaps_storyboard(content: &str, storyboard_numeric_id: i32) -> bool {
    extract_key_value(content, "scope")
        .map(|scope| scope.replace("storyboardIds=", ""))
        .or_else(|| extract_key_value(content, "storyboardIds"))
        .is_some_and(|value| {
            value
                .split(',')
                .map(normalize_prompt_text)
                .any(|part| part == storyboard_numeric_id.to_string())
        })
}

fn select_scoped_contextual_summary_style_note(
    rows: &[AgentMemoryRow],
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
    allowed_names: &[&str],
) -> Option<String> {
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description);

    let candidates = rows
        .iter()
        .filter(|row| allowed_names.contains(&row.name.as_str()))
        .filter_map(|row| {
            let is_generation_brief = row.name.contains("generation_brief");
            let note = if row.name.contains("generation_brief") {
                extract_key_value(&row.content, "style")
                    .map(|value| expand_compacted_delivery_style_note(&value))
            } else {
                contextual_style_memory_value_for_storyboard(row, Some(storyboard_row))
                    .map(|value| expand_compacted_delivery_style_note(&value))
            }
            .or_else(|| extract_key_value(&row.content, "style"))
            .or_else(|| extract_key_value(&row.content, "note"))?;
            let compacted = if row.name.contains("generation_brief") {
                super::compact::compact_generation_brief_style_note_for_storyboard(
                    &note,
                    storyboard_row,
                    constraint_pressure,
                )
            } else {
                super::compact::compact_guardrail_sensitive_style_note(
                    &note,
                    storyboard_row,
                    constraint_pressure,
                )
                .or_else(|| compact_contextual_video_style_note(&note, Some(storyboard_row)))
            }?;
            if !row.name.contains("generation_brief")
                && fields.as_ref().is_some_and(|fields| {
                    super::compact::summary_style_note_only_repeats_storyboard_fields(
                        &compacted, fields,
                    )
                })
            {
                return None;
            }
            let evidence = fields
                .as_ref()
                .map(|fields| observation_style_note_context_evidence(&compacted, fields) as i32)
                .unwrap_or(0);
            let score = fields
                .as_ref()
                .map(|fields| {
                    score_compacted_style_note_against_constraint_pressure(
                        &compacted,
                        fields,
                        constraint_pressure.unwrap_or_default(),
                    )
                })
                .unwrap_or(0);
            let brief_priority = i32::from(is_generation_brief);
            Some((
                score,
                evidence,
                brief_priority,
                compacted.chars().count(),
                is_generation_brief,
                compacted,
            ))
        })
        .collect::<Vec<_>>();

    candidates
        .iter()
        .filter(|candidate| {
            !candidates.iter().any(|other| {
                if std::ptr::eq(*candidate, other) {
                    return false;
                }
                let candidate_note = &candidate.5;
                let other_note = &other.5;
                let overlaps = style_note_fragments_subset_of(candidate_note, other_note)
                    || style_note_fragments_subset_of(other_note, candidate_note);
                overlaps
                    && other.0 >= candidate.0
                    && other.1 >= candidate.1
                    && other.3 <= candidate.3
                    && (other.4 != candidate.4 || other.3 < candidate.3)
            })
        })
        .max_by(|left, right| {
            left.0
                .cmp(&right.0)
                .then(left.1.cmp(&right.1))
                .then(left.2.cmp(&right.2))
                .then_with(|| right.3.cmp(&left.3))
                .then_with(|| right.5.cmp(&left.5))
        })
        .map(|(_, _, _, _, _, note)| note.clone())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub(in crate::production::workbench::meta::generate) enum PressureStyleCandidateSource {
    Neighbor,
    Summary,
    Prioritized,
    Role,
    Exact,
}

pub(in crate::production::workbench::meta::generate) fn select_pressure_prioritized_style_note_candidate(
    exact_notes: &[String],
    role_memory_notes: &[String],
    prioritized_notes: &[String],
    summary_notes: &[String],
    neighbor_notes: &[String],
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let pressure = constraint_pressure.filter(|pressure| pressure.has_active_guardrail())?;
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let mut best: Option<(i32, usize, PressureStyleCandidateSource, String)> = None;

    let mut consider = |note: &String, source: PressureStyleCandidateSource| {
        let chosen_note = if source == PressureStyleCandidateSource::Summary {
            note.clone()
        } else {
            let compacted = super::compact::compact_guardrail_sensitive_style_note(
                note,
                storyboard_row,
                Some(pressure),
            )
            .or_else(|| compact_contextual_video_style_note(note, Some(storyboard_row)));
            let Some(compacted) = compacted else {
                return;
            };
            if pressure.has_dialogue_guardrail || pressure.prefer_delivery_memory_recall {
                super::compact::preserve_delivery_pair_if_compaction_overtrims(note, &compacted)
            } else {
                compacted
            }
        };
        let score =
            score_compacted_style_note_against_constraint_pressure(&chosen_note, &fields, pressure)
                + match source {
                    PressureStyleCandidateSource::Exact => 2,
                    PressureStyleCandidateSource::Role => 1,
                    PressureStyleCandidateSource::Prioritized => 0,
                    PressureStyleCandidateSource::Summary => 0,
                    PressureStyleCandidateSource::Neighbor => -1,
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

    for note in exact_notes {
        consider(note, PressureStyleCandidateSource::Exact);
    }
    for note in role_memory_notes {
        consider(note, PressureStyleCandidateSource::Role);
    }
    for note in prioritized_notes {
        consider(note, PressureStyleCandidateSource::Prioritized);
    }
    for note in summary_notes {
        consider(note, PressureStyleCandidateSource::Summary);
    }
    for note in neighbor_notes {
        consider(note, PressureStyleCandidateSource::Neighbor);
    }

    best.map(|(_, _, _, note)| note)
}

fn style_note_fragments_subset_of(left: &str, right: &str) -> bool {
    let left_fragments = split_prompt_note_fragments(left).collect::<Vec<_>>();
    let right_fragments = split_prompt_note_fragments(right).collect::<Vec<_>>();
    !left_fragments.is_empty()
        && left_fragments.iter().all(|left_fragment| {
            right_fragments.iter().any(|right_fragment| {
                left_fragment == right_fragment
                    || right_fragment.contains(left_fragment)
                    || left_fragment.contains(right_fragment)
            })
        })
}
