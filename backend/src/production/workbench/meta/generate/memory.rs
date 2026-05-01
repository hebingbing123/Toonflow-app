//! Memory selection, trimming, and observation handling for prompt generation.

use super::*;
use crate::production::workbench::video_prompt_memory::{
    select_pending_rejected_video_observation_candidates_for_subject_with_bias,
    VideoPromptMemorySelectionBias,
};

fn rejected_video_memory_selection_bias(
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
pub(super) async fn load_video_prompt_memory_notes(
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
pub(super) fn build_video_prompt_memory_notes(
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

pub(super) fn build_video_prompt_memory_notes_with_pressure(
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
    (
        style_notes.into_iter().collect(),
        select_video_prompt_memory_notes(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            Some(storyboard_row),
        ),
    )
}

pub(super) fn select_video_prompt_style_notes(
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
    let role_memory_notes = select_subject_role_video_style_memory_notes_for_storyboard(
        rows,
        &current_subject_candidates,
        Some(storyboard_row),
    )
    .into_iter()
    .filter_map(|note| compact_contextual_video_style_note(&note, Some(storyboard_row)))
    .take(1)
    .collect::<Vec<_>>();
    let exact = select_selected_video_memory_notes_for_storyboard(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        Some(storyboard_row),
    )
    .into_iter()
    .filter_map(|note| compact_neighbor_video_style_note(&note, Some(storyboard_row)))
    .collect::<Vec<_>>();
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
    .filter_map(|note| compact_neighbor_video_style_note(&note, Some(storyboard_row)))
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
    if !prioritized.is_empty() {
        return prioritized;
    }
    if !summary.is_empty() {
        return summary;
    }
    neighbor
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

    rows.iter()
        .filter(|row| allowed_names.contains(&row.name.as_str()))
        .filter_map(|row| {
            let note = contextual_style_memory_value_for_storyboard(row, Some(storyboard_row))
                .or_else(|| extract_key_value(&row.content, "style"))
                .or_else(|| extract_key_value(&row.content, "note"))?;
            let compacted =
                compact_guardrail_sensitive_style_note(&note, storyboard_row, constraint_pressure)
                    .or_else(|| compact_contextual_video_style_note(&note, Some(storyboard_row)))?;
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
            let brief_priority = i32::from(row.name.contains("generation_brief"));
            Some((
                score,
                evidence,
                brief_priority,
                compacted.chars().count(),
                compacted,
            ))
        })
        .max_by(|left, right| {
            left.0
                .cmp(&right.0)
                .then(left.1.cmp(&right.1))
                .then(left.2.cmp(&right.2))
                .then_with(|| right.3.cmp(&left.3))
                .then_with(|| right.4.cmp(&left.4))
        })
        .map(|(_, _, _, _, note)| note)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub(super) enum PressureStyleCandidateSource {
    Neighbor,
    Summary,
    Prioritized,
    Role,
    Exact,
}

pub(super) fn select_pressure_prioritized_style_note_candidate(
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
        let compacted =
            compact_guardrail_sensitive_style_note(note, storyboard_row, Some(pressure))
                .or_else(|| compact_contextual_video_style_note(note, Some(storyboard_row)));
        let Some(compacted) = compacted else {
            return;
        };
        let score =
            score_compacted_style_note_against_constraint_pressure(&compacted, &fields, pressure)
                + match source {
                    PressureStyleCandidateSource::Exact => 2,
                    PressureStyleCandidateSource::Role => 1,
                    PressureStyleCandidateSource::Prioritized => 0,
                    PressureStyleCandidateSource::Summary => 0,
                    PressureStyleCandidateSource::Neighbor => -1,
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

pub(super) fn compact_guardrail_sensitive_style_notes(
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

pub(super) fn compact_guardrail_sensitive_style_note(
    note: &str,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let Some(pressure) = constraint_pressure
        .filter(|pressure| pressure.forces_compact_memory && pressure.has_active_guardrail())
    else {
        return Some(note.to_string());
    };
    let Some(fields) = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    else {
        return Some(note.to_string());
    };
    let note = compact_contextual_video_style_note(note, Some(storyboard_row))?;
    let fragments = split_prompt_note_fragments(&note).collect::<Vec<_>>();
    if fragments.is_empty() {
        return Some(note);
    }

    let compacted =
        select_best_memory_style_note_for_lean_tier(&fragments, Some(&fields), Some(pressure))
            .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS))
            .unwrap_or(note);

    Some(compacted)
}

pub(super) fn exact_style_notes_should_yield_to_role_memory(
    exact_notes: &[String],
    role_memory_notes: &[String],
) -> bool {
    !role_memory_notes.is_empty()
        && !exact_notes.is_empty()
        && exact_notes
            .iter()
            .all(|note| exact_style_note_is_low_signal_template(note))
}

pub(super) fn exact_style_note_is_low_signal_template(note: &str) -> bool {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    !fragments.is_empty()
        && fragments
            .iter()
            .all(|fragment| low_signal_template_style_fragment(fragment))
}

pub(super) fn low_signal_template_style_fragment(fragment: &str) -> bool {
    low_signal_local_camera_style_fragment(fragment)
        || (fragment.starts_with("动作") && generic_motion_style_fragment(fragment))
}

pub(super) fn low_signal_local_camera_style_fragment(fragment: &str) -> bool {
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

pub(super) fn merge_exact_and_role_style_notes_for_high_value_scene(
    exact_notes: &[String],
    role_memory_notes: &[String],
    storyboard_row: &StoryboardPromptSeedRow,
) -> Option<String> {
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    if !video_prompt_scene_needs_emotional_memory(&fields)
        && !video_prompt_scene_needs_identity_memory(&fields)
    {
        return None;
    }

    exact_notes.iter().find_map(|exact_note| {
        role_memory_notes
            .iter()
            .find_map(|role_note| merge_complementary_style_note_pair(exact_note, role_note))
    })
}

pub(super) fn video_prompt_scene_needs_identity_memory(
    fields: &StructuredStoryboardDescription,
) -> bool {
    if normalize_prompt_text(&fields.subject).is_empty() {
        return false;
    }

    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "近景",
                "中近景",
                "半身",
                "特写",
                "close-up",
                "medium close-up",
                "portrait",
                "face",
                "面部",
                "脸部",
                "眼神",
                "目光",
                "凝视",
                "对视",
                "抬眼",
                "回头",
                "唇",
                "喉结",
                "眉",
                "泪",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(super) fn prefer_role_memory_only_for_silent_identity_scene(
    exact_notes: &[String],
    role_memory_notes: &[String],
    storyboard_row: &StoryboardPromptSeedRow,
) -> Option<String> {
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    if !video_prompt_scene_needs_identity_memory(&fields)
        || !storyboard_dialogue_is_empty(&fields.dialogue)
    {
        return None;
    }
    if !exact_notes
        .iter()
        .all(|note| exact_style_note_is_low_gain_identity_carryover(note))
    {
        return None;
    }

    role_memory_notes
        .iter()
        .find_map(|note| role_style_note_has_visible_micro_performance(note).then(|| note.clone()))
}

pub(super) fn exact_style_note_is_low_gain_identity_carryover(note: &str) -> bool {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    !fragments.is_empty()
        && fragments.iter().all(|fragment| {
            matches!(
                style_note_fragment_family(fragment),
                Some("镜头") | Some("光影") | Some("环境") | Some("声场")
            )
        })
}

pub(super) fn role_style_note_has_visible_micro_performance(note: &str) -> bool {
    split_prompt_note_fragments(note).any(|fragment| {
        fragment.starts_with("表演")
            && (score_memory_fragment_human_performance_detail(&fragment, Some("表演")) >= 3
                || ["眼神", "目光", "抬眼", "眉", "唇", "喉结"]
                    .iter()
                    .any(|keyword| fragment.contains(keyword)))
    })
}

pub(super) fn merge_complementary_style_note_pair(
    exact_note: &str,
    role_note: &str,
) -> Option<String> {
    let mut merged_fragments = split_prompt_note_fragments(exact_note).collect::<Vec<_>>();
    if merged_fragments.is_empty() {
        return None;
    }

    let mut added_role_signal = false;
    for fragment in split_prompt_note_fragments(role_note) {
        if !role_memory_fragment_is_high_value(fragment.as_str()) {
            continue;
        }
        if merged_fragments
            .iter()
            .any(|existing| style_note_fragment_conflicts_or_overlaps(existing, &fragment))
        {
            continue;
        }
        merged_fragments.push(fragment);
        added_role_signal = true;
    }

    if !added_role_signal {
        return None;
    }

    let merged = compact_video_style_prompt_note(&merged_fragments.join("，"))?;
    let exact = compact_video_style_prompt_note(exact_note)?;
    let merged_score = merged_style_note_signal_score(&merged);
    let exact_score = merged_style_note_signal_score(&exact);
    (merged != exact && merged_score > exact_score).then_some(merged)
}

pub(super) fn role_memory_fragment_is_high_value(fragment: &str) -> bool {
    fragment.starts_with("表演")
        || fragment.starts_with("语气")
        || (fragment.starts_with("动作")
            && ["克制", "迟疑", "停顿", "轻缓", "自然", "优雅"]
                .iter()
                .any(|keyword| fragment.contains(keyword)))
}

pub(super) fn style_note_fragment_conflicts_or_overlaps(existing: &str, candidate: &str) -> bool {
    if existing == candidate {
        return true;
    }

    let existing_family = style_note_fragment_family(existing);
    let candidate_family = style_note_fragment_family(candidate);
    if existing_family.is_some() && existing_family == candidate_family {
        return true;
    }

    existing.contains(candidate) || candidate.contains(existing)
}

pub(super) fn style_note_fragment_family(fragment: &str) -> Option<&'static str> {
    [
        "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
    ]
    .into_iter()
    .find(|prefix| fragment.starts_with(*prefix))
}

pub(super) fn merged_style_note_signal_score(note: &str) -> usize {
    split_prompt_note_fragments(note)
        .map(|fragment| match style_note_fragment_family(&fragment) {
            Some("表演") | Some("语气") => 3,
            Some("情绪") | Some("光影") => 2,
            Some("镜头") | Some("动作") | Some("环境") | Some("声场") => 1,
            _ => 0,
        })
        .sum()
}

pub(super) fn is_local_framing_only_fragment(fragment: &str) -> bool {
    matches!(
        fragment,
        "镜头近景" | "镜头中景" | "镜头远景" | "镜头特写" | "镜头全景"
    )
}

pub(super) fn collect_neighbor_video_prompt_style_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_subject_candidates: &[String],
) -> Vec<String> {
    let mut scored = rows
        .iter()
        .enumerate()
        .filter(|(_, row)| row.name == "selected_video_memory")
        .filter_map(|(idx, row)| {
            let storyboard_ids = extract_storyboard_ids_from_memory_content(&row.content);
            if storyboard_ids.is_empty() || storyboard_ids.contains(&storyboard_numeric_id) {
                return None;
            }
            let subject_match =
                memory_content_matches_subject_candidates(&row.content, current_subject_candidates);
            let has_explicit_subject = memory_content_has_subject_identity(&row.content);
            if has_explicit_subject && !current_subject_candidates.is_empty() && !subject_match {
                return None;
            }
            let distance = storyboard_ids
                .iter()
                .map(|id| (storyboard_numeric_id - *id).abs())
                .min()?;
            let note = extract_key_value(&row.content, "style")
                .or_else(|| extract_key_value(&row.content, "note"))?;
            Some((!subject_match, distance, idx, note))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        a.0.cmp(&b.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.cmp(&b.2))
            .then(a.3.cmp(&b.3))
    });

    let mut notes = Vec::new();
    for (_, _, _, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= 2 {
            break;
        }
    }
    notes
}

pub(super) fn memory_content_has_subject_identity(content: &str) -> bool {
    extract_key_value(content, "subject").is_some()
        || extract_key_value(content, "subjectAliases").is_some()
}

pub(super) fn memory_content_matches_subject_candidates(
    content: &str,
    subject_candidates: &[String],
) -> bool {
    if subject_candidates.is_empty() {
        return false;
    }

    let memory_subjects = extract_key_value(content, "subject")
        .into_iter()
        .chain(
            extract_key_value(content, "subjectAliases")
                .into_iter()
                .flat_map(|value| {
                    value
                        .split('/')
                        .map(normalize_prompt_text)
                        .filter(|alias| !alias.is_empty())
                        .collect::<Vec<_>>()
                }),
        )
        .collect::<Vec<_>>();
    !memory_subjects.is_empty()
        && memory_subjects.iter().any(|memory_subject| {
            subject_candidates.iter().any(|candidate| {
                candidate == memory_subject
                    || candidate.contains(memory_subject)
                    || memory_subject.contains(candidate)
            })
        })
}

pub(super) fn extract_storyboard_ids_from_memory_content(content: &str) -> Vec<i32> {
    extract_key_value(content, "storyboardIds")
        .map(|raw| {
            raw.split(',')
                .filter_map(|part| part.trim().parse::<i32>().ok())
                .filter(|id| *id > 0)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

#[allow(dead_code)]
pub(super) fn trim_video_prompt_memory_rows(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
) -> Vec<AgentMemoryRow> {
    trim_video_prompt_memory_rows_with_context(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        None,
        None,
    )
}

pub(super) fn trim_video_prompt_memory_rows_with_context(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Vec<AgentMemoryRow> {
    let mut selected_candidates = Vec::new();
    let mut auto_scope_candidates = Vec::new();
    let mut script_style_candidates = Vec::new();
    let mut script_role_style_candidates = Vec::new();
    let mut project_style_candidates = Vec::new();
    let mut project_role_style_candidates = Vec::new();

    for (idx, row) in rows.into_iter().enumerate() {
        match row.name.as_str() {
            "selected_video_memory" => {
                if selected_memory_row_matches_subject_candidates(&row, subject_candidates) {
                    selected_candidates.push((idx, row))
                }
            }
            "auto_scope_memory" => auto_scope_candidates.push((idx, row)),
            "script_video_style_memory" => script_style_candidates.push((idx, row)),
            "script_role_video_style_memory" => script_role_style_candidates.push((idx, row)),
            "project_video_style_memory" => project_style_candidates.push((idx, row)),
            "project_role_video_style_memory" => project_role_style_candidates.push((idx, row)),
            _ => {}
        }
    }

    let mut kept = std::collections::HashSet::new();
    for idx in prioritize_storyboard_memory_indices_with_context(
        &selected_candidates,
        storyboard_numeric_id,
        current_prompt_seed,
        VIDEO_PROMPT_SELECTED_MEMORY_ROW_LIMIT,
        storyboard_row,
        constraint_pressure,
    ) {
        kept.insert(idx);
    }
    for idx in prioritize_storyboard_memory_indices_with_context(
        &auto_scope_candidates,
        storyboard_numeric_id,
        current_prompt_seed,
        VIDEO_PROMPT_AUTO_SCOPE_MEMORY_ROW_LIMIT,
        storyboard_row,
        constraint_pressure,
    ) {
        kept.insert(idx);
    }
    for (idx, _) in script_style_candidates
        .iter()
        .take(VIDEO_PROMPT_SCRIPT_STYLE_MEMORY_ROW_LIMIT)
    {
        kept.insert(*idx);
    }
    if should_keep_project_style_summary_rows(
        &script_style_candidates,
        &script_role_style_candidates,
        &project_style_candidates,
        subject_candidates,
        storyboard_row,
        constraint_pressure,
    ) {
        for (idx, _) in project_style_candidates
            .iter()
            .take(VIDEO_PROMPT_PROJECT_STYLE_MEMORY_ROW_LIMIT)
        {
            kept.insert(*idx);
        }
    }
    keep_matching_role_style_rows(
        &mut kept,
        &script_role_style_candidates,
        &project_role_style_candidates,
        subject_candidates,
        VIDEO_PROMPT_ROLE_STYLE_MEMORY_ROW_LIMIT,
    );

    let mut all_rows = selected_candidates;
    all_rows.extend(auto_scope_candidates);
    all_rows.extend(script_style_candidates);
    all_rows.extend(script_role_style_candidates);
    all_rows.extend(project_style_candidates);
    all_rows.extend(project_role_style_candidates);
    all_rows.sort_by_key(|(idx, _)| *idx);
    all_rows
        .into_iter()
        .filter_map(|(idx, row)| kept.contains(&idx).then_some(row))
        .collect()
}

pub(super) fn keep_matching_role_style_rows(
    kept: &mut std::collections::HashSet<usize>,
    script_candidates: &[(usize, AgentMemoryRow)],
    project_candidates: &[(usize, AgentMemoryRow)],
    subject_candidates: &[String],
    row_limit: usize,
) {
    let matching_indices = [script_candidates, project_candidates]
        .into_iter()
        .flat_map(|candidates| candidates.iter())
        .filter(|(_, row)| {
            memory_content_matches_subject_candidates(&row.content, subject_candidates)
        })
        .map(|(idx, _)| *idx)
        .take(row_limit)
        .collect::<Vec<_>>();
    if !matching_indices.is_empty() {
        for idx in matching_indices {
            kept.insert(idx);
        }
        return;
    }

    for (idx, _) in script_candidates
        .iter()
        .chain(project_candidates.iter())
        .take(row_limit)
    {
        kept.insert(*idx);
    }
}

pub(super) fn selected_memory_row_matches_subject_candidates(
    row: &AgentMemoryRow,
    subject_candidates: &[String],
) -> bool {
    if row.name != "selected_video_memory" {
        return true;
    }
    let has_explicit_subject = memory_content_has_subject_identity(&row.content);
    if !has_explicit_subject || subject_candidates.is_empty() {
        return true;
    }
    memory_content_matches_subject_candidates(&row.content, subject_candidates)
}

pub(super) fn prioritize_storyboard_memory_indices(
    rows: &[(usize, AgentMemoryRow)],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    limit: usize,
) -> Vec<usize> {
    prioritize_storyboard_memory_indices_with_context(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        limit,
        None,
        None,
    )
}

pub(super) fn prioritize_storyboard_memory_indices_with_context(
    rows: &[(usize, AgentMemoryRow)],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    limit: usize,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Vec<usize> {
    let mut scored = rows
        .iter()
        .map(|(idx, row)| {
            let storyboard_ids = extract_storyboard_ids_from_memory_content(&row.content);
            let exact_storyboard_match =
                storyboard_numeric_id > 0 && storyboard_ids.contains(&storyboard_numeric_id);
            let prompt_seed_match = memory_prompt_seed_matches(
                &row.content,
                storyboard_numeric_id,
                current_prompt_seed,
            );
            let prompt_seed_present =
                memory_prompt_seed_for_storyboard(&row.content, storyboard_numeric_id).is_some();
            let storyboard_distance =
                storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                    .unwrap_or(i32::MAX);
            let trim_quality =
                storyboard_memory_trim_quality_score(row, storyboard_row, constraint_pressure);
            (
                *idx,
                exact_storyboard_match,
                prompt_seed_match,
                prompt_seed_present,
                trim_quality,
                storyboard_distance,
            )
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then(b.2.cmp(&a.2))
            .then(a.3.cmp(&b.3))
            .then(b.4.cmp(&a.4))
            .then(a.5.cmp(&b.5))
            .then(a.0.cmp(&b.0))
    });
    scored
        .into_iter()
        .take(limit)
        .map(|(idx, _, _, _, _, _)| idx)
        .collect()
}

fn storyboard_memory_trim_quality_score(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    if row.name != "selected_video_memory" {
        return 0;
    }

    let should_prefer_delivery =
        storyboard_trim_prefers_delivery_memory(storyboard_row, constraint_pressure);
    let should_prefer_visual_continuity =
        storyboard_trim_prefers_visual_continuity_memory(constraint_pressure);
    let style = extract_key_value(&row.content, "style")
        .or_else(|| extract_key_value(&row.content, "note"))
        .unwrap_or_default();
    let fragments = split_prompt_note_fragments(&style).collect::<Vec<_>>();
    let mut score = 0;
    let has_delivery = extract_key_value(&row.content, "delivery")
        .is_some_and(|value| !normalize_prompt_text(&value).is_empty());
    let has_performance = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演") || fragment.starts_with("语气"));
    let has_emotion = fragments
        .iter()
        .any(|fragment| fragment.starts_with("情绪"));
    let has_identity = selected_memory_content_has_identity_anchor(&row.content, &fragments);
    let has_lighting = selected_memory_fragments_have_visual_continuity_anchor(&fragments);
    let visual_only = !fragments.is_empty()
        && fragments.iter().all(|fragment| {
            fragment.starts_with("镜头")
                || fragment.starts_with("光影")
                || fragment.starts_with("环境")
                || fragment.starts_with("动作")
                || fragment.starts_with("声场")
        });
    let local_framing_only = !fragments.is_empty()
        && fragments.iter().all(|fragment| {
            fragment.starts_with("镜头")
                && matches!(
                    normalize_prompt_text(fragment).as_str(),
                    "镜头近景" | "镜头中景" | "镜头远景" | "镜头特写" | "镜头全景"
                )
        });

    if has_delivery {
        score += 12;
    }
    if has_performance {
        score += 10;
    }
    if has_emotion {
        score += 6;
    }
    if has_identity {
        score += 6;
    }
    if has_lighting {
        score += 6;
    }
    if should_prefer_delivery {
        if has_delivery {
            score += 26;
        }
        if has_performance {
            score += 18;
        }
        if has_emotion {
            score += 10;
        }
        if visual_only {
            score -= 18;
        }
        if local_framing_only {
            score -= 14;
        }
    }
    if should_prefer_visual_continuity {
        if has_identity {
            score += 24;
        }
        if has_lighting {
            score += 22;
        }
        if visual_only && !has_identity && !has_lighting {
            score -= 10;
        }
        if local_framing_only && !has_identity && !has_lighting {
            score -= 12;
        }
    } else if constraint_pressure.is_some_and(|pressure| pressure.forces_compact_memory) {
        if visual_only {
            score -= 8;
        }
        if local_framing_only {
            score -= 8;
        }
    }

    score
}

fn storyboard_trim_prefers_delivery_memory(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    if constraint_pressure.is_some_and(|pressure| {
        pressure.prefer_delivery_memory_recall
            || pressure.has_dialogue_guardrail
            || pressure.has_emotion_guardrail
            || pressure.has_identity_guardrail
    }) {
        return true;
    }

    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return false;
    };
    let dialogue = normalize_prompt_text(&fields.dialogue);
    if !dialogue.is_empty() && dialogue != "无台词" {
        return true;
    }

    let expressive_context = [
        normalize_prompt_text(&fields.action),
        normalize_prompt_text(&fields.mood),
    ]
    .join(" ");
    [
        "停顿", "抬眼", "垂眼", "低声", "轻声", "哽咽", "克制", "压抑", "悲", "紧张", "发颤",
    ]
    .iter()
    .any(|keyword| expressive_context.contains(keyword))
}

fn storyboard_trim_prefers_visual_continuity_memory(
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    constraint_pressure.is_some_and(|pressure| {
        pressure.prefer_visual_continuity_memory_recall
            || pressure.has_identity_guardrail
            || pressure.has_lighting_guardrail
    })
}

fn selected_memory_content_has_identity_anchor(content: &str, fragments: &[String]) -> bool {
    extract_key_value(content, "subject")
        .is_some_and(|value| !normalize_prompt_text(&value).is_empty())
        || extract_key_value(content, "subjectAliases")
            .is_some_and(|value| !normalize_prompt_text(&value).is_empty())
        || fragments.iter().any(|fragment| {
            fragment.starts_with("表演")
                && [
                    "眼神", "抬眼", "回头", "面部", "脸", "喉结", "唇", "眉", "泪",
                ]
                .iter()
                .any(|keyword| fragment.contains(keyword))
        })
}

fn selected_memory_fragments_have_visual_continuity_anchor(fragments: &[String]) -> bool {
    fragments.iter().any(|fragment| {
        fragment.starts_with("光影")
            || fragment.starts_with("环境")
            || fragment.starts_with("声场")
            || (fragment.starts_with("镜头")
                && [
                    "逆光",
                    "反光",
                    "低机位",
                    "压迫",
                    "跟拍",
                    "推进",
                    "拉远",
                    "摇镜",
                    "霓虹",
                ]
                .iter()
                .any(|keyword| fragment.contains(keyword)))
    })
}

pub(super) fn memory_prompt_seed_matches(
    content: &str,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> bool {
    match current_prompt_seed {
        Some(seed) if !seed.is_empty() => {
            memory_prompt_seed_for_storyboard(content, storyboard_numeric_id).as_deref()
                == Some(seed)
        }
        _ => false,
    }
}

pub(super) fn memory_prompt_seed_for_storyboard(
    content: &str,
    storyboard_numeric_id: i32,
) -> Option<String> {
    if let Some(prompt_seed) =
        extract_key_value(content, "promptSeed").filter(|seed| !seed.is_empty())
    {
        return Some(prompt_seed);
    }
    if storyboard_numeric_id <= 0 {
        return None;
    }
    extract_key_value(content, "storyboardPromptSeeds").and_then(|mapping| {
        mapping.split(',').find_map(|entry| {
            let (raw_storyboard_id, prompt_seed) = entry.split_once(':')?;
            let entry_storyboard_id = raw_storyboard_id.trim().parse::<i32>().ok()?;
            (entry_storyboard_id == storyboard_numeric_id)
                .then(|| prompt_seed.trim().to_string())
                .filter(|seed| !seed.is_empty())
        })
    })
}

pub(super) fn storyboard_distance_from_memory_content(
    content: &str,
    storyboard_numeric_id: i32,
) -> Option<i32> {
    if storyboard_numeric_id <= 0 {
        return None;
    }
    extract_storyboard_ids_from_memory_content(content)
        .into_iter()
        .map(|id| (storyboard_numeric_id - id).abs())
        .min()
}

pub(super) struct PendingVideoObservationSelection {
    pub(super) note: String,
    pub(super) source: &'static str,
}

#[allow(dead_code)]
pub(super) fn build_pending_video_observation_note_from_runtime(
    runtime: &StoryboardNegativePromptRuntime,
) -> Option<String> {
    build_pending_video_observation_selection_from_runtime(runtime).map(|selection| selection.note)
}

pub(super) fn build_pending_video_observation_selection_from_runtime(
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
pub(super) fn build_pending_video_observation_note(
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

pub(super) fn build_pending_video_observation_selection(
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

pub(super) fn trim_video_prompt_observation_rows(
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
            "script_video_style_memory" | "selected_video_memory" => {
                if selected_memory_row_matches_subject_candidates(&row, subject_candidates) {
                    script_style_candidates.push((idx, row))
                }
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

fn should_keep_project_style_summary_rows(
    script_style_candidates: &[(usize, AgentMemoryRow)],
    script_role_style_candidates: &[(usize, AgentMemoryRow)],
    project_style_candidates: &[(usize, AgentMemoryRow)],
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    if project_style_candidates.is_empty() {
        return false;
    }

    let Some(storyboard_row) = storyboard_row else {
        return true;
    };
    let Some(fields) = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    else {
        return true;
    };
    let pressure = constraint_pressure.unwrap_or_default();
    if pressure.prefer_visual_continuity_memory_recall || pressure.has_lighting_guardrail {
        return true;
    }

    let scene_prefers_precise_subject_memory = (!subject_candidates.is_empty()
        && video_prompt_scene_needs_identity_memory(&fields))
        || video_prompt_scene_needs_emotional_memory(&fields)
        || storyboard_has_visible_speech_performance_risk(
            &fields,
            storyboard_row.prompt.as_deref(),
        )
        || pressure.prefer_delivery_memory_recall
        || pressure.has_dialogue_guardrail
        || pressure.has_emotion_guardrail
        || pressure.has_identity_guardrail;
    if !scene_prefers_precise_subject_memory {
        return true;
    }
    if constraint_pressure.is_none() && !script_role_style_candidates.is_empty() {
        return project_style_candidates
            .iter()
            .any(|(_, row)| project_style_note_carries_continuity_specific_visual_risk(row));
    }
    if !script_role_style_candidates.is_empty()
        && project_style_candidates.iter().all(|(_, row)| {
            project_style_note_is_low_gain_global_fill(row, &fields, Some(pressure))
        })
    {
        return false;
    }

    let best_script_locked_score = script_style_candidates
        .iter()
        .chain(script_role_style_candidates.iter())
        .filter_map(|(_, row)| {
            project_style_memory_trim_note_score(
                row,
                storyboard_row,
                Some(pressure),
                subject_candidates,
            )
        })
        .max()
        .unwrap_or(i32::MIN);
    if best_script_locked_score < 18 {
        return true;
    }

    let project_scores = project_style_candidates
        .iter()
        .filter_map(|(_, row)| {
            project_style_memory_trim_note_score(
                row,
                storyboard_row,
                Some(pressure),
                subject_candidates,
            )
            .map(|score| (score, row))
        })
        .collect::<Vec<_>>();
    if project_scores.is_empty() {
        return false;
    }
    if project_scores.iter().any(|(score, row)| {
        *score + 4 >= best_script_locked_score
            && !project_style_note_is_low_gain_global_fill(row, &fields, Some(pressure))
    }) {
        return true;
    }

    project_scores
        .iter()
        .any(|(_, row)| !project_style_note_is_low_gain_global_fill(row, &fields, Some(pressure)))
}

fn project_style_note_carries_continuity_specific_visual_risk(row: &AgentMemoryRow) -> bool {
    let note = extract_key_value(&row.content, "style")
        .or_else(|| extract_key_value(&row.content, "note"));
    let Some(note) = note else {
        return false;
    };
    let normalized = normalize_prompt_text(&note);
    [
        "霓虹反光",
        "反光",
        "反射",
        "潮湿",
        "地面反射",
        "逆光",
        "剪影",
        "构图",
        "走位",
        "方向",
        "轴线",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

fn project_style_memory_trim_note_score(
    row: &AgentMemoryRow,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
    subject_candidates: &[String],
) -> Option<i32> {
    if row.name == "project_role_video_style_memory"
        && !subject_candidates.is_empty()
        && !memory_content_matches_subject_candidates(&row.content, subject_candidates)
    {
        return None;
    }

    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let note = contextual_style_memory_value_for_storyboard(row, Some(storyboard_row))
        .or_else(|| extract_key_value(&row.content, "style"))
        .or_else(|| extract_key_value(&row.content, "note"))?;
    let compacted =
        compact_guardrail_sensitive_style_note(&note, storyboard_row, constraint_pressure)
            .or_else(|| compact_contextual_video_style_note(&note, Some(storyboard_row)))?;

    Some(score_compacted_style_note_against_constraint_pressure(
        &compacted,
        &fields,
        constraint_pressure.unwrap_or_default(),
    ))
}

fn project_style_note_is_low_gain_global_fill(
    row: &AgentMemoryRow,
    fields: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: None,
        video_desc: None,
        duration: None,
    };
    let note = extract_key_value(&row.content, "style")
        .or_else(|| extract_key_value(&row.content, "note"));
    let Some(note) = note else {
        return true;
    };
    let compacted =
        compact_guardrail_sensitive_style_note(&note, &storyboard_row, constraint_pressure)
            .or_else(|| compact_video_style_prompt_note(&note))
            .unwrap_or(note);
    let fragments = split_prompt_note_fragments(&compacted).collect::<Vec<_>>();
    if fragments.is_empty() {
        return true;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            || fragment
                .strip_prefix("语气")
                .map(normalize_prompt_text)
                .is_some_and(|voice| memory_fragment_has_high_signal_voice_detail(&voice))
    }) {
        return false;
    }

    let generic_visual_fill = fragments.iter().all(|fragment| {
        matches!(
            style_note_fragment_family(fragment),
            Some("镜头") | Some("情绪") | Some("光影") | Some("动作") | Some("环境") | Some("声场")
        )
    });
    if !generic_visual_fill {
        return false;
    }
    if fragments
        .iter()
        .all(|fragment| storyboard_style_already_covers_project_fill_fragment(fragment, fields))
    {
        return true;
    }

    let total_score = fragments
        .iter()
        .map(|fragment| {
            score_memory_style_fragment_for_lean_tier(fragment, Some(fields), constraint_pressure)
        })
        .sum::<i32>();
    total_score <= 18
}

fn storyboard_style_already_covers_project_fill_fragment(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    let normalized_fragment = normalize_prompt_text(fragment);
    if normalized_fragment.is_empty() {
        return true;
    }

    let family = style_note_fragment_family(&normalized_fragment);
    let core = family
        .and_then(|prefix| normalized_fragment.strip_prefix(prefix))
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| normalized_fragment.clone());

    let coverage_fields = match family {
        Some("镜头") => vec![
            fields.shot.as_str(),
            fields.camera_move.as_str(),
            fields.action.as_str(),
        ],
        Some("情绪") => vec![
            fields.mood.as_str(),
            fields.action.as_str(),
            fields.dialogue.as_str(),
        ],
        Some("光影") => vec![fields.lighting.as_str(), fields.setting.as_str()],
        Some("动作") => vec![fields.action.as_str(), fields.camera_move.as_str()],
        Some("环境") => vec![fields.setting.as_str(), fields.sound.as_str()],
        Some("声场") => vec![fields.sound.as_str(), fields.dialogue.as_str()],
        _ => vec![
            fields.shot.as_str(),
            fields.camera_move.as_str(),
            fields.mood.as_str(),
            fields.lighting.as_str(),
            fields.setting.as_str(),
            fields.action.as_str(),
            fields.sound.as_str(),
        ],
    };

    coverage_fields.into_iter().any(|field| {
        let normalized_field = normalize_prompt_text(field);
        !normalized_field.is_empty()
            && (normalized_field.contains(&core)
                || core.contains(&normalized_field)
                || shared_style_keyword(&normalized_field, &core))
    })
}

fn shared_style_keyword(left: &str, right: &str) -> bool {
    [
        "稳定跟拍",
        "手持跟拍",
        "慢推",
        "推进",
        "拉远",
        "压抑",
        "克制",
        "冷蓝窗光",
        "冷调逆光",
        "霓虹反光",
        "雨声",
        "回响",
        "潮湿",
    ]
    .iter()
    .any(|keyword| left.contains(keyword) && right.contains(keyword))
}

pub(super) fn keep_prioritized_observation_summary_rows(
    kept: &mut std::collections::HashSet<usize>,
    script_candidates: &[(usize, AgentMemoryRow)],
    project_candidates: &[(usize, AgentMemoryRow)],
    script_role_candidates: &[(usize, AgentMemoryRow)],
    project_role_candidates: &[(usize, AgentMemoryRow)],
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) {
    for idx in prioritize_observation_summary_indices(
        script_candidates,
        storyboard_row,
        subject_candidates,
        VIDEO_PROMPT_OBSERVATION_SCRIPT_SUMMARY_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }
    for idx in prioritize_observation_summary_indices(
        project_candidates,
        storyboard_row,
        subject_candidates,
        VIDEO_PROMPT_OBSERVATION_PROJECT_SUMMARY_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }

    let role_candidates = script_role_candidates
        .iter()
        .chain(project_role_candidates.iter())
        .filter(|(_, row)| {
            observation_summary_row_matches_subject_candidates(row, subject_candidates)
        })
        .map(|(idx, row)| (*idx, row.clone()))
        .collect::<Vec<_>>();
    let prioritized_role = if role_candidates.is_empty() {
        script_role_candidates
            .iter()
            .chain(project_role_candidates.iter())
            .map(|(idx, row)| (*idx, row.clone()))
            .collect::<Vec<_>>()
    } else {
        role_candidates
    };
    let prioritized_role_refs = prioritized_role
        .iter()
        .map(|(idx, row)| (*idx, row.clone()))
        .collect::<Vec<_>>();
    for idx in prioritize_observation_summary_indices(
        prioritized_role_refs.as_slice(),
        storyboard_row,
        subject_candidates,
        VIDEO_PROMPT_OBSERVATION_ROLE_SUMMARY_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }
}

pub(super) fn prioritize_observation_summary_indices(
    rows: &[(usize, AgentMemoryRow)],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
    limit: usize,
) -> Vec<usize> {
    let storyboard_tags = storyboard_observation_summary_risk_tags(storyboard_row);
    let mut scored = rows
        .iter()
        .map(|(idx, row)| {
            (
                *idx,
                observation_summary_row_risk_overlap(&row.content, &storyboard_tags),
                memory_subject_match_priority(&row.content, subject_candidates),
                observation_summary_row_sample_count(&row.content),
            )
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then(a.2.cmp(&b.2))
            .then(b.3.cmp(&a.3))
            .then(a.0.cmp(&b.0))
    });
    scored
        .into_iter()
        .take(limit)
        .map(|(idx, _, _, _)| idx)
        .collect()
}

pub(super) fn observation_summary_row_matches_subject_candidates(
    row: &AgentMemoryRow,
    subject_candidates: &[String],
) -> bool {
    memory_subject_match_priority(&row.content, subject_candidates) != usize::MAX
}

pub(super) fn memory_subject_match_priority(content: &str, subject_candidates: &[String]) -> usize {
    if subject_candidates.is_empty() {
        return usize::MAX;
    }
    let memory_subjects = extract_key_value(content, "subjectAliases")
        .or_else(|| extract_key_value(content, "subject"))
        .map(|value| {
            value
                .split(['/', ',', '，', ';', '；'])
                .map(normalize_prompt_text)
                .filter(|item| !item.is_empty())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    if memory_subjects.is_empty() {
        return usize::MAX;
    }

    subject_candidates
        .iter()
        .enumerate()
        .find_map(|(idx, candidate)| {
            let candidate = normalize_prompt_text(candidate);
            memory_subjects
                .iter()
                .any(|memory_subject| {
                    candidate == *memory_subject
                        || candidate.contains(memory_subject)
                        || memory_subject.contains(&candidate)
                })
                .then_some(idx)
        })
        .unwrap_or(usize::MAX)
}

pub(super) fn observation_summary_row_sample_count(content: &str) -> usize {
    extract_key_value(content, "sampleCount")
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(0)
}

pub(super) fn observation_summary_row_risk_overlap(
    content: &str,
    storyboard_tags: &[&str],
) -> usize {
    if storyboard_tags.is_empty() {
        return 0;
    }
    extract_key_value(content, "riskTags")
        .map(|value| {
            value
                .split(['/', ',', '，', ';', '；'])
                .map(normalize_prompt_text)
                .filter(|tag| {
                    storyboard_tags
                        .iter()
                        .any(|storyboard_tag| tag == *storyboard_tag)
                })
                .count()
        })
        .unwrap_or(0)
}

pub(super) fn storyboard_observation_summary_risk_tags(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<&'static str> {
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return Vec::new();
    };

    let mut tags = Vec::new();
    if video_prompt_scene_needs_identity_memory(&fields) {
        tags.push("identity");
    }
    if !storyboard_dialogue_is_empty(&fields.dialogue) {
        tags.push("dialogue");
    }
    if video_prompt_scene_has_lighting_risk(&fields) {
        tags.push("lighting");
    }
    if video_prompt_scene_has_motion_risk(&fields) {
        tags.push("motion");
    }
    if current_storyboard_is_fragile_emotional_turn(&fields) {
        tags.push("emotion");
        tags.push("performance");
    }
    if video_prompt_scene_has_axis_risk(&fields) {
        tags.push("framing");
    }
    tags
}

pub(super) fn keep_matching_role_observation_rows(
    kept: &mut std::collections::HashSet<usize>,
    script_candidates: &[(usize, AgentMemoryRow)],
    project_candidates: &[(usize, AgentMemoryRow)],
    subject_candidates: &[String],
) {
    let matching_indices = [script_candidates, project_candidates]
        .into_iter()
        .flat_map(|candidates| candidates.iter())
        .filter(|(_, row)| {
            !select_subject_role_video_style_memory_notes(
                std::slice::from_ref(row),
                subject_candidates,
            )
            .is_empty()
        })
        .map(|(idx, _)| *idx)
        .take(VIDEO_PROMPT_OBSERVATION_ROLE_STYLE_ROW_LIMIT)
        .collect::<Vec<_>>();
    if !matching_indices.is_empty() {
        for idx in matching_indices {
            kept.insert(idx);
        }
        return;
    }

    for (idx, _) in script_candidates
        .iter()
        .chain(project_candidates.iter())
        .take(VIDEO_PROMPT_OBSERVATION_ROLE_STYLE_ROW_LIMIT)
    {
        kept.insert(*idx);
    }
}

pub(super) fn resolve_observation_filter_style_note(
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

pub(super) fn select_contextual_observation_summary_style_note(
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

pub(super) fn observation_summary_style_note_min_evidence(
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

pub(super) fn rank_observation_summary_style_note_fragments(
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

pub(super) fn observation_summary_style_note_score(
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

pub(super) fn observation_summary_style_fragment_score(
    fragment: &str,
    context: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let evidence = observation_style_note_context_evidence(fragment, context) as i32;
    score_memory_style_fragment_for_lean_tier(fragment, Some(context), constraint_pressure)
        + evidence * 12
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub(super) enum ObservationFilterStyleCandidateSource {
    Summary,
    Prioritized,
    Role,
}

pub(super) fn select_pressure_prioritized_observation_filter_style_note(
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

pub(super) fn observation_style_note_context_evidence(
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

pub(super) fn style_note_matches_shared_keyword_family(
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

pub(super) fn style_note_matches_mood_keyword(note: &str, mood: &str) -> bool {
    let normalized_mood = normalize_prompt_text(mood);
    !normalized_mood.is_empty()
        && ["克制", "隐忍", "压抑", "平静", "冷静", "从容", "沉静"]
            .iter()
            .any(|keyword| normalized_mood.contains(keyword) && note.contains(keyword))
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn video_prompt_observation_conflicts_with_style(
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

pub(super) fn video_prompt_observation_is_irrelevant_to_storyboard(
    observation_note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    canonical_observation_note(observation_note) == "avoid lip-sync mismatch"
        && storyboard_row.is_some_and(storyboard_lacks_visible_speech_performance_risk)
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn storyboard_dialogue_is_empty_row(row: &StoryboardPromptSeedRow) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| storyboard_dialogue_is_empty(&fields.dialogue))
}

pub(super) fn storyboard_dialogue_is_empty(dialogue: &str) -> bool {
    let normalized = normalize_prompt_text(dialogue);
    let normalized_ascii = normalized.to_ascii_lowercase();
    normalized.is_empty()
        || [
            "无台词",
            "无对白",
            "无旁白",
            "无语音",
            "no dialogue",
            "no voice-over",
            "silent",
        ]
        .iter()
        .map(|marker| normalize_prompt_text(marker).to_ascii_lowercase())
        .any(|marker| normalized_ascii == marker)
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn storyboard_lacks_meaningful_spoken_dialogue(row: &StoryboardPromptSeedRow) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_none_or(|fields| {
            !storyboard_has_meaningful_spoken_dialogue_with_prompt(&fields, row.prompt.as_deref())
        })
}

pub(super) fn storyboard_lacks_visible_speech_performance_risk(
    row: &StoryboardPromptSeedRow,
) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_none_or(|fields| {
            !storyboard_has_visible_speech_performance_risk(&fields, row.prompt.as_deref())
        })
}

pub(super) fn storyboard_has_meaningful_spoken_dialogue(
    fields: &StructuredStoryboardDescription,
) -> bool {
    storyboard_has_meaningful_spoken_dialogue_with_prompt(fields, None)
}

pub(super) fn storyboard_has_meaningful_spoken_dialogue_with_prompt(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
) -> bool {
    if storyboard_dialogue_is_empty(&fields.dialogue) {
        return false;
    }

    let dialogue = normalize_prompt_text(&fields.dialogue);
    let action = normalize_prompt_text(&fields.action);
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();

    if dialogue_fragment_is_low_gain_utterance(&dialogue)
        && !storyboard_explicitly_signals_speech(&action, &dialogue, &prompt)
    {
        return false;
    }

    true
}

pub(super) fn storyboard_has_visible_speech_performance_risk(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
) -> bool {
    if !storyboard_has_meaningful_spoken_dialogue_with_prompt(fields, prompt) {
        return false;
    }

    let shot = normalize_prompt_text(&fields.shot);
    let camera_move = normalize_prompt_text(&fields.camera_move);
    let action = normalize_prompt_text(&fields.action);
    let dialogue = normalize_prompt_text(&fields.dialogue);
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();

    let mut score = 0i32;
    if ["特写", "近景", "近特写", "大特写"]
        .iter()
        .any(|keyword| shot.contains(keyword))
    {
        score += 2;
    } else if shot.contains("中景") {
        score += 1;
    } else if ["远景", "全景"]
        .iter()
        .any(|keyword| shot.contains(keyword))
    {
        score -= 1;
    }

    if storyboard_explicitly_signals_speech(&action, &dialogue, &prompt)
        || [
            "嘴角", "唇线", "抿唇", "喉结", "口型", "嘴唇", "失声", "哽咽", "呢喃", "低声", "轻声",
        ]
        .iter()
        .any(|keyword| {
            action.contains(keyword) || dialogue.contains(keyword) || prompt.contains(keyword)
        })
    {
        score += 2;
    }

    if !video_prompt_scene_has_motion_risk(fields)
        || ["静止", "缓推", "慢推", "停顿", "驻足", "停步"]
            .iter()
            .any(|keyword| camera_move.contains(keyword) || action.contains(keyword))
    {
        score += 1;
    }

    if video_prompt_scene_subject_count(fields) > 1 {
        score -= 1;
    }

    score >= 2
}

pub(super) fn dialogue_fragment_is_low_gain_utterance(dialogue: &str) -> bool {
    let stripped = dialogue
        .chars()
        .filter(|ch| {
            !ch.is_whitespace()
                && !matches!(ch, '：' | ':' | '，' | ',' | '。' | '！' | '!' | '？' | '?')
        })
        .collect::<String>();
    if stripped.is_empty() {
        return true;
    }
    let char_count = stripped.chars().count();
    if char_count > 2 {
        return false;
    }

    [
        "嗯", "啊", "呀", "哎", "欸", "诶", "哦", "喂", "哈", "呵", "呃", "唉", "哼",
    ]
    .iter()
    .any(|token| stripped == *token)
}

pub(super) fn storyboard_explicitly_signals_speech(
    action: &str,
    dialogue: &str,
    prompt: &str,
) -> bool {
    [action, dialogue, prompt].into_iter().any(|value| {
        !value.is_empty()
            && [
                "开口",
                "说道",
                "说出",
                "说着",
                "低声说",
                "轻声说",
                "哽咽",
                "失声",
                "喊",
                "叫住",
                "质问",
                "回答",
                "回应",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(super) fn canonical_observation_note(value: &str) -> String {
    value
        .trim()
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | ';' | '，' | '；' | '.' | '。' | ':' | '：')
        })
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

pub(super) fn compact_negative_constraint_against_storyboard_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return None;
    }
    let conflicts = |value: &str| {
        negative_constraint_conflicts_with_storyboard_style(
            value.trim(),
            selected_style_note,
            storyboard_row,
        )
    };
    match canonical_observation_note(trimmed).as_str() {
        "avoid extreme camera angle or overly tight close-up framing" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid extreme camera angle",
                "avoid overly tight close-up framing",
                conflicts,
            )
        }
        "avoid overly cold, oppressive, or frantic mood" => compact_conflicting_negative_pair(
            trimmed,
            "avoid oppressive or frantic mood",
            "avoid overly cold emotional tone",
            conflicts,
        ),
        "avoid flat cold lighting or harsh backlight silhouette" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid flat cold lighting",
                "avoid harsh backlight silhouette",
                conflicts,
            )
        }
        _ => (!conflicts(trimmed)).then_some(trimmed.to_string()),
    }
}

pub(super) fn compact_conflicting_negative_pair(
    original: &str,
    lhs: &str,
    rhs: &str,
    conflicts: impl Fn(&str) -> bool,
) -> Option<String> {
    let lhs_conflicts = conflicts(lhs);
    let rhs_conflicts = conflicts(rhs);
    match (lhs_conflicts, rhs_conflicts) {
        (false, false) => Some(original.to_string()),
        (true, false) => Some(rhs.to_string()),
        (false, true) => Some(lhs.to_string()),
        (true, true) => None,
    }
}

#[allow(dead_code)]
pub(super) fn select_best_video_prompt_observation_note(candidates: Vec<String>) -> Option<String> {
    candidates.into_iter().max_by(|a, b| {
        score_video_prompt_observation_specificity(a)
            .cmp(&score_video_prompt_observation_specificity(b))
            .then(
                score_video_prompt_observation_quality(a)
                    .cmp(&score_video_prompt_observation_quality(b)),
            )
            .then(b.chars().count().cmp(&a.chars().count()))
            .then(b.cmp(a))
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum VideoPromptObservationFamily {
    Identity,
    Blocking,
    Dialogue,
    Lighting,
    Motion,
    Emotion,
    Generic,
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn prune_low_signal_observation_candidates(candidates: Vec<String>) -> Vec<String> {
    let mut kept = candidates
        .into_iter()
        .filter(|note| !observation_candidate_is_low_signal(note))
        .filter(|note| observation_candidate_matches_storyboard_risk(note, None))
        .collect::<Vec<_>>();
    if kept.is_empty() {
        return Vec::new();
    }
    kept.dedup();
    kept
}

pub(super) fn prune_storyboard_observation_candidates(
    candidates: Vec<String>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let mut kept = candidates
        .into_iter()
        .filter(|note| !observation_candidate_is_low_signal(note))
        .filter(|note| observation_candidate_matches_storyboard_risk(note, storyboard_row))
        .collect::<Vec<_>>();
    if kept.is_empty() {
        return Vec::new();
    }
    kept.dedup();
    kept
}

pub(super) fn observation_candidate_is_low_signal(note: &str) -> bool {
    matches!(
        canonical_observation_note(note).as_str(),
        "avoid repeating stable follow camera"
            | "avoid oppressive or frantic mood"
            | "avoid overly cold emotional tone"
            | "avoid heavy tragic mood"
            | "avoid overly cold, oppressive, or frantic mood"
    )
}

pub(super) fn observation_candidate_matches_storyboard_risk(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    let Some(row) = storyboard_row else {
        return !matches!(
            observation_note_budget_family(note),
            VideoPromptObservationFamily::Generic
        );
    };
    let Some(fields) = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    else {
        return !matches!(
            observation_note_budget_family(note),
            VideoPromptObservationFamily::Generic
        );
    };

    match observation_note_budget_family(note) {
        VideoPromptObservationFamily::Identity => true,
        VideoPromptObservationFamily::Dialogue => {
            storyboard_has_visible_speech_performance_risk(&fields, row.prompt.as_deref())
        }
        VideoPromptObservationFamily::Blocking => video_prompt_scene_has_blocking_risk(&fields),
        VideoPromptObservationFamily::Lighting => video_prompt_scene_has_lighting_risk(&fields),
        VideoPromptObservationFamily::Motion => video_prompt_scene_has_motion_risk(&fields),
        VideoPromptObservationFamily::Emotion => video_prompt_scene_needs_emotional_memory(&fields),
        VideoPromptObservationFamily::Generic => false,
    }
}

pub(super) fn observation_note_budget_family(note: &str) -> VideoPromptObservationFamily {
    let normalized = canonical_observation_note(note);
    if normalized.is_empty() {
        return VideoPromptObservationFamily::Generic;
    }

    if [
        "identity drift",
        "costume drift",
        "costume inconsistency",
        "face distortion",
        "脸",
        "身份",
        "服装",
        "角色一致",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Identity;
    }
    if [
        "lip-sync",
        "blank expression",
        "monotone delivery",
        "口型",
        "dialogue",
        "voice-over",
        "台词",
        "对白",
        "旁白",
        "语音",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Dialogue;
    }
    if [
        "jump axis",
        "axis",
        "eyeline",
        "framing",
        "composition",
        "direction",
        "camera angle",
        "close-up",
        "跳轴",
        "视线",
        "构图",
        "方向",
        "站位",
        "走位",
        "机位",
        "景别",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Blocking;
    }
    if [
        "backlight",
        "silhouette",
        "lighting",
        "light",
        "flicker",
        "exposure",
        "reflection",
        "反光",
        "逆光",
        "光影",
        "曝光",
        "闪烁",
        "霓虹",
        "玻璃",
        "雨",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Lighting;
    }
    if [
        "shaky", "handheld", "motion", "stutter", "blur", "抖动", "手持", "运镜",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Motion;
    }
    if [
        "mood",
        "emotion",
        "tragic",
        "oppressive",
        "frantic",
        "情绪",
        "压迫",
        "悲怆",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Emotion;
    }

    VideoPromptObservationFamily::Generic
}

pub(super) fn score_video_prompt_observation_specificity(note: &str) -> i32 {
    let normalized = canonical_observation_note(note);
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "jump axis",
        "axis",
        "eyeline",
        "framing",
        "composition",
        "direction",
        "camera angle",
        "close-up",
        "跳轴",
        "视线",
        "构图",
        "方向",
        "站位",
        "走位",
        "机位",
        "景别",
    ] {
        if normalized.contains(keyword) {
            score += 18;
        }
    }
    for keyword in [
        "face distortion",
        "identity drift",
        "costume drift",
        "costume inconsistency",
        "lip-sync",
        "blank expression",
        "monotone delivery",
        "口型",
        "脸",
        "身份",
        "服装",
        "角色一致",
    ] {
        if normalized.contains(keyword) {
            score += 16;
        }
    }
    for keyword in [
        "backlight",
        "silhouette",
        "lighting",
        "light",
        "flicker",
        "exposure",
        "reflection",
        "反光",
        "逆光",
        "光影",
        "曝光",
        "闪烁",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "shaky", "handheld", "motion", "stutter", "blur", "抖动", "手持", "运镜",
    ] {
        if normalized.contains(keyword) {
            score += 10;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "tragic",
        "oppressive",
        "frantic",
        "情绪",
        "压迫",
        "悲怆",
    ] {
        if normalized.contains(keyword) {
            score += 6;
        }
    }
    if normalized.contains("repeat")
        || normalized.contains("repeating")
        || normalized.contains("重复")
    {
        score -= 8;
    }
    score
}

pub(super) fn score_video_prompt_observation_quality(note: &str) -> i32 {
    let normalized = canonical_observation_note(note);
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "face distortion",
        "identity drift",
        "costume drift",
        "costume inconsistency",
        "lip-sync",
        "blank expression",
        "monotone delivery",
        "jump axis",
        "axis",
        "eyeline",
        "framing",
        "camera angle",
        "close-up",
        "backlight",
        "silhouette",
        "flicker",
        "stutter",
        "blur",
        "跳轴",
        "视线",
        "构图",
        "方向",
        "站位",
        "走位",
        "逆光",
        "曝光",
        "闪烁",
    ] {
        if normalized.contains(keyword) {
            score += 10;
        }
    }
    score
}

pub(super) fn video_prompt_scene_has_motion_risk(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "跟拍", "推进", "拉远", "摇镜", "手持", "奔跑", "跑", "冲", "扑", "追", "快步",
                "转身", "扑向", "踉跄", "急退",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(super) fn video_prompt_scene_has_lighting_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "逆光",
                "霓虹",
                "反光",
                "玻璃",
                "雨",
                "车灯",
                "闪烁",
                "曝光",
                "剪影",
                "silhouette",
                "backlight",
                "reflection",
                "flicker",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}
