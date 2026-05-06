use super::*;

pub(in crate::production::workbench::meta::generate) fn rejected_video_memory_selection_bias(
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<VideoPromptMemorySelectionBias> {
    constraint_pressure.and_then(|pressure| {
        let bias = VideoPromptMemorySelectionBias {
            prefer_delivery: pressure.prefer_delivery_memory_recall,
            prefer_visual_continuity: pressure.prefer_visual_continuity_memory_recall,
        };
        (bias.prefer_delivery || bias.prefer_visual_continuity).then_some(bias)
    })
}

#[allow(clippy::too_many_arguments)]
pub(in crate::production::workbench::meta::generate) async fn load_video_prompt_memory_notes(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Result<(Vec<String>, Vec<String>), ApiError> {
    let rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN ('selected_video_memory', 'script_video_style_memory', 'script_video_generation_brief_memory', 'script_role_video_style_memory', 'auto_scope_memory'))
            OR (episodes_id IS NULL AND name IN ('project_video_style_memory', 'project_video_generation_brief_memory', 'project_role_video_style_memory'))
          )
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(VIDEO_PROMPT_MEMORY_ROW_LIMIT)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(build_video_prompt_memory_notes_with_pressure(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        constraint_pressure,
    ))
}

#[cfg_attr(not(test), allow(dead_code))]
pub(in crate::production::workbench::meta::generate) fn build_video_prompt_memory_notes(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
) -> (Vec<String>, Vec<String>) {
    build_video_prompt_memory_notes_with_pressure(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        None,
    )
}

