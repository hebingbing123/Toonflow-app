//! Prompt builder and diagnostics logic.

use super::super::builder_parts::quality_tail::continuity_tail_matches;
use super::super::*;
use super::*;

pub fn video_prompt_anchor_label(
    default_label: &'static str,
    compact_label: &'static str,
    compact_labels: bool,
) -> &'static str {
    if compact_labels {
        compact_label
    } else {
        default_label
    }
}

pub fn compact_neighbor_video_style_note(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let compacted = compact_contextual_video_style_note(note, storyboard_row)?;
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return Some(compacted);
    };
    let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<String>();
    let has_non_camera_match = note
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .any(|fragment| {
            !fragment.starts_with("镜头")
                && neighbor_style_fragment_matches_storyboard(&fragment, &fields, &expected_camera)
        });
    if has_non_camera_match {
        return Some(compacted);
    }

    let camera_only = split_prompt_note_fragments(&compacted)
        .filter(|fragment| fragment.starts_with("镜头"))
        .collect::<Vec<_>>();
    if camera_only.is_empty() {
        Some(compacted)
    } else {
        Some(camera_only.join("，"))
    }
}

pub fn compact_contextual_video_style_note(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return compact_video_style_prompt_note(&normalized);
    };

    let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<String>();
    let storyboard_prompt = storyboard_row
        .and_then(|row| row.prompt.as_deref())
        .unwrap_or_default();
    let mut fragments = normalized
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| {
            neighbor_style_fragment_matches_storyboard(fragment, &fields, &expected_camera)
        })
        .filter_map(|fragment| trim_style_fragment_against_storyboard_fields(&fragment, &fields))
        .filter(|fragment| {
            !style_fragment_is_low_gain_hidden_speech_voice(fragment, &fields, storyboard_prompt)
        })
        .filter(|fragment| !style_fragment_lags_current_emotional_turn(fragment, &fields))
        .filter(|fragment| !style_fragment_is_low_gain_mood_carryover(fragment, &fields))
        .map(|fragment| clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .collect::<Vec<_>>();
    if !fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"))
    {
        if let Some(fragment) =
            fallback_contextual_performance_fragment(&normalized, &fields, &fragments)
        {
            fragments.push(fragment);
        }
    }
    let high_signal_fallbacks =
        fallback_high_signal_contextual_style_fragments(&normalized, &fields);
    if fragments.is_empty() {
        fragments = high_signal_fallbacks;
    } else {
        for fallback in high_signal_fallbacks {
            let same_family_exists = fragments.iter().any(|existing| {
                style_note_fragment_family(existing) == style_note_fragment_family(&fallback)
            });
            if !same_family_exists {
                fragments.push(fallback);
            }
        }
    }
    if fragments.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn fallback_high_signal_contextual_style_fragments(
    note: &str,
    fields: &StructuredStoryboardDescription,
) -> Vec<String> {
    let mut fragments = Vec::new();
    for fragment in note
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
    {
        if fragment.starts_with("镜头")
            && fragment.contains("压迫感")
            && !fragments.iter().any(|existing| existing == &fragment)
        {
            fragments.push(clip_prompt_fragment(
                &fragment,
                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
            ));
            continue;
        }
        if fragment.starts_with("情绪")
            && fragment.contains("压迫")
            && video_prompt_scene_needs_emotional_memory(fields)
        {
            let compacted = if fragment.contains("压迫感") {
                "情绪压迫感".to_string()
            } else {
                "情绪压迫".to_string()
            };
            if !fragments.iter().any(|existing| existing == &compacted) {
                fragments.push(compacted);
            }
        }
    }
    fragments
}

pub fn fallback_contextual_performance_fragment(
    note: &str,
    fields: &StructuredStoryboardDescription,
    kept_fragments: &[String],
) -> Option<String> {
    if storyboard_dialogue_is_empty(&fields.dialogue)
        && !video_prompt_scene_needs_emotional_memory(fields)
        && !video_prompt_scene_needs_identity_memory(fields)
    {
        return None;
    }

    note.split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| fragment.starts_with("表演"))
        .filter_map(|fragment| trim_style_fragment_against_storyboard_fields(&fragment, fields))
        .filter(|fragment| !style_fragment_lags_current_emotional_turn(fragment, fields))
        .filter(|fragment| {
            score_memory_fragment_human_performance_detail(
                fragment,
                style_note_fragment_family(fragment),
            ) >= 3
                || (video_prompt_scene_needs_identity_memory(fields)
                    && performance_fragment_has_subject_locked_signal(
                        fragment,
                        &[fields.action.as_str(), fields.dialogue.as_str()],
                    ))
        })
        .filter(|fragment| {
            !kept_fragments
                .iter()
                .any(|existing| style_note_fragment_conflicts_or_overlaps(existing, fragment))
        })
        .max_by(|left, right| {
            score_memory_fragment_human_performance_detail(left, style_note_fragment_family(left))
                .cmp(&score_memory_fragment_human_performance_detail(
                    right,
                    style_note_fragment_family(right),
                ))
                .then_with(|| right.chars().count().cmp(&left.chars().count()))
                .then_with(|| right.cmp(left))
        })
        .map(|fragment| clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
}

pub fn neighbor_style_fragment_matches_storyboard(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    expected_camera: &str,
) -> bool {
    if fragment.starts_with("镜头") {
        return continuity_fragment_matches_fields(fragment, fields, expected_camera)
            || prompt_style_fragment_overlaps_field(fragment, &fields.shot)
            || prompt_style_fragment_overlaps_field(fragment, &fields.camera_move);
    }
    if fragment.starts_with("情绪") {
        return prompt_style_fragment_overlaps_field(fragment, &fields.mood);
    }
    if fragment.starts_with("光影") {
        return prompt_style_fragment_overlaps_field(fragment, &fields.lighting);
    }
    if fragment.starts_with("动作") {
        return prompt_style_fragment_overlaps_field(fragment, &fields.action)
            || prompt_style_fragment_overlaps_field(fragment, &fields.mood);
    }
    if fragment.starts_with("表演") {
        return prompt_style_fragment_overlaps_field(fragment, &fields.action)
            || prompt_style_fragment_overlaps_field(fragment, &fields.dialogue)
            || prompt_style_fragment_overlaps_field(fragment, &fields.mood)
            || style_note_matches_shared_keyword_family(
                fragment,
                &[fields.action.as_str(), fields.dialogue.as_str()],
                PERFORMANCE_SHARED_KEYWORD_FAMILIES,
            );
    }
    if fragment.starts_with("语气") {
        if !storyboard_supports_voice_style(fields) {
            return false;
        }
        return prompt_style_fragment_overlaps_field(fragment, &fields.dialogue)
            || prompt_style_fragment_overlaps_field(fragment, &fields.mood)
            || style_note_matches_shared_keyword_family(
                fragment,
                &[fields.action.as_str(), fields.dialogue.as_str()],
                VOICE_SHARED_KEYWORD_FAMILIES,
            );
    }
    if fragment.starts_with("声场") {
        return prompt_style_fragment_overlaps_field(fragment, &fields.sound)
            || prompt_style_fragment_overlaps_field(fragment, &fields.setting)
            || style_note_matches_shared_keyword_family(
                fragment,
                &[fields.sound.as_str()],
                SOUND_SHARED_KEYWORD_FAMILIES,
            );
    }
    false
}

pub fn prompt_style_fragment_overlaps_field(fragment: &str, field: &str) -> bool {
    if field.is_empty() {
        return false;
    }
    let canonical = canonical_continuity_fragment(fragment);
    !canonical.is_empty()
        && (canonical == field || canonical.contains(field) || field.contains(&canonical))
}

pub fn compact_camera_clause(
    shot: &str,
    camera_move: &str,
    style_coverage: &[String],
) -> Option<String> {
    let parts = [shot, camera_move]
        .into_iter()
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .filter(|part| !prompt_fragment_is_covered(part, style_coverage))
        .collect::<Vec<_>>();
    if parts.is_empty() {
        None
    } else {
        Some(parts.join(", "))
    }
}

pub fn project_director_fragment_adds_visual_style_guidance(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && [
            "机位",
            "运镜",
            "景别",
            "跟拍",
            "推进",
            "慢推",
            "拉远",
            "环绕",
            "手持",
            "特写",
            "近景",
            "中景",
            "全景",
            "远景",
            "光",
            "色",
            "色调",
            "质感",
            "氛围",
            "情绪",
            "风格",
            "tone",
            "style",
            "lighting",
            "mood",
            "frame",
            "composition",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}

pub fn project_director_fragment_is_generic_quality_tail_overlap(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty()
        || continuity_note_adds_specific_guidance(&normalized)
        || project_director_fragment_adds_visual_style_guidance(&normalized)
    {
        return false;
    }
    continuity_tail_matches(&normalized)
}

pub fn project_director_note_has_unique_visual_signal(note: &str) -> bool {
    split_prompt_note_fragments(note).any(|fragment| {
        fragment.starts_with("镜头")
            || fragment.starts_with("光影")
            || fragment.starts_with("环境")
            || [
                "低机位",
                "高机位",
                "稳定跟拍",
                "手持跟拍",
                "慢推",
                "推进",
                "拉远",
                "环绕",
                "逆光",
                "冷光",
                "暖光",
                "霓虹",
                "反光",
                "玻璃",
                "窗帘",
                "车流",
                "雨丝",
                "热气",
            ]
            .iter()
            .any(|keyword| fragment.contains(keyword))
    })
}

pub fn compact_project_art_style_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let normalized = compact_project_art_style_label(&normalized, structured_fields);

    let mut fragments = normalized
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| !prompt_fragment_is_covered(fragment, prompt_coverage))
        .filter(|fragment| {
            structured_fields.is_none_or(|fields| {
                fragment != &fields.mood
                    && fragment != &fields.lighting
                    && fragment != &fields.setting
                    && !continuity_fragment_matches_fields(
                        fragment,
                        fields,
                        &[fields.shot.as_str(), fields.camera_move.as_str()]
                            .into_iter()
                            .filter(|part| !part.is_empty())
                            .collect::<String>(),
                    )
            })
        })
        .collect::<Vec<_>>();

    if fragments.is_empty() {
        if prompt_fragment_is_covered(&normalized, prompt_coverage) {
            return None;
        }
        return Some(clip_prompt_fragment(&normalized, 32));
    }

    fragments.dedup();
    Some(clip_prompt_fragment(&fragments.join(", "), 32))
}

