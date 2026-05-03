//! Prompt builder and diagnostics logic.

use super::super::*;
use super::*;

pub fn resolve_video_prompt_description(
    description: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> Option<String> {
    let description = description
        .map(normalize_prompt_text)
        .filter(|text| !text.is_empty());
    if description.is_some() {
        return description;
    }
    context.and_then(|ctx| {
        ctx.storyboard_video_desc
            .as_deref()
            .map(normalize_prompt_text)
            .filter(|text| !text.is_empty())
            .or_else(|| {
                ctx.storyboard_prompt
                    .as_deref()
                    .map(normalize_prompt_text)
                    .filter(|text| !text.is_empty())
            })
    })
}

#[allow(dead_code)]
pub fn resolve_video_prompt_memory_budget_tier(
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    role_anchors: &[String],
    scene_anchors: &[String],
    tool_anchors: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> VideoPromptMemoryBudgetTier {
    let mut risk_score: i32 = 0;
    if image_url.is_none() {
        risk_score += 2;
    }
    if role_anchors.is_empty() && structured_fields.is_some_and(|fields| !fields.subject.is_empty())
    {
        risk_score += 1;
    }
    if scene_anchors.is_empty()
        && tool_anchors.is_empty()
        && structured_fields.is_some_and(|fields| !fields.setting.is_empty())
    {
        risk_score += 1;
    }
    let has_effective_continuity_note = context.is_some_and(|ctx| {
        video_prompt_has_effective_continuity_note_for_budget(
            &ctx.continuity_notes,
            structured_fields,
        )
    });
    if has_effective_continuity_note {
        risk_score += 1;
    }
    if structured_fields.is_some_and(video_prompt_scene_needs_emotional_memory) {
        risk_score += 1;
    }
    if image_url.is_none()
        && structured_fields.is_some_and(video_prompt_scene_is_grounded_low_risk)
        && !role_anchors.is_empty()
        && (!scene_anchors.is_empty() || !tool_anchors.is_empty())
        && !has_effective_continuity_note
    {
        risk_score = risk_score.saturating_sub(2);
    }
    if constraint_pressure.is_some_and(|pressure| pressure.forces_compact_memory) {
        risk_score = risk_score.saturating_sub(1);
    }
    if constraint_pressure.is_some_and(|pressure| {
        pressure.has_active_guardrail()
            && !role_anchors.is_empty()
            && (!scene_anchors.is_empty() || !tool_anchors.is_empty())
    }) {
        risk_score = risk_score.saturating_sub(1);
    }

    if risk_score >= 2 {
        VideoPromptMemoryBudgetTier::Expanded
    } else {
        VideoPromptMemoryBudgetTier::Lean
    }
}

pub fn collect_suppressed_memory_style_bucket_counts(
    raw: &std::collections::BTreeMap<String, usize>,
    selected: &std::collections::BTreeMap<String, usize>,
) -> std::collections::BTreeMap<String, usize> {
    raw.iter()
        .filter_map(|(bucket, raw_count)| {
            let selected_count = selected.get(bucket).copied().unwrap_or(0);
            raw_count
                .checked_sub(selected_count)
                .filter(|remaining| *remaining > 0)
                .map(|remaining| (bucket.clone(), remaining))
        })
        .collect()
}

pub fn collect_reserved_art_style_anchors(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let mut reserved = Vec::new();
    for candidate in [
        resolve_performance_style_anchor(project_art_style, structured_fields, prompt_coverage),
        resolve_environment_style_anchor(project_art_style, structured_fields, prompt_coverage),
        resolve_environment_texture_style_anchor(
            project_art_style,
            structured_fields,
            prompt_coverage,
        ),
        resolve_motion_style_anchor(project_art_style, structured_fields, prompt_coverage),
    ]
    .into_iter()
    .flatten()
    {
        if reserved.iter().any(|existing| existing == &candidate) {
            continue;
        }
        reserved.push(candidate);
    }
    reserved
}

pub fn director_performance_fragment_is_generic_proactive_hint(fragment: &str) -> bool {
    matches!(
        normalize_prompt_text(fragment).as_str(),
        "眼神先动再开口"
            | "开口前先压住气息"
            | "尾音带轻颤"
            | "气息带情绪起伏"
            | "眼神嘴角细微递进"
    )
}

pub fn restore_reference_guardrail_style_detail(
    compacted_note: &str,
    original_note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> String {
    let Some(fields) = structured_fields else {
        return compacted_note.to_string();
    };
    let Some(pressure) = constraint_pressure else {
        return compacted_note.to_string();
    };
    if !pressure.has_lighting_guardrail {
        return compacted_note.to_string();
    }

    let Some(original_lighting) = split_prompt_note_fragments(original_note)
        .find(|fragment| {
            fragment.starts_with("光影")
                && fragment.contains(&fields.lighting)
                && lighting_fragment_retains_specific_detail(fragment, &fields.lighting)
        })
        .map(|fragment| fragment.to_string())
    else {
        return compacted_note.to_string();
    };

    let restored = split_prompt_note_fragments(compacted_note)
        .map(|fragment| {
            if fragment.starts_with("光影")
                && low_signal_compacted_lighting_fragment(&fragment)
                && fragment != original_lighting
            {
                original_lighting.clone()
            } else {
                fragment
            }
        })
        .collect::<Vec<_>>();

    if restored.is_empty() {
        compacted_note.to_string()
    } else {
        restored.join("，")
    }
}

pub fn lighting_fragment_retains_specific_detail(fragment: &str, lighting: &str) -> bool {
    let body = normalize_prompt_text(fragment.trim_start_matches("光影"));
    let lighting = normalize_prompt_text(lighting);
    body.contains(&lighting)
        && normalize_prompt_text(&body.replace(&lighting, ""))
            .chars()
            .count()
            >= 2
}

fn low_signal_compacted_lighting_fragment(fragment: &str) -> bool {
    matches!(
        normalize_prompt_text(fragment).as_str(),
        "光影层次" | "光影质感" | "光影氛围"
    )
}

pub fn compact_expanded_visual_memory_fragment(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    memory_budget_tier: VideoPromptMemoryBudgetTier,
) -> Option<String> {
    if memory_budget_tier != VideoPromptMemoryBudgetTier::Expanded {
        return None;
    }

    if fragment.starts_with("光影") {
        let trimmed = trim_style_fragment_against_storyboard_fields(fragment, fields)?;
        return (trimmed != fragment
            && lighting_fragment_retains_specific_detail(fragment, &fields.lighting))
        .then_some(trimmed);
    }

    None
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LeanMemoryPairFocus {
    Emotional,
    Dialogue,
    DeliveryLighting,
    IdentityLighting,
}

pub fn collect_lean_memory_pair_focuses(
    fields: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> impl Iterator<Item = LeanMemoryPairFocus> {
    if video_prompt_scene_has_motion_risk(fields)
        && storyboard_dialogue_is_empty(&fields.dialogue)
        && !current_storyboard_is_fragile_emotional_turn(fields)
    {
        return Vec::new().into_iter();
    }

    let mut focuses = Vec::new();
    if video_prompt_scene_needs_emotional_memory(fields) {
        focuses.push(LeanMemoryPairFocus::Emotional);
    }
    if video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure) {
        focuses.push(LeanMemoryPairFocus::Dialogue);
    }
    if video_prompt_scene_needs_delivery_lighting_pair_memory(fields, constraint_pressure) {
        focuses.push(LeanMemoryPairFocus::DeliveryLighting);
    }
    if video_prompt_scene_needs_identity_lighting_pair_memory(fields, constraint_pressure) {
        focuses.push(LeanMemoryPairFocus::IdentityLighting);
    }
    focuses.into_iter()
}

pub fn score_memory_style_fragment_for_lean_tier(
    fragment: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let family = style_note_fragment_family(fragment);
    let mut score = match family {
        Some("表演") | Some("语气") => 6,
        Some("情绪") | Some("光影") => 5,
        Some("动作") => 4,
        Some("环境") | Some("声场") => 3,
        Some("镜头") => 2,
        _ => 0,
    };
    score += score_memory_fragment_human_performance_detail(fragment, family);

    if let Some(fields) = structured_fields {
        if video_prompt_scene_needs_emotional_memory(fields) {
            score += match family {
                Some("表演") | Some("语气") => 5,
                Some("情绪") => 4,
                _ => 0,
            };
        }
        if video_prompt_scene_has_lighting_risk(fields) {
            score += match family {
                Some("光影") => 8,
                Some("环境") | Some("声场") => 5,
                _ => 0,
            };
            if family == Some("表演") {
                score -= 2;
            }
        }
        if video_prompt_scene_has_motion_risk(fields) {
            score += match family {
                Some("动作") => 6,
                Some("镜头") => 5,
                Some("表演") => 1,
                _ => 0,
            };
        }
        if storyboard_dialogue_is_empty(&fields.dialogue) && family == Some("语气") {
            score -= 2;
        }
        if video_prompt_scene_has_motion_risk(fields)
            && storyboard_dialogue_is_empty(&fields.dialogue)
            && !current_storyboard_is_fragile_emotional_turn(fields)
        {
            score += match family {
                Some("动作") => 5,
                Some("镜头") => 4,
                Some("表演") => -6,
                _ => 0,
            };
        }
    }
    if let Some(pressure) = constraint_pressure {
        score += score_memory_fragment_against_constraint_pressure(fragment, family, pressure);
    }

    score
}

pub fn score_memory_style_note_for_expanded_tier(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let mut score = split_prompt_note_fragments(note)
        .map(|fragment| {
            score_memory_style_fragment_for_lean_tier(
                fragment.as_str(),
                structured_fields,
                constraint_pressure,
            )
        })
        .sum::<i32>();
    if let Some(fields) = structured_fields {
        if video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
            || current_storyboard_is_fragile_emotional_turn(fields)
        {
            if memory_style_anchor_has_delivery_signal(note) {
                score += 18;
            }
            if style_note_contains_family(note, "表演") {
                score += 8;
            }
            if style_note_contains_family(note, "语气") {
                score += 8;
            }
        }
    }
    if let Some(pressure) = constraint_pressure {
        if pressure.prefer_delivery_memory_recall {
            if memory_style_anchor_has_delivery_signal(note) {
                score += 12;
            }
            if style_note_contains_family(note, "表演") {
                score += 5;
            }
            if style_note_contains_family(note, "语气") {
                score += 5;
            }
        }
        if pressure.prefer_visual_continuity_memory_recall {
            if style_note_contains_family(note, "光影") {
                score += 8;
            }
            if style_note_contains_family(note, "镜头") {
                score += 6;
            }
            if style_note_contains_family(note, "环境") {
                score += 4;
            }
        }
    }
    score
}

pub fn score_memory_fragment_against_constraint_pressure(
    fragment: &str,
    family: Option<&'static str>,
    pressure: VideoPromptConstraintPressure,
) -> i32 {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    if pressure.has_emotion_guardrail {
        score += match family {
            Some("表演") => 4,
            Some("情绪") => -5,
            Some("语气") => {
                if memory_fragment_has_high_signal_voice_detail(&normalized) {
                    1
                } else {
                    -6
                }
            }
            Some("声场") => -4,
            _ => 0,
        };
    }
    if pressure.has_dialogue_guardrail && family == Some("语气") {
        score += if memory_fragment_has_high_signal_voice_detail(&normalized) {
            0
        } else {
            -6
        };
    }
    if pressure.has_motion_guardrail {
        score += match family {
            Some("动作") if generic_motion_style_fragment(&normalized) => -4,
            Some("镜头") if is_local_framing_only_fragment(&normalized) => -3,
            Some("表演") => 1,
            _ => 0,
        };
    }
    if pressure.has_lighting_guardrail {
        score += match family {
            Some("光影") => 3,
            Some("环境") | Some("声场") => -3,
            _ => 0,
        };
    }
    if pressure.has_blocking_guardrail {
        score += match family {
            Some("镜头") if is_local_framing_only_fragment(&normalized) => -4,
            Some("动作") if generic_motion_style_fragment(&normalized) => -3,
            _ => 0,
        };
    }
    if pressure.has_identity_guardrail {
        score += match family {
            Some("表演") => 4,
            Some("语气") => {
                if memory_fragment_has_high_signal_voice_detail(&normalized) {
                    0
                } else {
                    -4
                }
            }
            Some("动作") if generic_motion_style_fragment(&normalized) => -4,
            Some("环境") | Some("声场") => -4,
            Some("情绪") => -3,
            _ => 0,
        };
    }

    score
}

pub fn memory_fragment_has_high_signal_voice_detail(fragment: &str) -> bool {
    ["气息", "换气", "哽咽", "发颤", "尾音", "压低"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

pub fn score_memory_fragment_human_performance_detail(
    fragment: &str,
    family: Option<&'static str>,
) -> i32 {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    match family {
        Some("表演") => {
            for keyword in [
                "喉结", "吞咽", "呼吸", "鼻息", "眼尾", "眼眶", "眼睫", "嘴角", "眉心", "眉梢",
                "唇线", "唇角", "眨眼",
            ] {
                if normalized.contains(keyword) {
                    score += 3;
                }
            }
            for keyword in ["眼神", "目光"] {
                if normalized.contains(keyword) {
                    score += 2;
                }
            }
            for keyword in [
                "气息", "换气", "哽咽", "发颤", "尾音", "压低", "轻声", "低声",
            ] {
                if normalized.contains(keyword) {
                    score += 2;
                }
            }
            for keyword in ["迟疑", "犹疑", "犹豫"] {
                if normalized.contains(keyword) {
                    score += 1;
                }
            }
            for keyword in ["自然", "克制", "平静", "沉静", "放松"] {
                if normalized.contains(keyword) {
                    score -= 1;
                }
            }
        }
        Some("语气") => {
            for keyword in ["气息", "换气", "哽咽", "发颤", "尾音", "压低"] {
                if normalized.contains(keyword) {
                    score += 3;
                }
            }
        }
        _ => {}
    }

    score
}

pub fn score_compacted_style_note_against_constraint_pressure(
    note: &str,
    fields: &StructuredStoryboardDescription,
    pressure: VideoPromptConstraintPressure,
) -> i32 {
    let mut score = merged_style_note_signal_score(note) as i32;
    for fragment in split_prompt_note_fragments(note) {
        score += score_memory_style_fragment_for_lean_tier(&fragment, Some(fields), Some(pressure));
    }

    if role_style_note_has_visible_micro_performance(note)
        && (pressure.has_identity_guardrail
            || pressure.has_dialogue_guardrail
            || pressure.has_emotion_guardrail)
    {
        score += 8;
    }
    if pressure.prefer_delivery_memory_recall {
        if style_note_contains_family(note, "表演") {
            score += 4;
        }
        if style_note_contains_family(note, "语气") {
            score += 4;
        }
    }
    if pressure.prefer_visual_continuity_memory_recall {
        if style_note_contains_family(note, "光影") {
            score += 5;
        }
        if style_note_contains_family(note, "镜头") {
            score += 4;
        }
        if style_note_contains_family(note, "环境") {
            score += 2;
        }
    }
    if style_note_contains_family(note, "光影") && pressure.has_lighting_guardrail {
        score += 4;
    }
    if style_note_contains_family(note, "动作") && pressure.has_motion_guardrail {
        score += 3;
    }

    score
}

pub fn select_best_expressive_memory_pair_for_lean_tier(
    fragments: &[String],
    fields: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
    pair_focus: LeanMemoryPairFocus,
) -> Option<(String, i32)> {
    let dialogue_is_empty = storyboard_dialogue_is_empty(&fields.dialogue);
    let has_motion_risk = video_prompt_scene_has_motion_risk(fields);
    let has_lighting_risk = video_prompt_scene_has_lighting_risk(fields);
    let mut best: Option<(String, i32, usize)> = None;

    for (left_idx, left) in fragments.iter().enumerate() {
        for right in fragments.iter().skip(left_idx + 1) {
            if style_note_fragment_conflicts_or_overlaps(left, right) {
                continue;
            }
            let pair = format!("{left}，{right}");
            let pair_len = normalize_prompt_text(&pair).chars().count();
            if pair_len > VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS {
                continue;
            }

            let left_family = style_note_fragment_family(left);
            let right_family = style_note_fragment_family(right);
            let families = [left_family, right_family];
            if dialogue_is_empty && families.contains(&Some("语气")) {
                continue;
            }
            if !families.contains(&Some("表演")) {
                continue;
            }
            let allows_pair = match pair_focus {
                LeanMemoryPairFocus::Dialogue => {
                    families.contains(&Some("语气"))
                        && [left.as_str(), right.as_str()].into_iter().any(|fragment| {
                            style_note_fragment_family(fragment) == Some("语气")
                                && memory_fragment_has_high_signal_voice_detail(
                                    normalize_prompt_text(fragment).as_str(),
                                )
                        })
                }
                LeanMemoryPairFocus::DeliveryLighting => {
                    families.contains(&Some("光影"))
                        && [left.as_str(), right.as_str()].into_iter().any(|fragment| {
                            match style_note_fragment_family(fragment) {
                                Some("表演") => {
                                    score_memory_fragment_human_performance_detail(
                                        fragment,
                                        Some("表演"),
                                    ) >= 3
                                }
                                Some("语气") => memory_fragment_has_high_signal_voice_detail(
                                    normalize_prompt_text(fragment).as_str(),
                                ),
                                _ => false,
                            }
                        })
                }
                LeanMemoryPairFocus::Emotional => {
                    families.contains(&Some("语气"))
                        || families.contains(&Some("情绪"))
                        || (has_motion_risk
                            && !has_lighting_risk
                            && families.contains(&Some("动作")))
                }
                LeanMemoryPairFocus::IdentityLighting => {
                    families.contains(&Some("光影"))
                        && [left.as_str(), right.as_str()].into_iter().any(|fragment| {
                            style_note_fragment_family(fragment) == Some("表演")
                                && score_memory_fragment_human_performance_detail(
                                    fragment,
                                    Some("表演"),
                                ) >= 3
                        })
                }
            };
            if !allows_pair {
                continue;
            }

            let mut score =
                score_memory_style_fragment_for_lean_tier(left, Some(fields), constraint_pressure)
                    + score_memory_style_fragment_for_lean_tier(
                        right,
                        Some(fields),
                        constraint_pressure,
                    );
            if families.contains(&Some("语气")) {
                score += match pair_focus {
                    LeanMemoryPairFocus::Dialogue => 10,
                    LeanMemoryPairFocus::DeliveryLighting => 4,
                    LeanMemoryPairFocus::Emotional => 8,
                    LeanMemoryPairFocus::IdentityLighting => 0,
                };
            }
            if pair_focus == LeanMemoryPairFocus::DeliveryLighting {
                score += 12;
                if families.contains(&Some("光影")) {
                    score += 5;
                }
                if families.contains(&Some("表演")) {
                    score += 4;
                }
            }
            if pair_focus == LeanMemoryPairFocus::Emotional && families.contains(&Some("情绪")) {
                score += 5;
            }
            if pair_focus == LeanMemoryPairFocus::Emotional
                && has_motion_risk
                && families.contains(&Some("动作"))
            {
                score += 3;
            }
            if pair_focus == LeanMemoryPairFocus::IdentityLighting {
                score += 11;
                if families.contains(&Some("光影")) {
                    score += 5;
                }
            }

            match &best {
                Some((best_pair, best_score, best_len))
                    if *best_score > score
                        || (*best_score == score
                            && (*best_len < pair_len
                                || (*best_len == pair_len && best_pair <= &pair))) => {}
                _ => best = Some((pair, score, pair_len)),
            }
        }
    }

    best.map(|(pair, score, _)| (pair, score))
}

pub fn preserve_high_signal_performance_fragment(
    trimmed: Option<String>,
    original_fragment: &str,
) -> Option<String> {
    let Some(trimmed) = trimmed else {
        return performance_fragment_has_unique_micro_detail(original_fragment)
            .then(|| original_fragment.to_string());
    };

    let original_body = original_fragment.trim_start_matches("表演");
    let trimmed_body = trimmed.trim_start_matches("表演");
    if PERFORMANCE_SHARED_KEYWORD_FAMILIES.iter().any(|family| {
        family.iter().any(|keyword| original_body.contains(keyword))
            && !family.iter().any(|keyword| trimmed_body.contains(keyword))
    }) && !performance_fragment_has_unique_micro_detail(&trimmed)
    {
        performance_fragment_has_unique_micro_detail(original_fragment)
            .then(|| original_fragment.to_string())
    } else {
        Some(trimmed)
    }
}

pub fn performance_fragment_has_unique_micro_detail(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    [
        "喉结", "吞咽", "呼吸", "鼻息", "眼尾", "眼眶", "眼睫", "嘴角", "眉心", "眉梢", "唇线",
        "唇角", "眨眼", "下颌",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

pub fn generic_motion_style_fragment(fragment: &str) -> bool {
    let body = normalize_prompt_text(fragment.trim_start_matches("动作"));
    matches!(
        body.as_str(),
        "自然"
            | "从容克制"
            | "克制自然"
            | "缓慢优雅"
            | "简洁平滑"
            | "缓慢"
            | "轻盈"
            | "利落"
            | "轻缓克制"
    )
}

pub fn resolve_video_prompt_duration(
    duration_hint: Option<i32>,
    description: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> i32 {
    if let Some(value) = duration_hint.filter(|value| *value > 0) {
        return value.clamp(2, 16);
    }
    if let Some(parsed) = resolve_video_prompt_description(description, context)
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .and_then(|fields| fields.duration_seconds)
    {
        return parsed.clamp(2, 16);
    }
    if let Some(parsed) = context
        .and_then(|ctx| ctx.storyboard_duration.as_deref())
        .and_then(parse_positive_int)
    {
        return parsed.clamp(2, 16);
    }
    5
}