pub(in crate::production::workbench::meta::generate) fn build_video_prompt_memory_notes_with_pressure(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> (Vec<String>, Vec<String>) {
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let rows = trim_video_prompt_memory_rows_with_context(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &subject_candidates,
        Some(storyboard_row),
        constraint_pressure,
    );
    let style_notes = compact_guardrail_sensitive_style_notes(
        select_video_prompt_style_notes(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            storyboard_row,
            constraint_pressure,
        ),
        storyboard_row,
        constraint_pressure,
    );
    let style_notes = restore_runtime_exact_style_note_fragments(
        style_notes,
        &rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
    );
    let continuity_notes = {
        let selected = select_video_prompt_memory_notes(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            Some(storyboard_row),
        );
        if selected.is_empty() {
            select_runtime_action_continuity_fallback(
                &rows,
                storyboard_numeric_id,
                current_prompt_seed,
                storyboard_row,
            )
            .into_iter()
            .collect()
        } else {
            selected
        }
    };
    (style_notes.into_iter().collect(), continuity_notes)
}

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
            preserve_runtime_exact_camera_fragment(
                &note,
                &supplement_compacted_voice_note(&note, &compacted, storyboard_row),
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
        compact_neighbor_video_style_note(&note, Some(storyboard_row))
            .map(|compacted| supplement_compacted_voice_note(&note, &compacted, storyboard_row))
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
        && !exact_style_notes_should_yield_to_role_memory(&exact, &role_memory_notes)
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

fn preserve_runtime_exact_camera_fragment(original_note: &str, compacted_note: &str) -> String {
    if split_prompt_note_fragments(compacted_note).any(|fragment| fragment.starts_with("镜头")) {
        return compacted_note.to_string();
    }
    let original_has_character_signal =
        split_prompt_note_fragments(original_note).any(|fragment| {
            matches!(
                style_note_fragment_family(&fragment),
                Some("表演") | Some("语气")
            )
        });
    if !original_has_character_signal {
        return compacted_note.to_string();
    }

    let Some(camera_fragment) =
        split_prompt_note_fragments(original_note).find(|fragment| fragment.starts_with("镜头"))
    else {
        return compacted_note.to_string();
    };
    let keeps_character_signal = split_prompt_note_fragments(compacted_note).any(|fragment| {
        matches!(
            style_note_fragment_family(&fragment),
            Some("表演") | Some("语气")
        )
    });
    if !keeps_character_signal {
        return compacted_note.to_string();
    }

    sort_style_note_fragments_for_output(&format!("{camera_fragment}，{compacted_note}"))
        .unwrap_or_else(|| compacted_note.to_string())
}

fn restore_runtime_exact_style_note_fragments(
    notes: Vec<String>,
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    _storyboard_row: &StoryboardPromptSeedRow,
) -> Vec<String> {
    let exact_notes = rows
        .iter()
        .filter(|row| {
            selected_runtime_style_row_matches(row, storyboard_numeric_id, current_prompt_seed)
        })
        .filter_map(|row| extract_key_value(&row.content, "style"))
        .collect::<Vec<_>>();
    notes
        .into_iter()
        .map(|note| {
            exact_notes
                .iter()
                .find_map(|exact_note| {
                    let restored = preserve_runtime_exact_camera_fragment(exact_note, &note);
                    (restored != note).then_some(restored)
                })
                .unwrap_or(note)
        })
        .collect()
}

fn selected_runtime_style_row_matches(
    row: &AgentMemoryRow,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> bool {
    if row.name != "selected_video_memory" {
        return false;
    }

    let storyboard_matches =
        extract_key_value(&row.content, "storyboardIds").is_some_and(|value| {
            value
                .split(',')
                .map(normalize_prompt_text)
                .any(|part| part == storyboard_numeric_id.to_string())
        });
    if !storyboard_matches {
        return false;
    }

    match current_prompt_seed {
        Some(seed) => extract_key_value(&row.content, "promptSeed")
            .is_none_or(|value| normalize_prompt_text(&value) == normalize_prompt_text(seed)),
        None => true,
    }
}

fn select_runtime_action_continuity_fallback(
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

    let candidates = rows.iter()
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
                compact_generation_brief_style_note_for_storyboard(
                    &note,
                    storyboard_row,
                    constraint_pressure,
                )
            } else {
                compact_guardrail_sensitive_style_note(&note, storyboard_row, constraint_pressure)
                    .or_else(|| compact_contextual_video_style_note(&note, Some(storyboard_row)))
            }?;
            if !row.name.contains("generation_brief")
                && fields.as_ref().is_some_and(|fields| {
                    summary_style_note_only_repeats_storyboard_fields(&compacted, fields)
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

fn compact_generation_brief_style_note_for_storyboard(
    note: &str,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let expanded = expand_compacted_delivery_style_note(note);
    let mut fragments = split_prompt_note_fragments(&expanded)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| match style_note_fragment_family(fragment) {
            Some("表演") => true,
            Some("语气") => storyboard_supports_voice_style(&fields),
            Some("光影") => true,
            Some("环境") => {
                fragment.contains("连续")
                    || fragment.contains("轮廓")
                    || fragment.contains("保住")
                    || observation_style_note_context_evidence(fragment, &fields) > 0
            }
            _ => observation_style_note_context_evidence(fragment, &fields) > 0,
        })
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        fragments = split_prompt_note_fragments(&expanded).collect::<Vec<_>>();
    }

    let pressure = constraint_pressure.unwrap_or_default();
    if pressure.prefer_visual_continuity_memory_recall || pressure.has_lighting_guardrail {
        fragments.retain(|fragment| {
            fragment.starts_with("光影")
                || (fragment.starts_with("环境")
                    && (fragment.contains("连续")
                        || fragment.contains("轮廓")
                        || fragment.contains("保住")))
        });
    } else if pressure.prefer_delivery_memory_recall
        || pressure.has_dialogue_guardrail
        || pressure.has_emotion_guardrail
    {
        fragments.retain(|fragment| fragment.starts_with("表演") || fragment.starts_with("语气"));
    }

    if fragments.is_empty() {
        return None;
    }

    fragments = fragments
        .into_iter()
        .map(|fragment| {
            if let Some(body) = fragment.strip_prefix("光影") {
                if let Some(idx) = body.find("里保住") {
                    return format!("光影{}", &body[idx..]);
                }
            }
            fragment
        })
        .collect();
    if (pressure.prefer_visual_continuity_memory_recall || pressure.has_lighting_guardrail)
        && expanded.contains("环境")
        && expanded.contains("连续")
        && !fragments
            .iter()
            .any(|fragment| fragment.starts_with("环境"))
    {
        if let Some(environment_fragment) = split_prompt_note_fragments(&expanded)
            .find(|fragment| fragment.starts_with("环境") && fragment.contains("连续"))
        {
            fragments.push(environment_fragment);
        }
    }

    let joined = sort_style_note_fragments_for_output(&fragments.join("，"))?;
    Some(supplement_compacted_voice_note(
        &expanded,
        &joined,
        storyboard_row,
    ))
}

pub(in crate::production::workbench::meta::generate) fn summary_style_note_only_repeats_storyboard_fields(
    note: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    !fragments.is_empty()
        && fragments
            .iter()
            .all(|fragment| match style_note_fragment_family(fragment) {
                Some("镜头") => {
                    prompt_style_fragment_overlaps_field(fragment, &fields.shot)
                        || prompt_style_fragment_overlaps_field(fragment, &fields.camera_move)
                        || low_signal_local_camera_style_fragment(fragment)
                }
                Some("情绪") => prompt_style_fragment_overlaps_field(fragment, &fields.mood),
                Some("光影") => prompt_style_fragment_overlaps_field(fragment, &fields.lighting),
                Some("动作") => prompt_style_fragment_overlaps_field(fragment, &fields.action),
                Some("环境") => {
                    prompt_style_fragment_overlaps_field(fragment, &fields.setting)
                        || prompt_style_fragment_overlaps_field(fragment, &fields.sound)
                }
                _ => false,
            })
}

fn supplement_compacted_voice_note(
    source_note: &str,
    compacted_note: &str,
    storyboard_row: &StoryboardPromptSeedRow,
) -> String {
    let has_voice =
        split_prompt_note_fragments(compacted_note).any(|fragment| fragment.starts_with("语气"));
    if has_voice {
        return compacted_note.to_string();
    }
    let has_performance =
        split_prompt_note_fragments(compacted_note).any(|fragment| fragment.starts_with("表演"));
    if !has_performance {
        return compacted_note.to_string();
    }
    let Some(voice_note) = extract_visible_voice_fragment_from_note(source_note, storyboard_row)
    else {
        return compacted_note.to_string();
    };
    sort_style_note_fragments_for_output(&format!("{compacted_note}，{voice_note}"))
        .unwrap_or_else(|| compacted_note.to_string())
}

fn extract_visible_voice_fragment_from_note(
    source_note: &str,
    storyboard_row: &StoryboardPromptSeedRow,
) -> Option<String> {
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    if !storyboard_supports_voice_style(&fields) {
        return None;
    }

    let visible_speech = [
        fields.action.as_str(),
        fields.dialogue.as_str(),
        storyboard_row.prompt.as_deref().unwrap_or_default(),
    ]
    .into_iter()
    .any(|field| {
        ["开口", "说", "低声", "轻声", "压低", "呢喃", "哽咽"]
            .iter()
            .any(|keyword| field.contains(keyword))
    });
    if !visible_speech && storyboard_dialogue_is_empty(&fields.dialogue) {
        return None;
    }

    let normalized = normalize_prompt_text(source_note);
    [
        "压低气息尾音发颤",
        "压低哽咽尾音",
        "低声哽咽尾音",
        "轻声哽咽尾音",
        "低声尾音发颤",
        "轻声尾音发颤",
        "哽咽克制",
        "轻声克制",
        "低声克制",
        "轻声",
        "低声",
        "呢喃",
        "哽咽",
        "短促",
    ]
    .into_iter()
    .find(|marker| normalized.contains(marker))
    .map(|marker| match marker {
        "轻声克制" => "语气轻声".to_string(),
        "低声克制" => "语气低声".to_string(),
        "哽咽克制" => "语气哽咽".to_string(),
        other => format!("语气{other}"),
    })
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
            let compacted =
                compact_guardrail_sensitive_style_note(note, storyboard_row, Some(pressure))
                    .or_else(|| compact_contextual_video_style_note(note, Some(storyboard_row)));
            let Some(compacted) = compacted else {
                return;
            };
            if pressure.has_dialogue_guardrail || pressure.prefer_delivery_memory_recall {
                preserve_delivery_pair_if_compaction_overtrims(note, &compacted)
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

fn preserve_delivery_pair_if_compaction_overtrims(original: &str, compacted: &str) -> String {
    let original_has_pair = split_prompt_note_fragments(original)
        .any(|fragment| fragment.starts_with("表演"))
        && split_prompt_note_fragments(original).any(|fragment| fragment.starts_with("语气"));
    let compacted_lost_voice = split_prompt_note_fragments(compacted)
        .any(|fragment| fragment.starts_with("表演"))
        && !split_prompt_note_fragments(compacted).any(|fragment| fragment.starts_with("语气"));
    if original_has_pair && compacted_lost_voice {
        original.to_string()
    } else {
        compacted.to_string()
    }
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

pub(in crate::production::workbench::meta::generate) fn compact_guardrail_sensitive_style_notes(
    notes: Vec<String>,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Vec<String> {
    notes
        .into_iter()
        .filter_map(|note| {
            compact_guardrail_sensitive_style_note(&note, storyboard_row, constraint_pressure)
        })
        .collect()
}

pub(in crate::production::workbench::meta::generate) fn compact_guardrail_sensitive_style_note(
    note: &str,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let contextual_note = compact_contextual_video_style_note(note, Some(storyboard_row))
        .or_else(|| Some(note.to_string()))?;
    let Some(pressure) = constraint_pressure
        .filter(|pressure| pressure.forces_compact_memory && pressure.has_active_guardrail())
    else {
        return Some(contextual_note);
    };
    let Some(fields) = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    else {
        return Some(contextual_note);
    };
    let fragments = split_prompt_note_fragments(&contextual_note).collect::<Vec<_>>();
    if fragments.is_empty() {
        return Some(contextual_note);
    }

    let compacted =
        select_best_memory_style_note_for_lean_tier(&fragments, Some(&fields), Some(pressure))
            .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS))
            .unwrap_or(contextual_note);

    Some(compacted)
}

pub(in crate::production::workbench::meta::generate) fn exact_style_notes_should_yield_to_role_memory(
    exact_notes: &[String],
    role_memory_notes: &[String],
) -> bool {
    !role_memory_notes.is_empty()
        && !exact_notes.is_empty()
        && exact_notes
            .iter()
            .all(|note| exact_style_note_is_low_signal_template(note))
}

pub(in crate::production::workbench::meta::generate) fn exact_style_note_is_low_signal_template(
    note: &str,
) -> bool {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    !fragments.is_empty()
        && fragments
            .iter()
            .all(|fragment| low_signal_template_style_fragment(fragment))
}

pub(in crate::production::workbench::meta::generate) fn low_signal_template_style_fragment(
    fragment: &str,
) -> bool {
    low_signal_local_camera_style_fragment(fragment)
        || (fragment.starts_with("动作") && generic_motion_style_fragment(fragment))
}

pub(in crate::production::workbench::meta::generate) fn low_signal_local_camera_style_fragment(
    fragment: &str,
) -> bool {
    if !fragment.starts_with("镜头") {
        return false;
    }

    let body = normalize_prompt_text(fragment.trim_start_matches("镜头"));
    if body.is_empty() {
        return false;
    }
    if [
        "压迫", "冷峻", "紧张", "逆光", "光影", "情绪", "表演", "语气", "环境", "声场", "雨丝",
        "霓虹", "停顿", "哽咽",
    ]
    .iter()
    .any(|keyword| body.contains(keyword))
    {
        return false;
    }

    is_local_framing_only_fragment(fragment)
        || [
            "稳定",
            "稳定跟拍",
            "跟拍",
            "近景稳定",
            "中景稳定",
            "远景稳定",
            "特写稳定",
            "全景稳定",
        ]
        .iter()
        .any(|candidate| body == *candidate)
}