fn compact_project_art_style_label(
    normalized: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> String {
    if normalized == "成熟都市言情二次元动画"
        && structured_fields
            .is_some_and(|fields| !current_storyboard_is_fragile_emotional_turn(fields))
    {
        return "成熟都市言情动画风格".to_string();
    }

    normalized.to_string()
}

pub fn sound_stage_fragment_too_generic_after_trim(body: &str) -> bool {
    matches!(
        normalize_prompt_text(body).as_str(),
        "回响" | "回荡" | "空响" | "闷响" | "轻响" | "回声" | "贴近" | "摩擦" | "留白"
    )
}

pub fn compact_project_director_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    reserved_style_anchors: &[String],
) -> Option<String> {
    let expected_camera = structured_fields.map(|fields| {
        [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<String>()
    });
    let mut scored = Vec::new();
    for (idx, fragment) in note
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .enumerate()
    {
        if fragment.is_empty() || !project_director_fragment_relevant(&fragment) {
            continue;
        }
        let fragment = if let Some(fields) = structured_fields {
            trim_project_director_fragment_against_storyboard_fields(&fragment, fields)
        } else {
            Some(fragment)
        };
        let Some(fragment) = fragment else { continue };
        let fragment = compact_project_director_fragment_language(&fragment);
        if fragment.is_empty() {
            continue;
        }
        if project_director_fragment_is_generic_visual_placeholder(&fragment) {
            continue;
        }
        if project_director_fragment_is_redundant_with_reserved_style_anchors(
            &fragment,
            reserved_style_anchors,
        ) {
            continue;
        }
        if scored
            .iter()
            .any(|(_, _, existing): &(i32, usize, String)| existing == &fragment)
        {
            continue;
        }
        if project_director_fragment_is_generic_quality_tail_overlap(&fragment) {
            continue;
        }
        let style_field_overlap = structured_fields
            .is_some_and(|fields| style_fragment_matches_prompt_style_field(&fragment, fields));
        if prompt_fragment_is_covered(&fragment, prompt_coverage) && !style_field_overlap {
            continue;
        }
        if let (Some(fields), Some(camera)) = (structured_fields, expected_camera.as_deref()) {
            if ((continuity_fragment_matches_fields(&fragment, fields, camera)
                || fragment == fields.mood
                || fragment == fields.lighting)
                && !style_field_overlap)
                || fragment == fields.setting
            {
                continue;
            }
        }
        let score = score_project_director_fragment(&fragment, structured_fields);
        scored.push((score, idx, fragment));
    }
    if scored.is_empty() {
        return None;
    }
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    let mut fragments = scored.into_iter().take(2).collect::<Vec<_>>();
    fragments.sort_by(|a, b| a.1.cmp(&b.1).then(a.2.cmp(&b.2)));
    let fragments = fragments
        .into_iter()
        .map(|(_, _, fragment)| fragment)
        .collect::<Vec<_>>();
    Some(clip_prompt_fragment(&fragments.join(", "), 48))
}

pub fn project_director_fragment_is_redundant_with_reserved_style_anchors(
    fragment: &str,
    reserved_style_anchors: &[String],
) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() || reserved_style_anchors.is_empty() {
        return false;
    }
    if style_fragment_or_body_is_semantically_covered(&normalized, reserved_style_anchors) {
        return true;
    }
    normalized
        .strip_prefix("情绪")
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .is_some_and(|mood| {
            project_director_mood_fragment_is_generic_carryover(&mood)
                && reserved_style_anchors.iter().any(|anchor| {
                    project_director_reserved_anchor_already_carries_performance(anchor)
                })
        })
}

