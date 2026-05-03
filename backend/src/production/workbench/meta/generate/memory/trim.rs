use super::*;

#[allow(dead_code)]
pub(in crate::production::workbench::meta::generate) fn trim_video_prompt_memory_rows(
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

pub(in crate::production::workbench::meta::generate) fn trim_video_prompt_memory_rows_with_context(
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

pub(in crate::production::workbench::meta::generate) fn keep_matching_role_style_rows(
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

pub(in crate::production::workbench::meta::generate) fn selected_memory_row_matches_subject_candidates(
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

pub(in crate::production::workbench::meta::generate) fn prioritize_storyboard_memory_indices(
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

pub(in crate::production::workbench::meta::generate) fn prioritize_storyboard_memory_indices_with_context(
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

pub(in crate::production::workbench::meta::generate) fn memory_prompt_seed_matches(
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

pub(in crate::production::workbench::meta::generate) fn memory_prompt_seed_for_storyboard(
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

pub(in crate::production::workbench::meta::generate) fn storyboard_distance_from_memory_content(
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
