use super::*;

pub(in crate::production::workbench::meta::generate) struct PendingVideoObservationSelection {
    pub(in crate::production::workbench::meta::generate) note: String,
    pub(in crate::production::workbench::meta::generate) source: &'static str,
}

#[allow(dead_code)]
pub(in crate::production::workbench::meta::generate) fn build_pending_video_observation_note_from_runtime(
    runtime: &StoryboardNegativePromptRuntime,
) -> Option<String> {
    build_pending_video_observation_selection_from_runtime(runtime).map(|selection| selection.note)
}

pub(in crate::production::workbench::meta::generate) fn build_pending_video_observation_selection_from_runtime(
    runtime: &StoryboardNegativePromptRuntime,
) -> Option<PendingVideoObservationSelection> {
    let constraint_pressure =
        VideoPromptConstraintPressure::from_runtime_constraints(Some(&runtime.selection), None);
    build_pending_video_observation_selection(
        runtime.prompt_support_rows.clone(),
        runtime.storyboard_id,
        runtime.current_prompt_seed.as_deref(),
        runtime.storyboard_row.as_ref(),
        &runtime.subject_candidates,
        Some(runtime.pending_observation_candidates.clone()),
        constraint_pressure,
    )
}

#[allow(dead_code)]
pub(in crate::production::workbench::meta::generate) fn build_pending_video_observation_note(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
    preselected_candidates: Option<Vec<String>>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    build_pending_video_observation_selection(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        subject_candidates,
        preselected_candidates,
        constraint_pressure,
    )
    .map(|selection| selection.note)
}

pub(in crate::production::workbench::meta::generate) fn build_pending_video_observation_selection(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
    preselected_candidates: Option<Vec<String>>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<PendingVideoObservationSelection> {
    let patch_attribution_candidates =
        collect_patch_attribution_observation_candidates(&rows, storyboard_row);
    let rows = trim_video_prompt_observation_rows(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        storyboard_row,
    );
    let prioritized_style_note = resolve_observation_filter_style_note(
        &rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        subject_candidates,
        constraint_pressure,
    );
    let pending_observation_candidates = preselected_candidates.unwrap_or_else(|| {
        select_pending_rejected_video_observation_candidates_for_subject_with_bias(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            subject_candidates,
            storyboard_row,
            rejected_video_memory_selection_bias(constraint_pressure),
        )
    });
    let mut candidate_sources = pending_observation_candidates
        .into_iter()
        .map(|note| (note, "pending_rejected_observation"))
        .collect::<Vec<_>>();
    candidate_sources.extend(
        patch_attribution_candidates
            .into_iter()
            .map(|note| (note, "patch_attribution")),
    );
    let compacted_candidates = candidate_sources
        .into_iter()
        .filter_map(|(note, source)| {
            compact_negative_constraint_against_storyboard_style(
                &note,
                prioritized_style_note.as_deref(),
                storyboard_row,
            )
            .map(|compacted| (compacted, source))
        })
        .filter(|(note, _)| {
            !video_prompt_observation_is_irrelevant_to_storyboard(note, storyboard_row)
        })
        .collect::<Vec<_>>();
    let selected = select_best_storyboard_observation_note(
        prune_storyboard_observation_candidates(
            compacted_candidates
                .iter()
                .map(|(note, _)| note.clone())
                .collect::<Vec<_>>(),
            storyboard_row,
        ),
        storyboard_row,
        constraint_pressure,
    )?;
    let source = compacted_candidates
        .into_iter()
        .find_map(|(note, source)| (note == selected).then_some(source))
        .unwrap_or("pending_observation_note");

    Some(PendingVideoObservationSelection {
        note: format!("待观察失败倾向：{selected}"),
        source,
    })
}

fn select_best_storyboard_observation_note(
    candidates: Vec<String>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    candidates.into_iter().max_by(|a, b| {
        score_storyboard_observation_note_candidate(a, storyboard_row, constraint_pressure)
            .cmp(&score_storyboard_observation_note_candidate(
                b,
                storyboard_row,
                constraint_pressure,
            ))
            .then(
                score_video_prompt_observation_specificity(a)
                    .cmp(&score_video_prompt_observation_specificity(b)),
            )
            .then(
                score_video_prompt_observation_quality(a)
                    .cmp(&score_video_prompt_observation_quality(b)),
            )
            .then(b.chars().count().cmp(&a.chars().count()))
            .then(b.cmp(a))
    })
}

fn score_storyboard_observation_note_candidate(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let mut score = 0;
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return score;
    };

    match observation_note_budget_family(note) {
        VideoPromptObservationFamily::Dialogue => {
            if storyboard_has_visible_speech_performance_risk(&fields, None)
                || current_storyboard_is_fragile_emotional_turn(&fields)
            {
                score += 24;
            }
            if constraint_pressure.is_some_and(|pressure| pressure.prefer_delivery_memory_recall) {
                score += 12;
            }
        }
        VideoPromptObservationFamily::Identity => {
            if video_prompt_scene_needs_identity_memory(&fields) {
                score += 10;
            }
        }
        VideoPromptObservationFamily::Lighting => {
            if video_prompt_scene_has_lighting_risk(&fields) {
                score += 10;
            }
        }
        VideoPromptObservationFamily::Motion => {
            if video_prompt_scene_has_motion_risk(&fields) {
                score += 10;
            }
        }
        VideoPromptObservationFamily::Blocking => {
            if video_prompt_scene_has_blocking_risk(&fields) {
                score += 10;
            }
        }
        VideoPromptObservationFamily::Emotion => {
            if video_prompt_scene_needs_emotional_memory(&fields) {
                score += 8;
            }
        }
        VideoPromptObservationFamily::Generic => {}
    }

    score
}