pub fn compact_project_director_fragment_language(fragment: &str) -> String {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty()
        || continuity_note_adds_specific_guidance(&normalized)
        || !project_director_fragment_adds_visual_style_guidance(&normalized)
    {
        return normalized;
    }

    let compacted = strip_generic_director_continuity_subfragments(&normalized);
    let trimmed = ["保持", "维持", "延续"]
        .iter()
        .find_map(|prefix| compacted.strip_prefix(prefix))
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty());
    trimmed.unwrap_or(compacted)
}

pub fn project_director_fragment_is_generic_visual_placeholder(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return false;
    }
    if !project_director_fragment_relevant(&normalized)
        || continuity_note_adds_specific_guidance(&normalized)
    {
        return false;
    }

    let stripped = [
        "镜头语言",
        "镜头",
        "画面",
        "光影",
        "情绪",
        "氛围",
        "风格",
        "色调",
        "质感",
        "节奏",
        "场景",
        "camera",
        "lighting",
        "mood",
        "style",
        "tone",
        "frame",
        "composition",
        "统一",
        "一致",
        "连续",
        "衔接",
        "保持",
        "延续",
        "稳定",
    ]
    .into_iter()
    .fold(normalized.clone(), |acc, token| acc.replace(token, ""));
    normalize_prompt_text(&stripped).is_empty()
}

