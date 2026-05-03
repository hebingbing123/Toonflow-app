use super::*;

pub(crate) fn build_rejected_video_negative_memory(
    storyboard_numeric_id: i32,
    row: &StoryboardPromptSeedRow,
) -> Option<String> {
    if storyboard_numeric_id <= 0 {
        return None;
    }

    let fields = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let mut fragments = Vec::new();
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_shot_or_camera_fragment(&fields.shot),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_shot_or_camera_fragment(&fields.camera_move),
    );
    push_rejected_negative_fragment(&mut fragments, map_rejected_mood_fragment(&fields.mood));
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_lighting_fragment(&fields.lighting),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_performance_fragment(&fields.action, &fields.dialogue, &fields.mood),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_static_idle_fragment(
            &fields.action,
            &fields.dialogue,
            &fields.mood,
            &fields.camera_move,
        ),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_dialogue_fragment(&fields.dialogue),
    );
    push_rejected_negative_fragment(&mut fragments, map_rejected_identity_fragment(&fields));
    let fragments = compact_rejected_negative_memory_fragments_for_storage(
        fragments.into_iter().map(str::to_string).collect(),
    );
    if fragments.is_empty() {
        return None;
    }
    let risk_tags = rejected_video_negative_risk_tags(&fields, &fragments);
    let focus_tags = rejected_video_focus_tags_from_avoid(&fragments.join(", "));

    let mut parts = vec![format!("storyboardIds={storyboard_numeric_id}")];
    if let Some(prompt_seed) = storyboard_prompt_seed(row) {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    if let Some(subject) = selected_memory_subject_identity(&fields.subject, &fields.subject_refs) {
        parts.push(format!("subject={subject}"));
        let subject_aliases =
            selected_memory_subject_aliases(&fields.subject, &fields.subject_refs)
                .into_iter()
                .filter(|alias| alias != &subject)
                .collect::<Vec<_>>();
        if !subject_aliases.is_empty() {
            parts.push(format!("subjectAliases={}", subject_aliases.join("/")));
        }
    }
    parts.push("rejectionCount=1".to_string());
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    parts.push(format!("avoid={}", fragments.join(", ")));
    Some(parts.join(" | "))
}

