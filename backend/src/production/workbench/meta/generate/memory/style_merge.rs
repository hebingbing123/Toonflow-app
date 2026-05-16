use super::*;

pub(in crate::production::workbench::meta::generate) fn merge_exact_and_role_style_notes_for_high_value_scene(
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
        if exact_style_note_is_low_signal_template(exact_note) {
            return None;
        }
        role_memory_notes
            .iter()
            .find_map(|role_note| merge_complementary_style_note_pair(exact_note, role_note))
    })
}

pub(in crate::production::workbench::meta::generate) fn video_prompt_scene_needs_identity_memory(
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

pub(in crate::production::workbench::meta::generate) fn prefer_role_memory_only_for_silent_identity_scene(
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

pub(in crate::production::workbench::meta::generate) fn exact_style_note_is_low_gain_identity_carryover(
    note: &str,
) -> bool {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    !fragments.is_empty()
        && fragments.iter().all(|fragment| {
            matches!(
                style_note_fragment_family(fragment),
                Some("镜头") | Some("光影") | Some("环境") | Some("声场")
            )
        })
}

pub(in crate::production::workbench::meta::generate) fn role_style_note_has_visible_micro_performance(
    note: &str,
) -> bool {
    split_prompt_note_fragments(note).any(|fragment| {
        fragment.starts_with("表演")
            && (score_memory_fragment_human_performance_detail(&fragment, Some("表演")) >= 3
                || ["眼神", "目光", "抬眼", "眉", "唇", "喉结"]
                    .iter()
                    .any(|keyword| fragment.contains(keyword)))
    })
}

pub(in crate::production::workbench::meta::generate) fn merge_complementary_style_note_pair(
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

    let merged = sort_style_note_fragments_for_output(&compact_video_style_prompt_note(
        &merged_fragments.join("，"),
    )?)?;
    let exact =
        sort_style_note_fragments_for_output(&compact_video_style_prompt_note(exact_note)?)?;
    let merged_score = merged_style_note_signal_score(&merged);
    let exact_score = merged_style_note_signal_score(&exact);
    (merged != exact && merged_score > exact_score).then_some(merged)
}

pub(in crate::production::workbench::meta::generate) fn extract_compactable_role_voice_note(
    note: &str,
    storyboard_row: &StoryboardPromptSeedRow,
) -> Option<String> {
    split_prompt_note_fragments(note)
        .find(|fragment| fragment.starts_with("语气"))
        .and_then(|fragment| compact_role_voice_fragment_for_storyboard(&fragment, storyboard_row))
}

pub(in crate::production::workbench::meta::generate) fn collect_subject_role_voice_support_notes(
    rows: &[AgentMemoryRow],
    subject_candidates: &[String],
    storyboard_row: &StoryboardPromptSeedRow,
) -> Vec<String> {
    rows.iter()
        .filter(|row| {
            matches!(
                row.name.as_str(),
                "script_role_video_style_memory" | "project_role_video_style_memory"
            ) && memory_content_matches_subject_candidates(&row.content, subject_candidates)
        })
        .filter_map(|row| {
            extract_key_value(&row.content, "style")
                .or_else(|| extract_key_value(&row.content, "note"))
        })
        .filter_map(|note| extract_compactable_role_voice_note(&note, storyboard_row))
        .collect()
}

pub(in crate::production::workbench::meta::generate) fn expand_compacted_delivery_style_note(
    note: &str,
) -> String {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    if fragments.len() != 1 {
        return note.to_string();
    }

    let fragment = &fragments[0];
    if !fragment.starts_with("表演") || fragment.contains("语气") {
        return note.to_string();
    }

    let body = fragment.trim_start_matches("表演");
    let voice_markers = [
        "压低气息尾音发颤",
        "低声尾音发颤",
        "轻声尾音发颤",
        "压低哽咽尾音",
        "低声哽咽尾音",
        "轻声哽咽尾音",
        "轻声克制",
        "低声克制",
        "哽咽克制",
        "轻声",
        "低声",
        "呢喃",
        "哽咽",
        "短促",
    ];
    let Some((marker_idx, _)) = voice_markers
        .iter()
        .filter_map(|marker| body.find(marker).map(|idx| (idx, *marker)))
        .min_by_key(|(idx, _)| *idx)
    else {
        return note.to_string();
    };

    let performance = normalize_prompt_text(&body[..marker_idx]);
    let voice = normalize_prompt_text(&body[marker_idx..]);
    if performance.is_empty() || voice.is_empty() {
        return note.to_string();
    }

    format!("表演{performance}，语气{voice}")
}

pub(in crate::production::workbench::meta::generate) fn collapse_role_style_notes(
    notes: Vec<String>,
) -> Vec<String> {
    if notes.len() <= 1 {
        return notes;
    }

    let mut merged_fragments = Vec::<String>::new();
    for note in notes {
        for fragment in split_prompt_note_fragments(&note) {
            if merged_fragments
                .iter()
                .any(|existing| style_note_fragment_conflicts_or_overlaps(existing, &fragment))
            {
                continue;
            }
            merged_fragments.push(fragment);
        }
    }
    sort_style_note_fragments_for_output(&merged_fragments.join("，"))
        .map(|note| vec![note])
        .unwrap_or_default()
}

fn compact_role_voice_fragment_for_storyboard(
    fragment: &str,
    storyboard_row: &StoryboardPromptSeedRow,
) -> Option<String> {
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    if !storyboard_supports_voice_style(&fields) {
        return None;
    }

    let mut body = normalize_prompt_text(fragment.trim_start_matches("语气"));
    if body.is_empty() {
        return None;
    }

    for keyword in ["克制", "隐忍", "压抑", "沉静", "冷静"] {
        if fields.mood.contains(keyword) && body.contains(keyword) {
            let trimmed = normalize_prompt_text(&body.replace(keyword, ""));
            if trimmed.chars().count() >= 2 {
                body = trimmed;
            }
        }
    }

    let speech_context = [
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
    if !speech_context && storyboard_dialogue_is_empty(&fields.dialogue) {
        return None;
    }

    Some(format!("语气{body}"))
}

pub(in crate::production::workbench::meta::generate) fn sort_style_note_fragments_for_output(
    note: &str,
) -> Option<String> {
    let mut fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }
    fragments.sort_by(|left, right| {
        style_note_fragment_output_rank(left)
            .cmp(&style_note_fragment_output_rank(right))
            .then(left.cmp(right))
    });
    Some(fragments.join("，"))
}

fn style_note_fragment_output_rank(fragment: &str) -> usize {
    match style_note_fragment_family(fragment) {
        Some("镜头") => 0,
        Some("情绪") => 1,
        Some("光影") => 2,
        Some("动作") => 3,
        Some("表演") => 4,
        Some("环境") => 5,
        Some("语气") => 6,
        Some("声场") => 7,
        _ => usize::MAX,
    }
}

pub(in crate::production::workbench::meta::generate) fn role_memory_fragment_is_high_value(
    fragment: &str,
) -> bool {
    fragment.starts_with("表演")
        || fragment.starts_with("语气")
        || (fragment.starts_with("动作")
            && ["克制", "迟疑", "停顿", "轻缓", "自然", "优雅"]
                .iter()
                .any(|keyword| fragment.contains(keyword)))
}

pub(in crate::production::workbench::meta::generate) fn style_note_fragment_conflicts_or_overlaps(
    existing: &str,
    candidate: &str,
) -> bool {
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

pub(in crate::production::workbench::meta::generate) fn style_note_fragment_family(
    fragment: &str,
) -> Option<&'static str> {
    [
        "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
    ]
    .into_iter()
    .find(|prefix| fragment.starts_with(*prefix))
}

pub(in crate::production::workbench::meta::generate) fn merged_style_note_signal_score(
    note: &str,
) -> usize {
    split_prompt_note_fragments(note)
        .map(|fragment| match style_note_fragment_family(&fragment) {
            Some("表演") | Some("语气") => 3,
            Some("情绪") | Some("光影") => 2,
            Some("镜头") | Some("动作") | Some("环境") | Some("声场") => 1,
            _ => 0,
        })
        .sum()
}

pub(in crate::production::workbench::meta::generate) fn is_local_framing_only_fragment(
    fragment: &str,
) -> bool {
    matches!(
        fragment,
        "镜头近景" | "镜头中景" | "镜头远景" | "镜头特写" | "镜头全景"
    )
}

pub(in crate::production::workbench::meta::generate) fn collect_neighbor_video_prompt_style_notes(
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

pub(in crate::production::workbench::meta::generate) fn memory_content_has_subject_identity(
    content: &str,
) -> bool {
    extract_key_value(content, "subject").is_some()
        || extract_key_value(content, "subjectAliases").is_some()
}

pub(in crate::production::workbench::meta::generate) fn memory_content_matches_subject_candidates(
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

pub(in crate::production::workbench::meta::generate) fn extract_storyboard_ids_from_memory_content(
    content: &str,
) -> Vec<i32> {
    extract_key_value(content, "storyboardIds")
        .map(|raw| {
            raw.split(',')
                .filter_map(|part| part.trim().parse::<i32>().ok())
                .filter(|id| *id > 0)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}