pub fn trim_project_director_fragment_against_storyboard_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    if ["镜头", "情绪", "光影"]
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
    {
        return trim_style_fragment_against_storyboard_fields(fragment, fields);
    }
    Some(fragment.to_string())
}

pub fn score_project_director_fragment(
    fragment: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> i32 {
    let mut score = 0;
    if ["统一", "连续", "衔接", "延续", "保持"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
    {
        score += 18;
    }
    if [
        "镜头",
        "构图",
        "机位",
        "运镜",
        "景别",
        "frame",
        "composition",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
    {
        score += 14;
    }
    if [
        "光", "色", "色调", "质感", "氛围", "情绪", "风格", "tone", "style",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
    {
        score += 8;
    }
    if let Some(fields) = structured_fields {
        if !fields.shot.is_empty() && fragment.contains(&fields.shot) {
            score -= 10;
        }
        if !fields.camera_move.is_empty() && fragment.contains(&fields.camera_move) {
            score -= 10;
        }
        if !fields.mood.is_empty() && fragment.contains(&fields.mood) {
            score -= 8;
        }
        if !fields.lighting.is_empty() && fragment.contains(&fields.lighting) {
            score -= 8;
        }
        if !fields.setting.is_empty() && fragment.contains(&fields.setting) {
            score -= 6;
        }
    }
    score - fragment.chars().count() as i32 / 2
}

pub fn project_director_fragment_relevant(fragment: &str) -> bool {
    [
        "镜头",
        "构图",
        "机位",
        "运镜",
        "景别",
        "光",
        "色",
        "色调",
        "质感",
        "氛围",
        "节奏",
        "场景",
        "情绪",
        "风格",
        "统一",
        "连续",
        "延续",
        "保持",
        "camera",
        "lighting",
        "mood",
        "style",
        "tone",
        "frame",
        "composition",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}