fn rejected_video_negative_risk_tags(
    fields: &StructuredStoryboardDescription,
    fragments: &[String],
) -> Vec<&'static str> {
    let families = fragments
        .iter()
        .map(|fragment| observation_note_family(fragment))
        .collect::<Vec<_>>();
    let mut tags = Vec::new();

    if families.iter().any(|family| {
        matches!(
            *family,
            "camera_motion_stability" | "flicker_motion_jitter" | "shot_change_framing"
        )
    }) && selected_memory_scene_has_motion_risk(fields)
    {
        tags.push("motion");
    }
    if families
        .iter()
        .any(|family| *family == "character_consistency")
        && rejected_negative_scene_has_identity_risk(fields)
    {
        tags.push("identity");
    }
    if families
        .iter()
        .any(|family| matches!(*family, "camera_framing" | "shot_change_framing"))
        && rejected_negative_scene_has_framing_risk(fields)
    {
        tags.push("framing");
    }
    if families
        .iter()
        .any(|family| matches!(*family, "lighting_backlight" | "lighting_reflection"))
        && rejected_negative_scene_has_lighting_risk(fields)
    {
        tags.push("lighting");
    }
    if families.iter().any(|family| *family == "mood_tone")
        && rejected_negative_scene_needs_emotional_guard(fields)
    {
        tags.push("emotion");
    }
    if families
        .iter()
        .any(|family| *family == "performance_delivery")
        && rejected_negative_scene_needs_emotional_guard(fields)
    {
        tags.push("emotion");
    }
    if families
        .iter()
        .any(|family| *family == "performance_delivery")
        && rejected_negative_scene_needs_expressive_performance_guard(fields)
    {
        tags.push("performance");
    }
    if families
        .iter()
        .any(|family| *family == "performance_delivery")
        && rejected_negative_scene_has_dialogue_guard(fields)
    {
        tags.push("dialogue");
    }
    if families.iter().any(|family| *family == "lip_sync")
        && rejected_negative_scene_has_dialogue_guard(fields)
    {
        tags.push("dialogue");
    }

    tags
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_negative_scene_has_framing_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && [
                    "近景",
                    "特写",
                    "仰拍",
                    "俯拍",
                    "倾斜",
                    "跟拍",
                    "推进",
                    "拉远",
                    "摇镜",
                    "甩镜",
                    "切换",
                    "转场",
                    "close-up",
                    "tight close-up",
                    "low angle",
                    "high angle",
                    "dutch angle",
                    "follow",
                    "push in",
                    "pull back",
                    "whip",
                    "pan",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        })
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_negative_scene_has_lighting_risk(
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
                "霓虹",
                "反光",
                "玻璃",
                "雨",
                "逆光",
                "背光",
                "剪影",
                "车灯",
                "冷光",
                "冷调",
                "阴天",
                "曝光",
                "reflection",
                "wet street",
                "headlight reflection",
                "silhouette",
                "backlight",
                "flat lighting",
                "cold lighting",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_negative_scene_needs_emotional_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "哭",
                "泪",
                "哽咽",
                "颤",
                "停顿",
                "压抑",
                "克制",
                "愤怒",
                "惊慌",
                "紧张",
                "压迫",
                "冷峻",
                "崩溃",
                "隐忍",
                "欲言又止",
                "迟疑",
                "回头",
                "犹豫",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_negative_scene_needs_expressive_performance_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    rejected_negative_scene_needs_emotional_guard(fields)
        && (!selected_memory_field_looks_silent(&fields.dialogue)
            || [fields.mood.as_str(), fields.action.as_str()]
                .into_iter()
                .map(normalize_prompt_text)
                .any(|value| {
                    !value.is_empty()
                        && [
                            "欲言又止",
                            "隐忍",
                            "哽咽",
                            "低声",
                            "轻声",
                            "迟疑",
                            "停顿",
                            "犹豫",
                            "强忍",
                            "颤",
                        ]
                        .iter()
                        .any(|keyword| value.contains(keyword))
                }))
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_negative_scene_has_dialogue_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    !selected_memory_field_looks_silent(&fields.dialogue)
}

fn compact_rejected_negative_memory_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = compact_rejected_negative_fragment_risk_budget(fragments);
    let has_cold_lighting = compacted
        .iter()
        .any(|fragment| canonical_observation_note(fragment) == "avoid flat cold lighting");
    if has_cold_lighting {
        compacted.retain(|fragment| {
            canonical_observation_note(fragment) != "avoid overly cold emotional tone"
        });
    }
    let has_performance_delivery_guard = compacted
        .iter()
        .any(|fragment| observation_note_family(fragment) == "performance_delivery");
    if has_performance_delivery_guard {
        compacted.retain(|fragment| observation_note_family(fragment) != "mood_tone");
    }
    let has_character_guard = compacted.iter().any(|fragment| {
        matches!(
            observation_note_family(fragment),
            "character_consistency" | "performance_delivery"
        )
    });
    if has_character_guard {
        compacted.retain(|fragment| {
            canonical_observation_note(fragment) != "avoid repeating stable follow camera"
        });
    }

    if compacted.len() == 1
        && compacted
            .first()
            .is_some_and(|fragment| rejected_negative_memory_fragment_is_low_signal(fragment))
    {
        return Vec::new();
    }

    compacted
}

fn compact_rejected_negative_memory_fragments_for_storage(fragments: Vec<String>) -> Vec<String> {
    compact_rejected_negative_memory_fragments_for_storage_with_bias(fragments, None)
}

pub(in crate::production::workbench::video_prompt_memory) fn compact_rejected_negative_memory_fragments_for_storage_with_bias(
    fragments: Vec<String>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    let fragments = stitch_rejected_negative_fragments(fragments);
    let mut ranked = compact_rejected_negative_memory_fragments(
        compact_rejected_negative_fragment_families(fragments),
    )
    .into_iter()
    .enumerate()
    .map(|(idx, fragment)| {
        (
            score_rejected_negative_fragment(&fragment)
                + score_rejected_video_memory_bias_for_fragment(&fragment, bias),
            idx,
            fragment,
        )
    })
    .collect::<Vec<_>>();
    ranked.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    let ordered = ranked
        .into_iter()
        .map(|(_, _, fragment)| fragment)
        .collect::<Vec<_>>();
    prioritize_rejected_negative_fragments_for_bias(ordered, bias)
        .into_iter()
        .take(REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT)
        .collect()
}