fn collect_patch_attribution_observation_candidates(
    rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let mut candidates = Vec::new();
    for row in rows
        .iter()
        .filter(|row| row.name.starts_with("patch_attribution:"))
    {
        let Ok(value) = serde_json::from_str::<serde_json::Value>(&row.content) else {
            continue;
        };
        let Some(category) = value.get("category").and_then(serde_json::Value::as_str) else {
            continue;
        };
        let candidate = match category {
            "emotion_error" | "prompt_expression_gap" => {
                Some("avoid blank expression or monotone delivery")
            }
            "camera_language_error" => Some("avoid extra shot changes or wrong framing"),
            "visual_continuity_error" => Some("avoid face drift or costume inconsistency"),
            _ => None,
        };
        let Some(candidate) = candidate else {
            continue;
        };
        if video_prompt_observation_is_irrelevant_to_storyboard(candidate, storyboard_row) {
            continue;
        }
        if candidates.iter().any(|existing| existing == candidate) {
            continue;
        }
        candidates.push(candidate.to_string());
    }
    candidates
}

pub(in crate::production::workbench::meta::generate) fn trim_video_prompt_observation_rows(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<AgentMemoryRow> {
    let mut rejection_candidates = Vec::new();
    let mut script_style_candidates = Vec::new();
    let mut script_role_style_candidates = Vec::new();
    let mut project_style_candidates = Vec::new();
    let mut project_role_style_candidates = Vec::new();
    let mut script_observation_summary_candidates = Vec::new();
    let mut script_role_observation_summary_candidates = Vec::new();
    let mut project_observation_summary_candidates = Vec::new();
    let mut project_role_observation_summary_candidates = Vec::new();

    for (idx, row) in rows.into_iter().enumerate() {
        match row.name.as_str() {
            "rejected_video_negative_memory" => rejection_candidates.push((idx, row)),
            "script_video_style_memory" | "selected_video_memory"
                if selected_memory_row_matches_subject_candidates(&row, subject_candidates) =>
            {
                script_style_candidates.push((idx, row))
            }
            "script_role_video_style_memory" => script_role_style_candidates.push((idx, row)),
            "project_video_style_memory" => project_style_candidates.push((idx, row)),
            "project_role_video_style_memory" => project_role_style_candidates.push((idx, row)),
            "script_video_observation_memory" => {
                script_observation_summary_candidates.push((idx, row))
            }
            "script_role_video_observation_memory" => {
                script_role_observation_summary_candidates.push((idx, row))
            }
            "project_video_observation_memory" => {
                project_observation_summary_candidates.push((idx, row))
            }
            "project_role_video_observation_memory" => {
                project_role_observation_summary_candidates.push((idx, row))
            }
            _ => {}
        }
    }

    let mut kept = std::collections::HashSet::new();
    for idx in prioritize_storyboard_memory_indices(
        &rejection_candidates,
        storyboard_numeric_id,
        current_prompt_seed,
        VIDEO_PROMPT_OBSERVATION_REJECTION_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }
    for idx in prioritize_storyboard_memory_indices(
        &script_style_candidates,
        storyboard_numeric_id,
        current_prompt_seed,
        VIDEO_PROMPT_OBSERVATION_SCRIPT_STYLE_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }
    if should_keep_project_style_summary_rows(
        &script_style_candidates,
        &script_role_style_candidates,
        &project_style_candidates,
        subject_candidates,
        storyboard_row,
        None,
    ) {
        for (idx, _) in project_style_candidates
            .iter()
            .take(VIDEO_PROMPT_OBSERVATION_PROJECT_STYLE_ROW_LIMIT)
        {
            kept.insert(*idx);
        }
    }
    keep_prioritized_observation_summary_rows(
        &mut kept,
        &script_observation_summary_candidates,
        &project_observation_summary_candidates,
        &script_role_observation_summary_candidates,
        &project_role_observation_summary_candidates,
        subject_candidates,
        storyboard_row,
    );
    keep_matching_role_observation_rows(
        &mut kept,
        &script_role_style_candidates,
        &project_role_style_candidates,
        subject_candidates,
    );

    let mut all_rows = rejection_candidates;
    all_rows.extend(script_style_candidates);
    all_rows.extend(script_role_style_candidates);
    all_rows.extend(project_style_candidates);
    all_rows.extend(project_role_style_candidates);
    all_rows.extend(script_observation_summary_candidates);
    all_rows.extend(script_role_observation_summary_candidates);
    all_rows.extend(project_observation_summary_candidates);
    all_rows.extend(project_role_observation_summary_candidates);
    all_rows.sort_by_key(|(idx, _)| *idx);
    all_rows
        .into_iter()
        .filter_map(|(idx, row)| kept.contains(&idx).then_some(row))
        .collect()
}
