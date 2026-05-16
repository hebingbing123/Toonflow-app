use super::*;

pub(in crate::production::workbench::meta::generate) fn compact_generation_brief_style_note_for_storyboard(
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

pub(in crate::production::workbench::meta::generate) fn supplement_compacted_voice_note(
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

pub(in crate::production::workbench::meta::generate) fn preserve_runtime_exact_camera_fragment(
    original_note: &str,
    compacted_note: &str,
) -> String {
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

pub(in crate::production::workbench::meta::generate) fn restore_runtime_exact_style_note_fragments(
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

pub(in crate::production::workbench::meta::generate) fn preserve_delivery_pair_if_compaction_overtrims(
    original: &str,
    compacted: &str,
) -> String {
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