fn prioritize_rejected_negative_fragments_for_bias(
    ordered: Vec<String>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    let Some(bias) = bias else {
        return ordered;
    };
    let focus_match = |fragment: &String| {
        let tags = negative_fragment_storyboard_risk_tags(fragment);
        if bias.prefer_delivery && !bias.prefer_visual_continuity {
            return tags
                .iter()
                .any(|tag| matches!(*tag, "dialogue" | "performance" | "emotion"));
        }
        if bias.prefer_visual_continuity && !bias.prefer_delivery {
            return tags
                .iter()
                .any(|tag| matches!(*tag, "identity" | "lighting" | "motion" | "framing"));
        }
        false
    };

    let mut prioritized = ordered.into_iter().partition::<Vec<_>, _>(focus_match);
    prioritized.0.extend(prioritized.1);
    prioritized.0
}

pub(in crate::production::workbench::video_prompt_memory) fn selected_optimization_bias_to_rejected_selection_bias(
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<VideoPromptMemorySelectionBias> {
    let Some(bias) = bias else {
        return None;
    };
    Some(VideoPromptMemorySelectionBias {
        prefer_delivery: bias.prefer_delivery || bias.prefer_emotion,
        prefer_visual_continuity: bias.prefer_identity || bias.prefer_lighting,
    })
}

pub(in crate::production::workbench::video_prompt_memory) fn prepare_rejected_video_negative_memory_for_storage(
    content: &str,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Option<String> {
    let avoid = extract_key_value(content, "avoid")?;
    let fragments = split_prompt_note_fragments(&avoid).collect::<Vec<_>>();
    let compacted =
        compact_rejected_negative_memory_fragments_for_storage_with_bias(fragments, bias);
    if compacted.is_empty() {
        return None;
    }

    let risk_tags = rejected_video_risk_tags_from_avoid(&compacted.join(", "));
    let focus_tags = rejected_video_focus_tags_from_avoid(&compacted.join(", "));
    let mut parts = Vec::new();
    for key in [
        "storyboardIds",
        "promptSeed",
        "subject",
        "subjectAliases",
        "rejectionCount",
    ] {
        if let Some(value) = extract_key_value(content, key).filter(|value| !value.is_empty()) {
            parts.push(format!("{key}={value}"));
        }
    }
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    parts.push(format!("avoid={}", compacted.join(", ")));
    Some(parts.join(" | "))
}

fn push_rejected_negative_fragment(
    target: &mut Vec<&'static str>,
    candidate: Option<&'static str>,
) {
    let Some(candidate) = candidate else {
        return;
    };
    if target.iter().any(|existing| existing == &candidate) {
        return;
    }
    target.push(candidate);
}

fn map_rejected_shot_or_camera_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("手持") {
        return Some("avoid shaky handheld motion");
    }
    if value.contains("稳定跟拍")
        || value.contains("跟拍")
        || value.contains("推进")
        || value.contains("慢推")
    {
        return Some("avoid repeating stable follow camera");
    }
    if value.contains("低机位") || value.contains("高机位") {
        return Some("avoid extreme camera angle");
    }
    if value.contains("特写") || value.contains("近景") {
        return Some("avoid overly tight close-up framing");
    }
    None
}

fn map_rejected_mood_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("压迫") || value.contains("紧张") || value.contains("急迫") {
        return Some("avoid oppressive or frantic mood");
    }
    if value.contains("冷峻") || value.contains("冷调") || value.contains("冷色") {
        return Some("avoid overly cold emotional tone");
    }
    if value.contains("悲怆") {
        return Some("avoid heavy tragic mood");
    }
    None
}

