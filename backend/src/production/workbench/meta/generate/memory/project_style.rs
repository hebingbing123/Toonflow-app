use super::*;

pub(in crate::production::workbench::meta::generate) fn should_keep_project_style_summary_rows(
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

pub(in crate::production::workbench::meta::generate) fn keep_prioritized_observation_summary_rows(
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

pub(in crate::production::workbench::meta::generate) fn prioritize_observation_summary_indices(
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

pub(in crate::production::workbench::meta::generate) fn observation_summary_row_matches_subject_candidates(
    row: &AgentMemoryRow,
    subject_candidates: &[String],
) -> bool {
    memory_subject_match_priority(&row.content, subject_candidates) != usize::MAX
}

pub(in crate::production::workbench::meta::generate) fn memory_subject_match_priority(
    content: &str,
    subject_candidates: &[String],
) -> usize {
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

pub(in crate::production::workbench::meta::generate) fn observation_summary_row_sample_count(
    content: &str,
) -> usize {
    extract_key_value(content, "sampleCount")
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(0)
}

pub(in crate::production::workbench::meta::generate) fn observation_summary_row_risk_overlap(
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

pub(in crate::production::workbench::meta::generate) fn storyboard_observation_summary_risk_tags(
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

pub(in crate::production::workbench::meta::generate) fn keep_matching_role_observation_rows(
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