fn map_rejected_performance_fragment(
    action: &str,
    dialogue: &str,
    mood: &str,
) -> Option<&'static str> {
    let action = normalize_prompt_text(action);
    let dialogue = normalize_prompt_text(dialogue);
    let mood = normalize_prompt_text(mood);
    let has_dialogue = !dialogue.is_empty()
        && !["无台词", "沉默", "静默", "无对白"]
            .iter()
            .any(|token| dialogue.contains(token));
    let has_restrained_emotional_signal = [action.as_str(), dialogue.as_str(), mood.as_str()]
        .into_iter()
        .any(|value| {
            !value.is_empty()
                && [
                    "欲言又止",
                    "隐忍",
                    "哽咽",
                    "低声",
                    "轻声",
                    "迟疑",
                    "停顿",
                    "犹豫",
                    "压低声音",
                    "强忍",
                    "颤",
                    "克制",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        });
    if has_dialogue && has_restrained_emotional_signal {
        return Some("avoid blank expression or monotone delivery");
    }

    let has_silent_high_signal = [action.as_str(), mood.as_str()].into_iter().any(|value| {
        !value.is_empty()
            && [
                "欲言又止",
                "隐忍",
                "哽咽",
                "迟疑",
                "停顿",
                "犹豫",
                "强忍",
                "颤",
                "喉结",
                "嘴角发僵",
                "下颌绷紧",
                "指尖发颤",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    });
    has_silent_high_signal.then_some("avoid blank expression or monotone delivery")
}

fn map_rejected_dialogue_fragment(dialogue: &str) -> Option<&'static str> {
    let dialogue = normalize_prompt_text(dialogue);
    let has_dialogue = !dialogue.is_empty()
        && !["无台词", "沉默", "静默", "无对白"]
            .iter()
            .any(|token| dialogue.contains(token));
    has_dialogue.then_some("avoid lip-sync mismatch")
}

fn map_rejected_static_idle_fragment(
    action: &str,
    dialogue: &str,
    mood: &str,
    camera_move: &str,
) -> Option<&'static str> {
    let action = normalize_prompt_text(action);
    let dialogue = normalize_prompt_text(dialogue);
    let mood = normalize_prompt_text(mood);
    let camera_move = normalize_prompt_text(camera_move);
    let has_dialogue = !dialogue.is_empty()
        && !["无台词", "沉默", "静默", "无对白"]
            .iter()
            .any(|token| dialogue.contains(token));
    if has_dialogue || action.is_empty() {
        return None;
    }

    let neutral_mood =
        mood.is_empty() || ["平静", "冷静", "安静"].iter().any(|token| mood == *token);
    let static_camera = ["静止", "固定", "定镜"]
        .iter()
        .any(|token| camera_move.contains(token));
    let idle_pose = ["站在", "站住", "站定", "站在门口", "站在原地"]
        .iter()
        .any(|token| action.contains(token));
    (neutral_mood && static_camera && idle_pose).then_some("avoid stiff idle pose")
}

fn map_rejected_identity_fragment(
    fields: &StructuredStoryboardDescription,
) -> Option<&'static str> {
    (rejected_negative_scene_has_identity_risk(fields)
        && rejected_negative_scene_has_framing_risk(fields)
        && !rejected_negative_scene_has_dialogue_guard(fields))
    .then_some("avoid face distortion or identity drift")
}

fn map_rejected_lighting_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("逆光") {
        return Some("avoid harsh backlight silhouette");
    }
    if value.contains("冷光") || value.contains("阴天冷光") || value.contains("冷调") {
        return Some("avoid flat cold lighting");
    }
    if value.contains("霓虹") || value.contains("反光") {
        return Some("avoid distracting neon reflections");
    }
    None
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_negative_memory_fragment_is_low_signal(
    fragment: &str,
) -> bool {
    matches!(
        canonical_observation_note(fragment).as_str(),
        "avoid repeating stable follow camera"
            | "avoid oppressive or frantic mood"
            | "avoid overly cold emotional tone"
            | "avoid heavy tragic mood"
            | "avoid overly cold, oppressive, or frantic mood"
    )
}
