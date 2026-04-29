//! Prompt builder and diagnostics logic.

use super::*;

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn build_video_prompt(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> String {
    build_video_prompt_with_constraint_pressure(description, image_url, context, None).prompt
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn build_video_prompt_with_diagnostics(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> VideoPromptBuildResult {
    build_video_prompt_with_constraint_pressure(description, image_url, context, None)
}

pub(super) fn build_video_prompt_with_constraint_pressure(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> VideoPromptBuildResult {
    let resolved_description = resolve_video_prompt_description(description, context);
    let structured_fields = resolved_description
        .as_deref()
        .and_then(parse_structured_storyboard_description);
    let compact_labels = structured_fields
        .as_ref()
        .is_some_and(video_prompt_scene_is_grounded_low_risk);
    let mut clauses = Vec::new();
    clauses.push(build_video_prompt_opening_clause(
        structured_fields.as_ref(),
    ));
    let mut prompt_coverage = collect_prompt_coverage(structured_fields.as_ref());
    let role_anchors = build_script_role_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    if !role_anchors.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Character anchor", "Character", compact_labels),
            role_anchors.join("; ")
        ));
    }
    let scene_anchors = build_script_scene_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    if !scene_anchors.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Scene anchor", "Scene", compact_labels),
            scene_anchors.join("; ")
        ));
    }
    let tool_anchors = build_script_tool_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    if !tool_anchors.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Prop anchor", "Prop", compact_labels),
            tool_anchors.join("; ")
        ));
    }
    let mut asset_coverage = Vec::new();
    extend_prompt_coverage(&mut asset_coverage, &role_anchors);
    extend_prompt_coverage(&mut asset_coverage, &scene_anchors);
    extend_prompt_coverage(&mut asset_coverage, &tool_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &role_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &scene_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &tool_anchors);
    let memory_budget_tier = resolve_video_prompt_memory_budget_tier(
        image_url,
        context,
        structured_fields.as_ref(),
        &role_anchors,
        &scene_anchors,
        &tool_anchors,
        constraint_pressure,
    );
    let style_anchor_build = build_project_visual_anchors(
        context,
        structured_fields.as_ref(),
        &prompt_coverage,
        image_url.is_some(),
        memory_budget_tier,
        constraint_pressure,
    );
    let style_anchors = style_anchor_build.anchors;
    let memory_style_anchor_count = style_anchor_build.memory_style_anchor_count;
    let memory_anchors = style_anchors
        .iter()
        .rev()
        .take(memory_style_anchor_count)
        .cloned()
        .collect::<Vec<_>>();
    let memory_style_chars = memory_anchors
        .iter()
        .map(|anchor| anchor.chars().count())
        .sum();
    let (memory_visual_chars, memory_delivery_chars) =
        memory_style_anchor_char_breakdown(&memory_anchors);
    let mut style_coverage = Vec::new();
    extend_prompt_coverage(&mut style_coverage, &style_anchors);
    match structured_fields.as_ref() {
        Some(fields) => {
            let compacted_dialogue =
                compact_dialogue_clause(&fields.dialogue, Some(fields), context);
            let mut subject = compact_subject_clause(
                &fields.subject,
                &asset_coverage,
                &prompt_coverage,
                Some(fields.action.as_str()),
            );
            let setting = compact_setting_clause(
                &fields.setting,
                &asset_coverage,
                &prompt_coverage,
                Some(fields.subject.as_str()),
                Some(fields.action.as_str()),
            );
            let action = compact_action_clause(
                &fields.action,
                &asset_coverage,
                &prompt_coverage,
                compacted_dialogue.as_deref(),
                Some(fields.setting.as_str()),
            )
            .map(|action| {
                compact_hidden_speech_action_clause(&action, &fields.dialogue, fields, context)
            })
            .unwrap_or(None);

            if prompt_clauses_substantially_overlap(subject.as_deref(), action.as_deref()) {
                subject = None;
            }

            if let Some(subject) = subject {
                clauses.push(format!("Subject: {}.", clip_prompt_fragment(&subject, 72)));
            }
            if let Some(setting) = setting {
                clauses.push(format!("Setting: {}.", clip_prompt_fragment(&setting, 48)));
            }
            if let Some(action) = action.as_ref() {
                clauses.push(format!("Action: {}.", clip_prompt_fragment(action, 72)));
            }
            if let Some(camera) =
                compact_camera_clause(&fields.shot, &fields.camera_move, &style_coverage)
            {
                clauses.push(format!("Camera: {}.", clip_prompt_fragment(&camera, 40)));
            }
            if !fields.mood.is_empty()
                && !prompt_style_field_is_covered(&fields.mood, &style_coverage)
            {
                clauses.push(format!("Mood: {}.", clip_prompt_fragment(&fields.mood, 36)));
            }
            if !fields.lighting.is_empty()
                && !prompt_style_field_is_covered(&fields.lighting, &style_coverage)
            {
                clauses.push(format!(
                    "Lighting: {}.",
                    clip_prompt_fragment(&fields.lighting, 44)
                ));
            }
            if let Some(dialogue) = compacted_dialogue.as_deref() {
                clauses.push(format!("Dialogue: {}.", clip_prompt_fragment(dialogue, 60)));
            }
            if let Some(sound) = compact_sound_clause(
                &fields.sound,
                compacted_dialogue.as_deref(),
                action.as_deref(),
            ) {
                clauses.push(format!("Sound: {}.", clip_prompt_fragment(&sound, 44)));
            }
        }
        None => {
            let fallback = resolved_description
                .filter(|text| !text.is_empty())
                .unwrap_or_else(|| "Clear subject, natural motion, stable continuity.".to_string());
            clauses.push(format!("Scene: {}.", clip_prompt_fragment(&fallback, 160)));
        }
    }

    if !style_anchors.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Style anchor", "Style", compact_labels),
            style_anchors.join("; ")
        ));
    }
    extend_prompt_coverage(&mut prompt_coverage, &style_anchors);
    let continuity_notes = build_continuity_notes(
        context,
        structured_fields.as_ref(),
        &prompt_coverage,
        memory_budget_tier,
        constraint_pressure,
    );
    let continuity_note_chars = continuity_notes
        .iter()
        .map(|note| note.chars().count())
        .sum();
    if !continuity_notes.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Continuity notes", "Continuity", compact_labels),
            continuity_notes.join("; ")
        ));
    }
    if image_url.is_some() {
        clauses.push("Use the supplied frame as reference.".to_string());
    }
    clauses.push(build_video_prompt_quality_tail(
        structured_fields.as_ref(),
        &style_anchors,
        &continuity_notes,
        constraint_pressure,
    ));
    let prompt = clauses.join(" ");
    VideoPromptBuildResult {
        diagnostics: GenerateVideoPromptDiagnostics {
            prompt_chars: prompt.chars().count(),
            negative_prompt_chars: 0,
            negative_constraint_count: 0,
            negative_budget_tier: "lean".to_string(),
            auto_negative_source: None,
            auto_negative_review_fragment_count: 0,
            auto_negative_memory_fragment_count: 0,
            observation_note_chars: 0,
            role_anchor_count: role_anchors.len(),
            scene_anchor_count: scene_anchors.len(),
            tool_anchor_count: tool_anchors.len(),
            style_anchor_count: style_anchors.len(),
            memory_style_anchor_count,
            memory_delivery_anchor_count: style_anchor_build.memory_delivery_anchor_count,
            memory_delivery_priority_applied: style_anchor_build.memory_delivery_priority_applied,
            memory_style_chars,
            memory_visual_chars,
            memory_delivery_chars,
            memory_hit_buckets: style_anchor_build.memory_hit_buckets,
            memory_suppressed_buckets: style_anchor_build.memory_suppressed_buckets,
            memory_hit_bucket_counts: style_anchor_build.memory_hit_bucket_counts,
            memory_suppressed_bucket_counts: style_anchor_build.memory_suppressed_bucket_counts,
            memory_optimization_applied: false,
            memory_optimization_removed_rows: 0,
            memory_optimization_removed_chars: 0,
            memory_optimization_removed_visual_rows: 0,
            memory_optimization_removed_duplicate_rows: 0,
            director_manual_yielded_to_memory: style_anchor_build.director_manual_yielded_to_memory,
            director_manual_yielded_chars: style_anchor_build.director_manual_yielded_chars,
            director_performance_trimmed_chars: style_anchor_build
                .director_performance_trimmed_chars,
            director_anchor_saved_chars: style_anchor_build.director_manual_yielded_chars
                + style_anchor_build.director_performance_trimmed_chars,
            continuity_note_count: continuity_notes.len(),
            continuity_note_chars,
            uses_reference_frame: image_url.is_some(),
            memory_budget_tier: memory_budget_tier.as_str().to_string(),
        },
        prompt,
    }
}

pub(super) fn video_prompt_anchor_label(
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

pub(super) fn compact_neighbor_video_style_note(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    compact_contextual_video_style_note(note, storyboard_row)
}

pub(super) fn compact_contextual_video_style_note(
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
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

pub(super) fn fallback_contextual_performance_fragment(
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
                    && style_note_matches_shared_keyword_family(
                        fragment,
                        &[fields.action.as_str(), fields.dialogue.as_str()],
                        PERFORMANCE_SHARED_KEYWORD_FAMILIES,
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

pub(super) fn neighbor_style_fragment_matches_storyboard(
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

pub(super) fn prompt_style_fragment_overlaps_field(fragment: &str, field: &str) -> bool {
    if field.is_empty() {
        return false;
    }
    let canonical = canonical_continuity_fragment(fragment);
    !canonical.is_empty()
        && (canonical == field || canonical.contains(field) || field.contains(&canonical))
}

pub(super) fn storyboard_supports_voice_style(fields: &StructuredStoryboardDescription) -> bool {
    if !storyboard_dialogue_is_empty(&fields.dialogue) {
        return true;
    }

    let normalized_action = normalize_prompt_text(&fields.action);
    if normalized_action.is_empty() {
        return false;
    }

    [
        "开口",
        "说",
        "说道",
        "说出",
        "低声",
        "轻声",
        "呢喃",
        "哽咽",
        "吸气",
        "呼吸",
        "欲言又止",
    ]
    .iter()
    .any(|keyword| normalized_action.contains(keyword))
}

pub(super) fn style_fragment_is_low_gain_hidden_speech_voice(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    prompt: &str,
) -> bool {
    fragment.starts_with("语气")
        && dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech(
            &fields.dialogue,
            fields,
            prompt,
        )
}

pub(super) fn style_fragment_lags_current_emotional_turn(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    if !fragment.starts_with("语气") {
        return false;
    }

    let Some(fragment_voice_family) = style_voice_family_for_generate(fragment) else {
        return false;
    };
    let Some(context_voice_family) = current_storyboard_voice_family(fields) else {
        return false;
    };
    if fragment_voice_family == context_voice_family {
        return false;
    }

    current_storyboard_is_fragile_emotional_turn(fields)
        || matches!(context_voice_family, "fragile" | "clipped")
}

pub(super) fn current_storyboard_voice_family(
    fields: &StructuredStoryboardDescription,
) -> Option<&'static str> {
    [
        fields.dialogue.as_str(),
        fields.action.as_str(),
        fields.mood.as_str(),
    ]
    .into_iter()
    .find_map(style_voice_family_for_generate)
}

pub(super) fn current_storyboard_is_fragile_emotional_turn(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.action.as_str(),
        fields.dialogue.as_str(),
        fields.mood.as_str(),
    ]
    .into_iter()
    .any(|field| {
        ["哽咽", "发哽", "含泪", "泪", "哭", "发颤", "颤声", "鼻音"]
            .iter()
            .any(|keyword| field.contains(keyword))
    })
}

pub(super) fn style_voice_family_for_generate(text: &str) -> Option<&'static str> {
    [
        ("哽咽", "fragile"),
        ("发哽", "fragile"),
        ("失声", "fragile"),
        ("哑声", "fragile"),
        ("哭腔", "fragile"),
        ("颤声", "fragile"),
        ("鼻音", "fragile"),
        ("抽气", "fragile"),
        ("发颤", "fragile"),
        ("低声", "low"),
        ("压低", "low"),
        ("轻声", "light"),
        ("轻轻", "light"),
        ("呢喃", "murmur"),
        ("喃喃", "murmur"),
        ("耳语", "murmur"),
        ("短促", "clipped"),
        ("急促", "clipped"),
    ]
    .into_iter()
    .find_map(|(keyword, family)| text.contains(keyword).then_some(family))
}

pub(super) fn build_video_prompt_quality_tail(
    structured_fields: Option<&StructuredStoryboardDescription>,
    style_anchors: &[String],
    continuity_notes: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> String {
    if structured_fields.is_some_and(video_prompt_scene_is_grounded_low_risk) {
        return "No extra shot changes.".to_string();
    }

    let camera = structured_fields
        .map(|fields| {
            [fields.shot.as_str(), fields.camera_move.as_str()]
                .into_iter()
                .filter(|part| !part.is_empty())
                .collect::<String>()
        })
        .unwrap_or_default();
    let continuity_is_explicit = !continuity_notes.is_empty()
        || continuity_tail_matches(&camera)
        || style_anchors
            .iter()
            .any(|anchor| continuity_tail_matches(anchor));
    let guardrail_continuity_is_explicit =
        style_anchors
            .iter()
            .chain(continuity_notes.iter())
            .any(|fragment| {
                continuity_fragment_matches_constraint_pressure(fragment, constraint_pressure)
            });
    let motion_is_explicit = style_anchors
        .iter()
        .chain(continuity_notes.iter())
        .any(|fragment| quality_tail_motion_is_explicit(fragment));

    if (guardrail_continuity_is_explicit
        && constraint_pressure.is_some_and(|pressure| pressure.forces_compact_memory))
        || (continuity_is_explicit && motion_is_explicit)
    {
        "No extra shot changes.".to_string()
    } else if continuity_is_explicit {
        "Natural motion, no extra shot changes.".to_string()
    } else if motion_is_explicit {
        "Stable continuity, no extra shot changes.".to_string()
    } else {
        "Natural motion, stable continuity, no extra shot changes.".to_string()
    }
}

pub(super) fn build_video_prompt_opening_clause(
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> String {
    if structured_fields.is_some_and(video_prompt_scene_is_grounded_low_risk) {
        "Single shot.".to_string()
    } else {
        "Single cinematic shot.".to_string()
    }
}

pub(super) fn continuity_tail_matches(value: &str) -> bool {
    let normalized = normalize_prompt_text(value);
    !normalized.is_empty()
        && ["稳定", "跟拍", "衔接", "连续", "一致", "统一"]
            .iter()
            .any(|keyword| normalized.contains(keyword))
}

pub(super) fn quality_tail_motion_is_explicit(value: &str) -> bool {
    let normalized = normalize_prompt_text(value);
    !normalized.is_empty()
        && [
            "动作", "节奏", "跟拍", "推进", "拉远", "手持", "转身", "快步", "呼吸", "停顿", "自然",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}

pub(super) fn compact_camera_clause(
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

pub(super) fn continuity_note_adds_specific_guidance(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && [
            "走位",
            "站位",
            "跳轴",
            "方向",
            "构图",
            "视线",
            "节奏",
            "动作",
            "位置",
            "前后景",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}

pub(super) fn continuity_fragment_is_generic_quality_tail_overlap(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() || continuity_note_adds_specific_guidance(&normalized) {
        return false;
    }
    continuity_fragment_core(&normalized)
        .as_deref()
        .is_some_and(continuity_tail_matches)
}

pub(super) fn project_director_fragment_adds_visual_style_guidance(fragment: &str) -> bool {
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

pub(super) fn project_director_fragment_is_generic_quality_tail_overlap(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty()
        || continuity_note_adds_specific_guidance(&normalized)
        || project_director_fragment_adds_visual_style_guidance(&normalized)
    {
        return false;
    }
    continuity_tail_matches(&normalized)
}

pub(super) fn resolve_video_prompt_description(
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

pub(super) fn resolve_video_prompt_memory_budget_tier(
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

pub(super) fn video_prompt_has_effective_continuity_note_for_budget(
    notes: &[String],
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> bool {
    notes.iter().any(|note| {
        compact_continuity_note(note, structured_fields, &[]).is_some_and(|compacted| {
            continuity_note_matches_storyboard_risk(&compacted, structured_fields)
        })
    })
}

pub(super) fn video_prompt_scene_needs_emotional_memory(
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

pub(super) fn video_prompt_scene_is_grounded_low_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    !video_prompt_scene_has_motion_risk(fields)
        && !video_prompt_scene_has_lighting_risk(fields)
        && !video_prompt_scene_needs_emotional_memory(fields)
}

pub(super) fn build_project_visual_anchors(
    context: Option<&VideoPromptContext>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    has_reference_frame: bool,
    memory_budget_tier: VideoPromptMemoryBudgetTier,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> VideoPromptStyleAnchorBuild {
    let Some(ctx) = context else {
        return VideoPromptStyleAnchorBuild::default();
    };

    let mut anchors = Vec::new();
    let mut memory_anchor_count = 0usize;
    let mut memory_delivery_anchor_count = 0usize;
    let mut memory_delivery_priority_applied = false;
    let raw_memory_bucket_counts = count_memory_style_buckets(
        ctx.memory_style_notes
            .iter()
            .map(std::string::String::as_str),
    );
    let mut selected_memory_bucket_counts = std::collections::BTreeMap::new();
    let mut director_manual_yielded_to_memory = false;
    let mut director_manual_yielded_chars = 0usize;
    let mut director_performance_trimmed_chars = 0usize;
    let mut style_coverage = prompt_coverage.to_vec();
    let compact_decorative_style_anchors = should_compact_decorative_style_anchors(
        structured_fields,
        has_reference_frame,
        constraint_pressure,
    );
    if let Some(style) = ctx
        .project_art_style
        .as_deref()
        .and_then(|value| compact_project_art_style_note(value, structured_fields, &style_coverage))
    {
        anchors.push(clip_prompt_fragment(&style, 32));
        extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
    }
    let reserved_art_style_anchors = collect_reserved_art_style_anchors(
        ctx.project_art_style.as_deref(),
        structured_fields,
        &style_coverage,
    );
    if let Some(note) = ctx.project_director_manual.as_deref().and_then(|value| {
        compact_project_director_note(
            value,
            structured_fields,
            &style_coverage,
            &reserved_art_style_anchors,
        )
    }) {
        let should_yield = project_director_note_should_yield_to_memory_style(
            &note,
            &ctx.memory_style_notes,
            structured_fields,
            constraint_pressure,
        );
        if !should_yield {
            anchors.push(note);
            extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
        } else {
            director_manual_yielded_to_memory = true;
            director_manual_yielded_chars += note.chars().count();
        }
    }
    if let Some(performance_anchor) = resolve_performance_style_anchor(
        ctx.project_art_style.as_deref(),
        structured_fields,
        &style_coverage,
    ) {
        let original_chars = performance_anchor.chars().count();
        let compacted = compact_director_performance_anchor_against_memory_style(
            &performance_anchor,
            &ctx.memory_style_notes,
            structured_fields,
            constraint_pressure,
        );
        match compacted {
            Some(compacted_anchor) => {
                director_performance_trimmed_chars +=
                    original_chars.saturating_sub(compacted_anchor.chars().count());
                anchors.push(compacted_anchor);
                extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
            }
            None => {
                director_performance_trimmed_chars += original_chars;
            }
        }
    }
    if let Some(guardrail_performance_anchor) = resolve_guardrail_performance_anchor(
        structured_fields,
        &style_coverage,
        constraint_pressure,
    ) {
        anchors.push(guardrail_performance_anchor);
        extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
    }
    if !compact_decorative_style_anchors
        || structured_fields
            .zip(constraint_pressure)
            .is_some_and(|(fields, pressure)| {
                should_keep_environment_style_anchor_under_pressure(fields, pressure)
            })
    {
        if let Some(environment_anchor) = resolve_environment_style_anchor(
            ctx.project_art_style.as_deref(),
            structured_fields,
            &style_coverage,
        ) {
            anchors.push(environment_anchor);
            extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
        }
    }
    if !compact_decorative_style_anchors {
        if let Some(environment_texture_anchor) = resolve_environment_texture_style_anchor(
            ctx.project_art_style.as_deref(),
            structured_fields,
            &style_coverage,
        ) {
            anchors.push(environment_texture_anchor);
            extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
        }
    }
    if !compact_decorative_style_anchors
        || structured_fields
            .zip(constraint_pressure)
            .is_some_and(|(fields, pressure)| {
                should_keep_motion_style_anchor_under_pressure(fields, pressure)
            })
    {
        if let Some(motion_anchor) = resolve_motion_style_anchor(
            ctx.project_art_style.as_deref(),
            structured_fields,
            &style_coverage,
        ) {
            anchors.push(motion_anchor);
            extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
        }
    }
    let has_base_style_anchor = !anchors.is_empty();
    let mut memory_candidates = ctx
        .memory_style_notes
        .iter()
        .filter_map(|note| {
            compact_memory_style_anchor(
                note,
                structured_fields,
                &style_coverage,
                has_base_style_anchor,
                memory_budget_tier,
                constraint_pressure,
            )
        })
        .filter(|note| !anchors.iter().any(|existing| existing == note))
        .map(|note| {
            let is_delivery = memory_style_anchor_has_delivery_signal(&note);
            let score = score_memory_style_note_for_expanded_tier(
                &note,
                structured_fields,
                constraint_pressure,
            );
            (note, is_delivery, score)
        })
        .collect::<Vec<_>>();
    memory_candidates.sort_by(|left, right| {
        right
            .2
            .cmp(&left.2)
            .then_with(|| right.1.cmp(&left.1))
            .then_with(|| right.0.chars().count().cmp(&left.0.chars().count()))
            .then_with(|| left.0.cmp(&right.0))
    });

    let mut selected_memory_anchor_kinds = Vec::new();
    for (note, is_delivery, _) in memory_candidates {
        if memory_budget_tier == VideoPromptMemoryBudgetTier::Expanded
            && memory_anchor_count >= 1
            && selected_memory_anchor_kinds
                .iter()
                .any(|kind| *kind != is_delivery)
            && memory_anchor_total_chars_within_budget(
                &anchors,
                &note,
                memory_anchor_count,
                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
            )
            && memory_style_anchor_is_complementary(&note, &anchors)
        {
            extend_prompt_coverage(&mut style_coverage, std::slice::from_ref(&note));
            if is_delivery {
                memory_delivery_anchor_count += 1;
            }
            accumulate_memory_style_bucket_counts(&mut selected_memory_bucket_counts, &note);
            anchors.push(note);
            selected_memory_anchor_kinds.push(is_delivery);
            memory_anchor_count += 1;
            break;
        }
        if memory_anchor_count > 0 {
            continue;
        }
        if is_delivery
            && structured_fields.is_some_and(|fields| {
                video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
                    || current_storyboard_is_fragile_emotional_turn(fields)
            })
        {
            memory_delivery_priority_applied = true;
        }
        extend_prompt_coverage(&mut style_coverage, std::slice::from_ref(&note));
        if is_delivery {
            memory_delivery_anchor_count += 1;
        }
        accumulate_memory_style_bucket_counts(&mut selected_memory_bucket_counts, &note);
        anchors.push(note);
        selected_memory_anchor_kinds.push(is_delivery);
        memory_anchor_count += 1;
    }
    let memory_hit_buckets = flatten_memory_style_bucket_counts(&selected_memory_bucket_counts);
    let memory_suppressed_buckets = flatten_suppressed_memory_style_bucket_counts(
        &raw_memory_bucket_counts,
        &selected_memory_bucket_counts,
    );
    let memory_suppressed_bucket_counts = collect_suppressed_memory_style_bucket_counts(
        &raw_memory_bucket_counts,
        &selected_memory_bucket_counts,
    );
    VideoPromptStyleAnchorBuild {
        anchors,
        memory_style_anchor_count: memory_anchor_count,
        memory_delivery_anchor_count,
        memory_delivery_priority_applied,
        memory_hit_buckets,
        memory_suppressed_buckets,
        memory_hit_bucket_counts: selected_memory_bucket_counts,
        memory_suppressed_bucket_counts,
        director_manual_yielded_to_memory,
        director_manual_yielded_chars,
        director_performance_trimmed_chars,
    }
}

fn memory_style_bucket(fragment: &str) -> Option<&'static str> {
    [
        ("表演", "表演"),
        ("语气", "语气"),
        ("情绪", "情绪"),
        ("动作", "动作"),
        ("镜头", "镜头"),
        ("光影", "光影"),
        ("环境", "环境"),
        ("声场", "声场"),
    ]
    .into_iter()
    .find_map(|(prefix, bucket)| fragment.starts_with(prefix).then_some(bucket))
}

fn count_memory_style_buckets<'a>(
    notes: impl Iterator<Item = &'a str>,
) -> std::collections::BTreeMap<String, usize> {
    let mut counts = std::collections::BTreeMap::new();
    for note in notes {
        accumulate_memory_style_bucket_counts(&mut counts, note);
    }
    counts
}

fn accumulate_memory_style_bucket_counts(
    counts: &mut std::collections::BTreeMap<String, usize>,
    note: &str,
) {
    for fragment in split_prompt_note_fragments(note) {
        let Some(bucket) = memory_style_bucket(&fragment) else {
            continue;
        };
        counts
            .entry(bucket.to_string())
            .and_modify(|count| *count += 1)
            .or_insert(1);
    }
}

fn flatten_memory_style_bucket_counts(
    counts: &std::collections::BTreeMap<String, usize>,
) -> Vec<String> {
    counts
        .iter()
        .filter(|(_, count)| **count > 0)
        .map(|(bucket, _)| bucket.clone())
        .collect()
}

fn flatten_suppressed_memory_style_bucket_counts(
    raw: &std::collections::BTreeMap<String, usize>,
    selected: &std::collections::BTreeMap<String, usize>,
) -> Vec<String> {
    raw.iter()
        .filter_map(|(bucket, raw_count)| {
            let selected_count = selected.get(bucket).copied().unwrap_or(0);
            (raw_count > &selected_count).then_some(bucket.clone())
        })
        .collect()
}

fn collect_suppressed_memory_style_bucket_counts(
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

pub(super) fn should_compact_decorative_style_anchors(
    structured_fields: Option<&StructuredStoryboardDescription>,
    has_reference_frame: bool,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    let Some(fields) = structured_fields else {
        return false;
    };
    if should_yield_decorative_style_to_reference_frame(
        fields,
        has_reference_frame,
        constraint_pressure,
    ) {
        return true;
    }
    let Some(pressure) = constraint_pressure
        .filter(|pressure| pressure.forces_compact_memory && pressure.has_active_guardrail())
    else {
        return false;
    };

    video_prompt_scene_needs_dialogue_performance_memory(fields, Some(pressure))
        || current_storyboard_is_fragile_emotional_turn(fields)
        || (pressure.has_identity_guardrail && video_prompt_scene_needs_identity_memory(fields))
}

pub(super) fn should_yield_decorative_style_to_reference_frame(
    fields: &StructuredStoryboardDescription,
    has_reference_frame: bool,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    has_reference_frame
        && !constraint_pressure.is_some_and(|pressure| {
            pressure.has_lighting_guardrail || pressure.has_motion_guardrail
        })
        && (video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
            || current_storyboard_is_fragile_emotional_turn(fields))
}

pub(super) fn should_keep_environment_style_anchor_under_pressure(
    fields: &StructuredStoryboardDescription,
    pressure: VideoPromptConstraintPressure,
) -> bool {
    video_prompt_scene_has_lighting_risk(fields)
        && !pressure.has_dialogue_guardrail
        && !pressure.has_identity_guardrail
}

pub(super) fn should_keep_motion_style_anchor_under_pressure(
    fields: &StructuredStoryboardDescription,
    pressure: VideoPromptConstraintPressure,
) -> bool {
    video_prompt_scene_has_motion_risk(fields)
        && !pressure.has_dialogue_guardrail
        && !pressure.has_emotion_guardrail
        && !current_storyboard_is_fragile_emotional_turn(fields)
}

pub(super) fn collect_reserved_art_style_anchors(
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

pub(super) fn project_director_note_should_yield_to_memory_style(
    director_note: &str,
    memory_style_notes: &[String],
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    let Some(fields) = structured_fields else {
        return false;
    };
    if !video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
        && !current_storyboard_is_fragile_emotional_turn(fields)
    {
        return false;
    }
    if project_director_note_has_unique_visual_signal(director_note) {
        return false;
    }

    memory_style_notes.iter().any(|note| {
        split_prompt_note_fragments(note).any(|fragment| {
            role_memory_fragment_is_high_value(fragment.as_str())
                || sound_fragment_has_high_value_acoustic_detail(fragment.as_str())
        })
    })
}

pub(super) fn compact_director_performance_anchor_against_memory_style(
    anchor: &str,
    memory_style_notes: &[String],
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let Some(fields) = structured_fields else {
        return Some(anchor.to_string());
    };
    if !video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
        && !current_storyboard_is_fragile_emotional_turn(fields)
    {
        return Some(anchor.to_string());
    }

    let expressive_memory_fragments = memory_style_notes
        .iter()
        .flat_map(|note| split_prompt_note_fragments(note))
        .filter(|fragment| role_memory_fragment_is_high_value(fragment))
        .collect::<Vec<_>>();
    if expressive_memory_fragments.is_empty() {
        return Some(anchor.to_string());
    }

    let expressive_memory_refs = expressive_memory_fragments
        .iter()
        .map(String::as_str)
        .collect::<Vec<_>>();
    let retained = split_prompt_note_fragments(anchor)
        .filter(|fragment| {
            !prompt_fragment_is_covered(fragment, &expressive_memory_fragments)
                && !style_note_matches_shared_keyword_family(
                    fragment,
                    &expressive_memory_refs,
                    PERFORMANCE_SHARED_KEYWORD_FAMILIES,
                )
        })
        .collect::<Vec<_>>();
    if retained.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &retained.join(", "),
        VIDEO_PROMPT_PERFORMANCE_ANCHOR_MAX_CHARS,
    ))
}

pub(super) fn project_director_note_has_unique_visual_signal(note: &str) -> bool {
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

pub(super) fn memory_style_anchor_has_delivery_signal(note: &str) -> bool {
    let note = normalize_prompt_text(note);
    if note.is_empty() {
        return false;
    }

    let has_performance_signal = note.starts_with("表演")
        || [
            "抬眼",
            "垂眼",
            "喉结",
            "呼吸",
            "唇线",
            "眼眶",
            "嘴角",
            "下颌",
            "眉心",
            "欲言又止",
            "强忍泪意",
            "指尖",
        ]
        .iter()
        .any(|keyword| note.contains(keyword));
    let has_voice_signal = ["轻声", "低声", "哽咽", "呢喃", "短促", "颤声", "鼻音"]
        .iter()
        .any(|keyword| note.contains(keyword));

    has_performance_signal && has_voice_signal
}

pub(super) fn memory_style_anchor_char_breakdown(anchors: &[String]) -> (usize, usize) {
    let mut visual_chars = 0usize;
    let mut delivery_chars = 0usize;

    for anchor in anchors {
        for fragment in split_prompt_note_fragments(anchor) {
            match style_note_fragment_family(&fragment) {
                Some("表演") | Some("语气") => delivery_chars += fragment.chars().count(),
                _ => visual_chars += fragment.chars().count(),
            }
        }
    }

    (visual_chars, delivery_chars)
}

pub(super) fn memory_anchor_total_chars_within_budget(
    all_style_anchors: &[String],
    next_memory_anchor: &str,
    memory_anchor_count: usize,
    max_chars: usize,
) -> bool {
    let current_memory_chars = all_style_anchors
        .iter()
        .rev()
        .take(memory_anchor_count)
        .map(|anchor| anchor.chars().count())
        .sum::<usize>();
    current_memory_chars + next_memory_anchor.chars().count() <= max_chars
}

pub(super) fn memory_style_anchor_is_complementary(note: &str, anchors: &[String]) -> bool {
    let note_fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    if note_fragments.is_empty() {
        return false;
    }
    let existing_fragments = anchors
        .iter()
        .flat_map(|anchor| split_prompt_note_fragments(anchor))
        .collect::<Vec<_>>();
    !note_fragments.iter().all(|fragment| {
        prompt_fragment_is_covered(fragment, &existing_fragments)
            || style_note_matches_shared_keyword_family(
                fragment,
                &existing_fragments
                    .iter()
                    .map(String::as_str)
                    .collect::<Vec<_>>(),
                PERFORMANCE_SHARED_KEYWORD_FAMILIES,
            )
    })
}

pub(super) fn compact_project_art_style_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }

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

pub(super) fn compact_memory_style_anchor(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    allow_prompt_covered_style_fragments: bool,
    memory_budget_tier: VideoPromptMemoryBudgetTier,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let has_base_motion_style_anchor = prompt_coverage
        .iter()
        .any(|fragment| fragment.starts_with("动作") && generic_motion_style_fragment(fragment));
    let expected_camera = structured_fields.map(|fields| {
        [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<String>()
    });
    let fragments = normalized
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| style_fragment_prefix(fragment))
        .filter_map(|fragment| {
            if let Some(fields) = structured_fields {
                return trim_style_fragment_against_storyboard_fields(&fragment, fields);
            }
            Some(fragment)
        })
        .filter_map(|fragment| {
            trim_style_fragment_against_prompt_coverage(&fragment, prompt_coverage)
        })
        .filter(|fragment| {
            structured_fields
                .is_none_or(|fields| !style_fragment_lags_current_emotional_turn(fragment, fields))
        })
        .filter(|fragment| {
            structured_fields
                .is_none_or(|fields| !style_fragment_is_low_gain_mood_carryover(fragment, fields))
        })
        .filter(|fragment| {
            !memory_style_fragment_should_yield_to_negative_pressure(
                fragment,
                structured_fields,
                constraint_pressure,
            )
        })
        .filter(|fragment| {
            !(has_base_motion_style_anchor
                && fragment.starts_with("动作")
                && generic_motion_style_fragment(fragment))
        })
        .filter(|fragment| {
            if let (Some(fields), Some(camera)) = (structured_fields, expected_camera.as_deref()) {
                if continuity_fragment_matches_fields(fragment, fields, camera)
                    && !(allow_prompt_covered_style_fragments
                        && style_fragment_matches_prompt_style_field(fragment, fields))
                {
                    return false;
                }
            }
            !style_fragment_or_body_is_semantically_covered(fragment, prompt_coverage)
                || structured_fields.is_some_and(|fields| {
                    allow_prompt_covered_style_fragments
                        && style_fragment_matches_prompt_style_field(fragment, fields)
                })
        })
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }

    let note = match memory_budget_tier {
        VideoPromptMemoryBudgetTier::Lean => select_best_memory_style_note_for_lean_tier(
            &fragments,
            structured_fields,
            constraint_pressure,
        )
        .map(|note| clip_prompt_fragment(&note, VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS))?,
        VideoPromptMemoryBudgetTier::Expanded => {
            clip_prompt_fragment(&fragments.join("，"), VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
        }
    };
    Some(note)
}

pub(super) fn select_best_memory_style_note_for_lean_tier(
    fragments: &[String],
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let best_single = fragments
        .iter()
        .max_by(|left, right| {
            score_memory_style_fragment_for_lean_tier(left, structured_fields, constraint_pressure)
                .cmp(&score_memory_style_fragment_for_lean_tier(
                    right,
                    structured_fields,
                    constraint_pressure,
                ))
                .then_with(|| right.chars().count().cmp(&left.chars().count()))
                .then_with(|| right.cmp(left))
        })
        .cloned()?;

    let Some(fields) = structured_fields else {
        return Some(best_single);
    };

    let pair_focus = if video_prompt_scene_needs_emotional_memory(fields) {
        Some(LeanMemoryPairFocus::Emotional)
    } else if video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure) {
        Some(LeanMemoryPairFocus::Dialogue)
    } else if video_prompt_scene_needs_identity_lighting_pair_memory(fields, constraint_pressure) {
        Some(LeanMemoryPairFocus::IdentityLighting)
    } else {
        None
    };
    let Some(pair_focus) = pair_focus else {
        return Some(best_single);
    };

    let best_pair = select_best_expressive_memory_pair_for_lean_tier(
        fragments,
        fields,
        constraint_pressure,
        pair_focus,
    );
    match best_pair {
        Some((pair, pair_score)) => {
            let single_score = score_memory_style_fragment_for_lean_tier(
                &best_single,
                structured_fields,
                constraint_pressure,
            );
            if pair_score > single_score {
                Some(pair)
            } else {
                Some(best_single)
            }
        }
        None => Some(best_single),
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum LeanMemoryPairFocus {
    Emotional,
    Dialogue,
    IdentityLighting,
}

pub(super) fn video_prompt_scene_needs_dialogue_performance_memory(
    fields: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    !storyboard_dialogue_is_empty(&fields.dialogue)
        && storyboard_supports_voice_style(fields)
        && (video_prompt_scene_needs_identity_memory(fields)
            || current_storyboard_is_fragile_emotional_turn(fields)
            || constraint_pressure.is_some_and(|pressure| {
                pressure.has_dialogue_guardrail || pressure.has_identity_guardrail
            }))
}

pub(super) fn video_prompt_scene_needs_identity_lighting_pair_memory(
    fields: &StructuredStoryboardDescription,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    video_prompt_scene_needs_identity_memory(fields)
        && video_prompt_scene_has_lighting_risk(fields)
        && constraint_pressure.is_some_and(|pressure| {
            pressure.has_identity_guardrail || pressure.has_lighting_guardrail
        })
}

pub(super) fn score_memory_style_fragment_for_lean_tier(
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
    }
    if let Some(pressure) = constraint_pressure {
        score += score_memory_fragment_against_constraint_pressure(fragment, family, pressure);
    }

    score
}

pub(super) fn score_memory_style_note_for_expanded_tier(
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
    score
}

pub(super) fn score_memory_fragment_against_constraint_pressure(
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

pub(super) fn memory_fragment_has_high_signal_voice_detail(fragment: &str) -> bool {
    ["气息", "换气", "哽咽", "发颤", "尾音", "压低"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

pub(super) fn memory_style_fragment_should_yield_to_negative_pressure(
    fragment: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    let Some(pressure) = constraint_pressure.filter(|pressure| pressure.has_active_guardrail())
    else {
        return false;
    };

    let normalized = normalize_prompt_text(fragment);
    let family = style_note_fragment_family(&normalized);
    match family {
        Some("情绪") => {
            (pressure.has_emotion_guardrail || pressure.has_identity_guardrail)
                && mood_fragment_is_generic_carryover(
                    normalize_prompt_text(normalized.trim_start_matches("情绪")).as_str(),
                )
        }
        Some("语气") => {
            if structured_fields.is_some_and(|fields| !storyboard_supports_voice_style(fields)) {
                return true;
            }
            !memory_fragment_has_high_signal_voice_detail(&normalized)
                && (pressure.has_dialogue_guardrail
                    || pressure.has_emotion_guardrail
                    || pressure.has_identity_guardrail)
        }
        Some("声场") => {
            pressure.has_dialogue_guardrail
                || pressure.has_motion_guardrail
                || pressure.has_emotion_guardrail
                || pressure.has_identity_guardrail
        }
        Some("环境") => {
            pressure.has_identity_guardrail
                || pressure.has_lighting_guardrail
                    && !["反光", "逆光", "霓虹", "雨丝", "玻璃", "水痕", "影"]
                        .iter()
                        .any(|keyword| normalized.contains(keyword))
        }
        Some("动作") => {
            (pressure.has_motion_guardrail || pressure.has_identity_guardrail)
                && generic_motion_style_fragment(&normalized)
        }
        Some("镜头") => {
            pressure.has_blocking_guardrail && is_local_framing_only_fragment(&normalized)
        }
        _ => false,
    }
}

pub(super) fn style_fragment_is_low_gain_mood_carryover(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    if fragment.starts_with("语气") {
        if !storyboard_supports_voice_style(fields) {
            return false;
        }

        let body = normalize_prompt_text(fragment.trim_start_matches("语气"));
        return !body.is_empty()
            && body
                .split(['，', ',', '；', ';', '、', '/', ' '])
                .map(normalize_prompt_text)
                .filter(|part| !part.is_empty())
                .all(|part| voice_fragment_token_is_generic_mood_carryover(part.as_str()));
    }

    if fragment.starts_with("情绪") {
        let body = normalize_prompt_text(fragment.trim_start_matches("情绪"));
        return mood_fragment_is_generic_carryover(body.as_str());
    }

    fragment.starts_with("动作")
        && !video_prompt_scene_has_motion_risk(fields)
        && generic_motion_style_fragment(fragment)
}

pub(super) fn voice_fragment_token_is_generic_mood_carryover(token: &str) -> bool {
    matches!(
        token,
        "克制" | "平静" | "冷静" | "沉静" | "从容" | "隐忍" | "压抑"
    )
}

pub(super) fn mood_fragment_is_generic_carryover(body: &str) -> bool {
    matches!(
        body,
        "克制"
            | "隐忍"
            | "压抑"
            | "平静"
            | "冷静"
            | "沉静"
            | "从容"
            | "隐忍克制"
            | "克制隐忍"
            | "压抑克制"
            | "克制压抑"
            | "平静克制"
            | "克制平静"
            | "冷静克制"
            | "克制冷静"
    )
}

pub(super) fn score_memory_fragment_human_performance_detail(
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
            for keyword in [
                "气息", "换气", "哽咽", "发颤", "尾音", "压低", "轻声", "低声",
            ] {
                if normalized.contains(keyword) {
                    score += 2;
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

pub(super) fn score_compacted_style_note_against_constraint_pressure(
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
    if style_note_contains_family(note, "光影") && pressure.has_lighting_guardrail {
        score += 4;
    }
    if style_note_contains_family(note, "动作") && pressure.has_motion_guardrail {
        score += 3;
    }

    score
}

pub(super) fn style_note_contains_family(note: &str, family: &str) -> bool {
    split_prompt_note_fragments(note)
        .any(|fragment| style_note_fragment_family(&fragment) == Some(family))
}

pub(super) fn select_best_expressive_memory_pair_for_lean_tier(
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
                    LeanMemoryPairFocus::Emotional => 8,
                    LeanMemoryPairFocus::IdentityLighting => 0,
                };
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

pub(super) fn trim_style_fragment_against_storyboard_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    if fragment.starts_with("镜头") {
        return trim_prefixed_style_fragment(
            fragment,
            "镜头",
            &[fields.shot.as_str(), fields.camera_move.as_str()],
        );
    }
    if fragment.starts_with("情绪") {
        return trim_prefixed_style_fragment(fragment, "情绪", &[fields.mood.as_str()]);
    }
    if fragment.starts_with("光影") {
        return trim_prefixed_style_fragment(fragment, "光影", &[fields.lighting.as_str()]);
    }
    if fragment.starts_with("环境") {
        return trim_prefixed_style_fragment(
            fragment,
            "环境",
            &[
                fields.setting.as_str(),
                fields.action.as_str(),
                fields.sound.as_str(),
            ],
        );
    }
    if fragment.starts_with("动作") {
        let trimmed = trim_prefixed_style_fragment(
            fragment,
            "动作",
            &[fields.action.as_str(), fields.mood.as_str()],
        );
        return trim_style_fragment_by_shared_mood_keywords(trimmed, "动作", &fields.mood);
    }
    if fragment.starts_with("表演") {
        let trimmed = trim_prefixed_style_fragment(
            fragment,
            "表演",
            &[
                fields.action.as_str(),
                fields.dialogue.as_str(),
                fields.mood.as_str(),
            ],
        );
        let trimmed = trim_style_fragment_by_shared_performance_keywords(
            trimmed,
            "表演",
            &[fields.action.as_str(), fields.dialogue.as_str()],
        );
        let trimmed = if trimmed.is_none()
            && video_prompt_scene_needs_identity_memory(fields)
            && style_note_matches_shared_keyword_family(
                fragment,
                &[fields.action.as_str(), fields.dialogue.as_str()],
                PERFORMANCE_SHARED_KEYWORD_FAMILIES,
            ) {
            Some(fragment.to_string())
        } else {
            trimmed
        };
        return trim_style_fragment_by_shared_mood_keywords(trimmed, "表演", &fields.mood);
    }
    if fragment.starts_with("语气") {
        if !storyboard_supports_voice_style(fields) {
            return None;
        }
        let trimmed = trim_prefixed_style_fragment(
            fragment,
            "语气",
            &[
                fields.action.as_str(),
                fields.dialogue.as_str(),
                fields.mood.as_str(),
            ],
        );
        let trimmed = trim_style_fragment_by_shared_voice_keywords(
            trimmed,
            "语气",
            &[fields.action.as_str(), fields.dialogue.as_str()],
        );
        return trim_style_fragment_by_shared_mood_keywords(trimmed, "语气", &fields.mood);
    }
    if fragment.starts_with("声场") {
        let trimmed = trim_prefixed_style_fragment(
            fragment,
            "声场",
            &[
                fields.sound.as_str(),
                fields.setting.as_str(),
                fields.action.as_str(),
            ],
        );
        return match trimmed {
            Some(compacted)
                if compacted
                    .strip_prefix("声场")
                    .is_some_and(sound_stage_fragment_too_generic_after_trim) =>
            {
                Some(fragment.to_string())
            }
            other => other,
        };
    }
    Some(fragment.to_string())
}

pub(super) fn sound_stage_fragment_too_generic_after_trim(body: &str) -> bool {
    matches!(
        normalize_prompt_text(body).as_str(),
        "回响" | "回荡" | "空响" | "闷响" | "轻响" | "回声" | "贴近" | "摩擦" | "留白"
    )
}

pub(super) fn trim_prefixed_style_fragment(
    fragment: &str,
    prefix: &str,
    fields: &[&str],
) -> Option<String> {
    let body = fragment.strip_prefix(prefix).unwrap_or(fragment).trim();
    if body.is_empty() {
        return None;
    }

    let mut trimmed = body.to_string();
    for field in fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
    {
        trimmed = trimmed.replace(&field, "");
    }
    let trimmed = trimmed
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    ',' | '，' | ';' | '；' | ':' | '：' | '/' | '／' | '、' | '|' | '-' | ' '
                )
        })
        .to_string();
    if trimmed.is_empty() {
        None
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub(super) fn trim_style_fragment_against_prompt_coverage(
    fragment: &str,
    prompt_coverage: &[String],
) -> Option<String> {
    let Some((prefix, body)) = style_fragment_prefix_and_body(fragment) else {
        return Some(fragment.to_string());
    };
    if !matches!(prefix, "表演" | "语气") {
        return Some(fragment.to_string());
    }

    let mut trimmed = body.clone();
    let mut candidates = prompt_coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));
    candidates.dedup();

    for candidate in candidates {
        if candidate.chars().count() < 2 || !trimmed.contains(&candidate) {
            continue;
        }
        let residual = normalize_prompt_text(&trimmed.replace(&candidate, ""));
        if residual.chars().count() >= 2 {
            trimmed = residual;
        }
    }

    let trimmed = normalize_prompt_text(&trimmed);
    if trimmed.is_empty() {
        None
    } else if trimmed == body {
        Some(fragment.to_string())
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub(super) fn trim_style_fragment_by_shared_mood_keywords(
    fragment: Option<String>,
    prefix: &str,
    mood: &str,
) -> Option<String> {
    let fragment = fragment?;
    let body = fragment
        .strip_prefix(prefix)
        .unwrap_or(fragment.as_str())
        .trim();
    if body.is_empty() {
        return None;
    }

    let normalized_mood = normalize_prompt_text(mood);
    if normalized_mood.is_empty() {
        return Some(fragment);
    }

    let mut trimmed = body.to_string();
    for keyword in ["克制", "隐忍", "压抑", "平静", "冷静", "从容", "沉静"] {
        if !normalized_mood.contains(keyword) || !trimmed.contains(keyword) {
            continue;
        }
        let candidate = normalize_prompt_text(&trimmed.replace(keyword, ""));
        if candidate.chars().count() >= 2 {
            trimmed = candidate;
        }
    }

    if trimmed == body {
        return Some(fragment);
    }
    if trimmed.is_empty() {
        None
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub(super) const VOICE_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["低声", "压低声音", "低低开口"],
    &["轻声", "轻轻开口", "轻轻说道"],
    &["呢喃", "喃喃", "喃喃道", "喃喃说"],
    &["哽咽", "带着哽意", "声音发哽"],
    &["短促", "短促开口", "短促出声"],
];

pub(super) const SOUND_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["雨声", "雨滴声", "雨丝声", "雨点击窗"],
    &["风声", "风响", "风掠过", "风穿堂"],
    &["呼吸", "喘息", "呼吸声", "气息"],
    &["脚步", "足音", "步声", "脚步声"],
    &["门轴", "门响", "敲门", "开门声", "关门声", "门被推开"],
];

pub(super) fn trim_style_fragment_by_shared_voice_keywords(
    fragment: Option<String>,
    prefix: &str,
    fields: &[&str],
) -> Option<String> {
    trim_fragment_by_shared_keyword_families(
        fragment,
        prefix,
        fields,
        VOICE_SHARED_KEYWORD_FAMILIES,
    )
}

pub(super) fn trim_style_fragment_by_shared_performance_keywords(
    fragment: Option<String>,
    prefix: &str,
    fields: &[&str],
) -> Option<String> {
    trim_fragment_by_shared_keyword_families(
        fragment,
        prefix,
        fields,
        PERFORMANCE_SHARED_KEYWORD_FAMILIES,
    )
}

pub(super) const PERFORMANCE_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["欲言又止", "欲说还休"],
    &["抬眼", "抬眸", "抬起眼"],
    &["停顿", "顿住", "停了停"],
    &["迟疑", "犹疑", "犹豫"],
    &["回头", "回眸", "回身看"],
    &["看向", "望向", "望着", "看着", "注视"],
    &["唇线收紧", "抿唇", "嘴唇抿紧", "唇角绷紧", "嘴角绷紧"],
    &["眉心轻蹙", "蹙眉", "眉头轻蹙", "眉心微蹙"],
];

pub(super) fn trim_director_performance_fragment_against_storyboard_fields(
    fragment: &str,
    fields: &[&str],
) -> Option<String> {
    trim_fragment_by_shared_keyword_families(
        Some(fragment.to_string()),
        "",
        fields,
        PERFORMANCE_SHARED_KEYWORD_FAMILIES,
    )
}

pub(super) fn trim_fragment_by_shared_keyword_families(
    fragment: Option<String>,
    prefix: &str,
    fields: &[&str],
    families: &[&[&str]],
) -> Option<String> {
    let fragment = fragment?;
    let body = if prefix.is_empty() {
        fragment.trim()
    } else {
        fragment
            .strip_prefix(prefix)
            .unwrap_or(fragment.as_str())
            .trim()
    };
    if body.is_empty() {
        return None;
    }

    let normalized_fields = fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
        .collect::<Vec<_>>();
    if normalized_fields.is_empty() {
        return Some(fragment);
    }

    let mut trimmed = body.to_string();
    for family in families {
        if !family.iter().any(|keyword| trimmed.contains(keyword))
            || !normalized_fields
                .iter()
                .any(|field| family.iter().any(|keyword| field.contains(keyword)))
        {
            continue;
        }
        let candidate = family
            .iter()
            .fold(trimmed.clone(), |acc, keyword| acc.replace(keyword, ""));
        let candidate = normalize_prompt_text(&candidate);
        if candidate.is_empty() {
            trimmed = candidate;
            break;
        }
        if candidate.chars().count() >= 2 {
            trimmed = candidate;
        }
    }

    if trimmed == body {
        return Some(fragment);
    }
    if trimmed.is_empty() {
        None
    } else if prefix.is_empty() {
        Some(trimmed)
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub(super) fn style_fragment_matches_prompt_style_field(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    (!fields.mood.is_empty() && style_fragment_semantically_covers_field(fragment, &fields.mood))
        || (!fields.lighting.is_empty()
            && style_fragment_semantically_covers_field(fragment, &fields.lighting))
        || (fragment.starts_with("表演")
            && ((!fields.action.is_empty()
                && style_fragment_semantically_covers_field(fragment, &fields.action))
                || (!fields.dialogue.is_empty()
                    && style_fragment_semantically_covers_field(fragment, &fields.dialogue))
                || (!fields.mood.is_empty()
                    && style_fragment_semantically_covers_field(fragment, &fields.mood))))
        || (fragment.starts_with("语气")
            && ((!fields.action.is_empty()
                && style_fragment_semantically_covers_field(fragment, &fields.action))
                || (!fields.dialogue.is_empty()
                    && style_fragment_semantically_covers_field(fragment, &fields.dialogue))
                || (!fields.mood.is_empty()
                    && style_fragment_semantically_covers_field(fragment, &fields.mood))))
}

pub(super) fn style_fragment_prefix(fragment: &str) -> bool {
    [
        "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
    ]
    .iter()
    .any(|prefix| fragment.starts_with(prefix))
}

pub(super) fn style_fragment_prefix_and_body(fragment: &str) -> Option<(&'static str, String)> {
    [
        "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
    ]
    .iter()
    .find_map(|prefix| {
        fragment
            .strip_prefix(prefix)
            .map(normalize_prompt_text)
            .filter(|body| !body.is_empty())
            .map(|body| (*prefix, body))
    })
}

pub(super) fn style_fragment_body(fragment: &str) -> Option<String> {
    style_fragment_prefix_and_body(fragment).map(|(_, body)| body)
}

pub(super) fn generic_motion_style_fragment(fragment: &str) -> bool {
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

pub(super) fn style_fragment_or_body_is_semantically_covered(
    fragment: &str,
    coverage: &[String],
) -> bool {
    style_fragment_is_semantically_covered(fragment, coverage)
        || style_fragment_body(fragment)
            .as_deref()
            .is_some_and(|body| prompt_fragment_is_covered(body, coverage))
}

pub(super) fn style_fragment_is_semantically_covered(fragment: &str, coverage: &[String]) -> bool {
    continuity_fragment_is_semantically_covered(fragment, coverage)
}

pub(super) fn continuity_fragment_is_semantically_covered(
    fragment: &str,
    coverage: &[String],
) -> bool {
    if prompt_fragment_is_covered(fragment, coverage) {
        return true;
    }

    let canonical_fragment = canonical_continuity_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }

    coverage.iter().any(|existing| {
        let canonical_existing = canonical_continuity_fragment(existing);
        !canonical_existing.is_empty()
            && (canonical_existing == canonical_fragment
                || (canonical_fragment.chars().count() >= 4
                    && canonical_existing.contains(&canonical_fragment))
                || (canonical_existing.chars().count() >= 4
                    && canonical_fragment.contains(&canonical_existing)))
    })
}

pub(super) fn build_script_role_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_role_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let subject = structured_fields
        .map(|fields| normalize_prompt_text(&fields.subject))
        .unwrap_or_default();
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let subject_refs = structured_fields
        .map(structured_subject_ref_names)
        .unwrap_or_default();
    let role_anchor_limit = if subject_refs.len() > 1 {
        VIDEO_PROMPT_MULTI_ROLE_ANCHOR_LIMIT.min(subject_refs.len())
    } else {
        1
    };
    let mut scored = Vec::new();
    for (idx, anchor) in ctx.script_role_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Role,
        ) else {
            continue;
        };
        let score = score_script_asset_anchor(&name, &description, &subject, &action)
            + score_subject_ref_match(&name, &subject_refs);
        if name.is_empty() || score <= 0 {
            continue;
        }
        scored.push((score, idx, anchor));
    }
    select_script_asset_anchors(scored, role_anchor_limit)
}

pub(super) fn build_script_scene_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_scene_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let setting = structured_fields
        .map(|fields| normalize_prompt_text(&fields.setting))
        .unwrap_or_default();
    let setting_refs = structured_fields
        .map(structured_setting_ref_names)
        .unwrap_or_default();
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let mut scored = Vec::new();
    let mut directly_referenced_anchor_count = 0usize;
    for (idx, anchor) in ctx.script_scene_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Scene,
        ) else {
            continue;
        };
        let ref_match_score =
            score_scene_ref_match(&name, &description, &setting, &setting_refs, &action);
        let score =
            score_script_asset_anchor(&name, &description, &setting, &action) + ref_match_score;
        if name.is_empty() || score <= 0 {
            continue;
        }
        if ref_match_score > 0 {
            directly_referenced_anchor_count += 1;
        }
        scored.push((score, idx, anchor));
    }
    let scene_anchor_limit = if directly_referenced_anchor_count > 1 {
        VIDEO_PROMPT_MULTI_SCENE_ANCHOR_LIMIT.min(directly_referenced_anchor_count)
    } else {
        1
    };
    select_script_asset_anchors(scored, scene_anchor_limit)
}

pub(super) fn build_script_tool_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_tool_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let subject = structured_fields
        .map(|fields| normalize_prompt_text(&fields.subject))
        .unwrap_or_default();
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let subject_refs = structured_fields
        .map(structured_subject_ref_names)
        .unwrap_or_default();
    let mut scored = Vec::new();
    let mut directly_referenced_anchor_count = 0usize;
    for (idx, anchor) in ctx.script_tool_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Tool,
        ) else {
            continue;
        };
        let ref_match_score = score_subject_ref_match(&name, &subject_refs);
        let score =
            score_script_asset_anchor(&name, &description, &subject, &action) + ref_match_score;
        if name.is_empty() || score <= 0 {
            continue;
        }
        if ref_match_score > 0 {
            directly_referenced_anchor_count += 1;
        }
        scored.push((score, idx, anchor));
    }
    let tool_anchor_limit = if directly_referenced_anchor_count > 1 {
        VIDEO_PROMPT_MULTI_TOOL_ANCHOR_LIMIT.min(directly_referenced_anchor_count)
    } else {
        1
    };
    select_script_asset_anchors(scored, tool_anchor_limit)
}

pub(super) fn score_script_asset_anchor(
    name: &str,
    description: &str,
    primary: &str,
    secondary: &str,
) -> i32 {
    if name.is_empty() {
        return 0;
    }
    let mut score = 0;
    let primary_head = primary
        .split(['/', '／', '、', '，', ',', ' '])
        .map(normalize_prompt_text)
        .find(|part| !part.is_empty());
    if primary_head.as_deref() == Some(name) {
        score += 160;
    }
    if !primary.is_empty() && primary == name {
        score += 120;
    } else if !primary.is_empty() && (primary.contains(name) || name.contains(primary)) {
        score += 96;
        if primary.starts_with(name) {
            score += 96;
        }
        if let Some(idx) = primary.find(name) {
            score += 24 - idx.min(24) as i32;
        }
    }
    if !secondary.is_empty() && secondary.contains(name) {
        score += 48;
        if let Some(idx) = secondary.find(name) {
            score += 12 - idx.min(12) as i32;
        }
    }
    if !description.is_empty() && description.contains(name) {
        score += 36;
        if let Some(idx) = description.find(name) {
            score += 8 - idx.min(8) as i32;
        }
    }
    score - name.chars().count() as i32
}

pub(super) fn score_subject_ref_match(name: &str, subject_refs: &[String]) -> i32 {
    if name.is_empty() {
        return 0;
    }

    subject_refs
        .iter()
        .enumerate()
        .find_map(|(idx, subject_ref)| {
            (subject_ref == name || subject_ref.contains(name) || name.contains(subject_ref))
                .then_some(220 - (idx.min(4) as i32 * 8))
        })
        .unwrap_or(0)
}

pub(super) fn score_scene_ref_match(
    name: &str,
    description: &str,
    setting: &str,
    setting_refs: &[String],
    action: &str,
) -> i32 {
    if name.is_empty() {
        return 0;
    }

    let mut best = setting_refs
        .iter()
        .enumerate()
        .find_map(|(idx, setting_ref)| {
            (setting_ref == name || setting_ref.contains(name) || name.contains(setting_ref))
                .then_some(220 - (idx.min(4) as i32 * 8))
        })
        .unwrap_or(0);
    for suffix in scene_anchor_suffix_candidates(name) {
        let Some(prefix) = name.strip_suffix(&suffix).map(normalize_prompt_text) else {
            continue;
        };
        let prefix_matches_context = !prefix.is_empty()
            && [description, setting, action]
                .into_iter()
                .any(|field| field.contains(&prefix));
        if !prefix_matches_context {
            continue;
        }
        if setting.contains(&suffix) {
            best = best.max(120 - suffix.chars().count() as i32);
        }
        if action.contains(&suffix) {
            best = best.max(72 - suffix.chars().count() as i32);
        }
        if description.contains(&suffix) {
            best = best.max(48 - suffix.chars().count() as i32);
        }
    }
    best
}

pub(super) fn scene_anchor_suffix_candidates(name: &str) -> Vec<String> {
    let normalized = normalize_prompt_text(name);
    if normalized.chars().count() < 4 {
        return Vec::new();
    }

    let chars = normalized.chars().collect::<Vec<_>>();
    let mut suffixes = Vec::new();
    for len in 2..=4 {
        if chars.len() <= len {
            continue;
        }
        let suffix = chars[chars.len() - len..].iter().collect::<String>();
        if scene_anchor_suffix_looks_specific(&suffix)
            && !suffixes.iter().any(|existing| existing == &suffix)
        {
            suffixes.push(suffix);
        }
    }
    suffixes
}

pub(super) fn scene_anchor_suffix_looks_specific(suffix: &str) -> bool {
    !suffix.is_empty()
        && [
            "门厅", "走廊", "街口", "巷口", "门口", "楼梯", "楼道", "雨巷", "包间", "车内", "车门",
            "客厅", "卧室", "仓库", "天台", "屋顶", "尽头",
        ]
        .iter()
        .any(|keyword| suffix.ends_with(keyword))
}

pub(super) fn structured_subject_ref_names(
    fields: &StructuredStoryboardDescription,
) -> Vec<String> {
    fields
        .subject_refs
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut refs, value| {
            if !refs.iter().any(|existing| existing == &value) {
                refs.push(value);
            }
            refs
        })
}

pub(super) fn structured_setting_ref_names(
    fields: &StructuredStoryboardDescription,
) -> Vec<String> {
    fields
        .setting
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut refs, value| {
            if !refs.iter().any(|existing| existing == &value) {
                refs.push(value);
            }
            refs
        })
}

pub(super) fn select_script_asset_anchors(
    mut scored: Vec<(i32, usize, String)>,
    limit: usize,
) -> Vec<String> {
    if limit == 0 {
        return Vec::new();
    }
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    let mut selected = Vec::new();
    for (_, _, anchor) in scored {
        if selected.iter().any(|existing| existing == &anchor) {
            continue;
        }
        selected.push(anchor);
        if selected.len() >= limit {
            break;
        }
    }
    selected
}

#[derive(Debug, Clone, Copy)]
pub(super) enum ScriptAssetAnchorKind {
    Role,
    Scene,
    Tool,
}

pub(super) fn compact_selected_script_asset_anchor(
    name: &str,
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    kind: ScriptAssetAnchorKind,
) -> Option<String> {
    let normalized_name = normalize_prompt_text(name);
    if normalized_name.is_empty() {
        return None;
    }
    if script_asset_anchor_note_is_generic_placeholder(note) {
        return None;
    }

    let mut fragments = note
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_script_asset_anchor_fragment_against_storyboard_fields(
                fragment,
                structured_fields,
                kind,
            )
        })
        .filter(|fragment| {
            !script_asset_anchor_fragment_is_covered(
                fragment,
                structured_fields,
                prompt_coverage,
                kind,
            )
        })
        .collect::<Vec<_>>();
    fragments.dedup();

    if fragments.is_empty() {
        return None;
    }

    Some(format!("{normalized_name}:{}", fragments.join("，")))
}

pub(super) fn script_asset_anchor_note_is_generic_placeholder(note: &str) -> bool {
    matches!(
        normalize_prompt_text(note).as_str(),
        "视觉设定延续" | "场景设定延续" | "道具设定延续"
    )
}

pub(super) fn script_asset_anchor_fragment_is_covered(
    fragment: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    kind: ScriptAssetAnchorKind,
) -> bool {
    if prompt_fragment_is_covered(fragment, prompt_coverage) {
        return true;
    }

    let Some(fields) = structured_fields else {
        return false;
    };
    match kind {
        ScriptAssetAnchorKind::Role => fragment_mostly_repeats_prompt_mood(fragment, &fields.mood),
        ScriptAssetAnchorKind::Scene | ScriptAssetAnchorKind::Tool => false,
    }
}

pub(super) fn trim_script_asset_anchor_fragment_against_storyboard_fields(
    fragment: String,
    structured_fields: Option<&StructuredStoryboardDescription>,
    kind: ScriptAssetAnchorKind,
) -> Option<String> {
    let Some(fields) = structured_fields else {
        return Some(fragment);
    };

    let mut trimmed = fragment;
    for field in script_asset_anchor_overlap_fields(fields, kind) {
        trimmed = trim_fragment_by_exact_field_overlap(&trimmed, field)?;
    }
    Some(trimmed)
}

pub(super) fn script_asset_anchor_overlap_fields(
    fields: &StructuredStoryboardDescription,
    kind: ScriptAssetAnchorKind,
) -> Vec<&str> {
    let mut overlap_fields = match kind {
        ScriptAssetAnchorKind::Role => vec![fields.subject.as_str(), fields.action.as_str()],
        ScriptAssetAnchorKind::Scene => vec![fields.setting.as_str()],
        ScriptAssetAnchorKind::Tool => Vec::new(),
    };
    overlap_fields.push(fields.mood.as_str());
    overlap_fields.push(fields.lighting.as_str());
    overlap_fields
}

pub(super) fn trim_fragment_by_exact_field_overlap(fragment: &str, field: &str) -> Option<String> {
    let normalized_fragment = normalize_prompt_text(fragment);
    let normalized_field = normalize_prompt_text(field);
    if normalized_fragment.is_empty() || normalized_field.is_empty() {
        return Some(normalized_fragment);
    }
    if !normalized_fragment.contains(&normalized_field) {
        return Some(normalized_fragment);
    }

    let residual = normalize_prompt_text(&normalized_fragment.replace(&normalized_field, ""));
    if residual.chars().count() <= 2 {
        None
    } else {
        Some(residual)
    }
}

pub(super) fn fragment_mostly_repeats_prompt_mood(fragment: &str, mood: &str) -> bool {
    let fragment = normalize_prompt_text(fragment);
    let mood = normalize_prompt_text(mood);
    if fragment.is_empty() || mood.is_empty() || !fragment.contains(&mood) {
        return false;
    }

    let residual = fragment.replace(&mood, "");
    normalize_prompt_text(&residual).chars().count() <= 2
}

pub(super) fn build_continuity_notes(
    context: Option<&VideoPromptContext>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    memory_budget_tier: VideoPromptMemoryBudgetTier,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Vec<String> {
    let mut notes = context
        .map(|ctx| {
            ctx.continuity_notes
                .iter()
                .filter_map(|note| {
                    compact_continuity_note(note, structured_fields, prompt_coverage)
                })
                .filter(|note| continuity_note_matches_storyboard_risk(note, structured_fields))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    notes.sort_by(|a, b| {
        continuity_note_pressure_score(b, constraint_pressure)
            .cmp(&continuity_note_pressure_score(a, constraint_pressure))
            .then(score_continuity_specificity(b).cmp(&score_continuity_specificity(a)))
            .then(
                score_continuity_note(b, structured_fields)
                    .cmp(&score_continuity_note(a, structured_fields)),
            )
            .then(a.len().cmp(&b.len()))
            .then(a.cmp(b))
    });
    if let Some(pressure) = constraint_pressure.filter(|pressure| pressure.forces_compact_memory) {
        let has_guardrail_specific_note = notes
            .iter()
            .any(|note| continuity_note_pressure_score(note, Some(pressure)) > 0);
        if has_guardrail_specific_note {
            notes.retain(|note| continuity_note_pressure_score(note, Some(pressure)) > 0);
        }
    }
    match memory_budget_tier {
        VideoPromptMemoryBudgetTier::Expanded => {
            notes.truncate(VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT);
        }
        VideoPromptMemoryBudgetTier::Lean => {
            notes.retain(|note| continuity_note_is_lean_critical(note));
            notes
                .retain(|note| note.chars().count() <= VIDEO_PROMPT_LEAN_CONTINUITY_NOTE_MAX_CHARS);
            notes.truncate(1);
        }
    }
    notes
}

pub(super) fn continuity_note_is_lean_critical(note: &str) -> bool {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() || !continuity_note_adds_specific_guidance(&normalized) {
        return false;
    }

    ["跳轴", "视线", "构图", "方向", "站位", "走位", "前后景"]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}

pub(super) fn video_prompt_scene_has_axis_risk(fields: &StructuredStoryboardDescription) -> bool {
    let has_dialogue = storyboard_has_meaningful_spoken_dialogue(fields);
    let subject_count = video_prompt_scene_subject_count(fields);
    if has_dialogue && subject_count > 1 {
        return true;
    }

    [
        fields.action.as_str(),
        fields.mood.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "对视", "对峙", "回头", "转身", "逼近", "靠近", "擦肩", "并肩", "交错", "相望",
                "互看",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(super) fn video_prompt_scene_subject_count(fields: &StructuredStoryboardDescription) -> usize {
    let subject_refs = structured_subject_ref_names(fields);
    if !subject_refs.is_empty() {
        return subject_refs.len();
    }

    fields
        .subject
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut subjects, value| {
            if !subjects.iter().any(|existing| existing == &value) {
                subjects.push(value);
            }
            subjects
        })
        .len()
}

pub(super) fn video_prompt_scene_has_blocking_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    if video_prompt_scene_has_motion_risk(fields) || video_prompt_scene_has_axis_risk(fields) {
        return true;
    }

    normalize_prompt_text(&fields.action)
        .split(['，', ',', '；', ';', '。', '\n'])
        .any(|fragment| {
            [
                "停步", "站定", "侧身", "让开", "绕过", "穿过", "退后", "后退",
            ]
            .iter()
            .any(|keyword| fragment.contains(keyword))
        })
}

pub(super) fn continuity_note_matches_storyboard_risk(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> bool {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return false;
    }
    let Some(fields) = structured_fields else {
        return true;
    };
    if continuity_note_mentions_axis_risk(&normalized) {
        return video_prompt_scene_has_axis_risk(fields);
    }
    if continuity_note_mentions_blocking_risk(&normalized) {
        return video_prompt_scene_has_blocking_risk(fields);
    }
    if continuity_note_adds_specific_guidance(&normalized) {
        return video_prompt_scene_has_motion_risk(fields)
            || video_prompt_scene_has_axis_risk(fields)
            || video_prompt_scene_has_blocking_risk(fields);
    }
    if continuity_note_mentions_dialogue_risk(&normalized) {
        return storyboard_has_meaningful_spoken_dialogue(fields);
    }
    if continuity_note_mentions_emotional_risk(&normalized) {
        return video_prompt_scene_needs_emotional_memory(fields);
    }
    if continuity_note_mentions_lighting_risk(&normalized) {
        return video_prompt_scene_has_lighting_risk(fields);
    }
    if continuity_note_mentions_motion_risk(&normalized) {
        return video_prompt_scene_has_motion_risk(fields);
    }
    false
}

pub(super) fn continuity_note_mentions_axis_risk(note: &str) -> bool {
    ["跳轴", "视线", "方向", "构图"]
        .iter()
        .any(|keyword| note.contains(keyword))
}

pub(super) fn continuity_note_mentions_blocking_risk(note: &str) -> bool {
    ["站位", "走位", "位置", "前后景"]
        .iter()
        .any(|keyword| note.contains(keyword))
}

pub(super) fn continuity_note_mentions_dialogue_risk(note: &str) -> bool {
    [
        "对白", "台词", "口型", "语气", "旁白", "voice", "dialogue", "lip-sync",
    ]
    .iter()
    .any(|keyword| note.contains(keyword))
}

pub(super) fn continuity_note_mentions_emotional_risk(note: &str) -> bool {
    [
        "情绪", "压迫", "冷峻", "悲怆", "克制", "隐忍", "急迫", "停顿", "哽咽", "表演", "状态",
    ]
    .iter()
    .any(|keyword| note.contains(keyword))
}

pub(super) fn continuity_note_mentions_lighting_risk(note: &str) -> bool {
    [
        "光", "影", "逆光", "反光", "曝光", "闪烁", "霓虹", "玻璃", "雨", "灯",
    ]
    .iter()
    .any(|keyword| note.contains(keyword))
}

pub(super) fn continuity_note_mentions_motion_risk(note: &str) -> bool {
    [
        "跟拍", "推进", "拉远", "手持", "运镜", "抖动", "动作", "节奏", "转身", "快步",
    ]
    .iter()
    .any(|keyword| note.contains(keyword))
}

pub(super) fn continuity_fragment_matches_constraint_pressure(
    fragment: &str,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    continuity_note_pressure_score(fragment, constraint_pressure) > 0
}

pub(super) fn continuity_note_pressure_score(
    note: &str,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let Some(pressure) = constraint_pressure else {
        return 0;
    };
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return 0;
    }

    let mentions_axis = continuity_note_mentions_axis_risk(&normalized);
    let mentions_blocking = continuity_note_mentions_blocking_risk(&normalized);
    let mentions_dialogue = continuity_note_mentions_dialogue_risk(&normalized);
    let mentions_emotion = continuity_note_mentions_emotional_risk(&normalized);
    let mentions_lighting = continuity_note_mentions_lighting_risk(&normalized);
    let mentions_motion = continuity_note_mentions_motion_risk(&normalized);

    let mut score = 0;
    if pressure.has_dialogue_guardrail {
        if mentions_dialogue {
            score += 24;
        }
        if mentions_axis {
            score += 18;
        }
    }
    if pressure.has_identity_guardrail {
        if mentions_axis || mentions_blocking {
            score += 18;
        }
        if mentions_lighting {
            score += 12;
        }
    }
    if pressure.has_blocking_guardrail {
        if mentions_blocking {
            score += 22;
        }
        if mentions_motion {
            score += 12;
        }
    }
    if pressure.has_motion_guardrail {
        if mentions_motion {
            score += 20;
        }
        if mentions_blocking {
            score += 10;
        }
    }
    if pressure.has_lighting_guardrail && mentions_lighting {
        score += 20;
    }
    if pressure.has_emotion_guardrail {
        if mentions_emotion {
            score += 18;
        }
        if mentions_dialogue {
            score += 8;
        }
    }
    score
}

pub(super) fn compact_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let Some(fields) = structured_fields else {
        let clipped = clip_prompt_fragment(&normalized, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
        return (!prompt_fragment_is_covered(&clipped, prompt_coverage)).then_some(clipped);
    };

    let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<String>();
    let fragments = normalized
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_continuity_fragment_against_storyboard_fields(&fragment, fields)
        })
        .map(|fragment| compact_continuity_fragment_wording(&fragment))
        .filter(|fragment| !fragment.is_empty())
        .map(|fragment| {
            trim_continuity_fragment_against_prompt_coverage(&fragment, prompt_coverage)
        })
        .filter(|fragment| {
            let normalized_core = continuity_fragment_core(fragment);
            !continuity_fragment_matches_fields(fragment, fields, &expected_camera)
                && !continuity_fragment_is_generic_quality_tail_overlap(fragment)
                && !continuity_fragment_is_semantically_covered(fragment, prompt_coverage)
                && normalized_core.as_deref().is_none_or(|core| {
                    !continuity_fragment_is_semantically_covered(core, prompt_coverage)
                })
        })
        .collect::<Vec<_>>();

    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

pub(super) fn compact_continuity_fragment_wording(fragment: &str) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    for (from, to) in [
        ("人物站位不要跳轴", "站位不要跳轴"),
        ("角色站位不要跳轴", "站位不要跳轴"),
        ("人物站位连续", "站位连续"),
        ("角色站位连续", "站位连续"),
        ("人物走位连续", "走位连续"),
        ("角色走位连续", "走位连续"),
        ("人物视线方向一致", "视线方向一致"),
        ("角色视线方向一致", "视线方向一致"),
        ("镜头方向连续", "方向连续"),
        ("人物动作节奏", "动作节奏"),
        ("角色动作节奏", "动作节奏"),
        ("人物前后景", "前后景"),
        ("角色前后景", "前后景"),
    ] {
        compacted = compacted.replace(from, to);
    }

    if compacted.contains("不要") {
        for prefix in ["保持", "保留", "延续"] {
            if let Some(stripped) = compacted.strip_prefix(prefix) {
                compacted = normalize_prompt_text(stripped);
                break;
            }
        }
    }

    normalize_prompt_text(&compacted)
}

pub(super) fn trim_continuity_fragment_against_prompt_coverage(
    fragment: &str,
    prompt_coverage: &[String],
) -> String {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return normalized;
    }

    let trimmed = strip_leading_covered_prompt_fragment(&normalized, prompt_coverage);
    if trimmed == normalized || trimmed.is_empty() {
        return normalized;
    }

    if continuity_fragment_still_specific_after_coverage_trim(&trimmed) {
        trimmed
    } else {
        normalized
    }
}

pub(super) fn continuity_fragment_still_specific_after_coverage_trim(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return false;
    }

    [
        "保持", "保留", "延续", "走位", "站位", "方向", "构图", "衔接", "连续", "统一", "一致",
        "跳轴",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

pub(super) fn trim_continuity_fragment_against_storyboard_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return None;
    }

    let (prefix, body) = continuity_fragment_prefix_and_body(&normalized);
    let mut trimmed = body.to_string();
    for field in [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.mood.as_str(),
        fields.lighting.as_str(),
        fields.setting.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .filter(|field| !field.is_empty())
    {
        trimmed = trimmed.replace(&field, "");
    }
    trimmed = trim_continuity_fragment_storyboard_lead_in(&trimmed, fields);
    let trimmed = trimmed
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    ',' | '，' | ';' | '；' | ':' | '：' | '/' | '／' | '、' | '|' | '-' | ' '
                )
        })
        .to_string();
    if trimmed.is_empty()
        || ["镜头", "情绪", "光影", "场景"]
            .iter()
            .any(|prefix| trimmed == *prefix)
    {
        None
    } else if prefix.is_empty() {
        Some(trimmed)
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub(super) fn trim_continuity_fragment_storyboard_lead_in(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> String {
    const CONTINUITY_LEAD_ROLE_PREFIXES: [&str; 10] = [
        "主角", "女主", "男主", "反派", "女孩", "男孩", "女人", "男人", "老人", "孩子",
    ];
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    for field in [fields.subject.as_str(), fields.action.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .filter(|field| !field.is_empty())
    {
        let candidate = compacted.replace(&field, "");
        let candidate = candidate
            .trim_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ',' | '，' | ';' | '；' | ':' | '：' | '/' | '／' | '、' | '|' | '-' | ' '
                    )
            })
            .to_string();
        if candidate.is_empty()
            || !candidate.contains("上一镜头")
                && ![
                    "保持", "延续", "衔接", "连续", "一致", "统一", "方向", "构图",
                ]
                .iter()
                .any(|keyword| candidate.contains(keyword))
        {
            continue;
        }
        compacted = candidate;
    }

    loop {
        let mut changed = false;
        for prefix in CONTINUITY_LEAD_ROLE_PREFIXES {
            let Some(stripped) = compacted.strip_prefix(prefix) else {
                continue;
            };
            let candidate = stripped
                .trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                        )
                })
                .to_string();
            if candidate.is_empty()
                || !candidate.contains("上一镜头")
                    && ![
                        "保持", "延续", "衔接", "连续", "一致", "统一", "方向", "构图",
                    ]
                    .iter()
                    .any(|keyword| candidate.contains(keyword))
            {
                continue;
            }
            compacted = candidate;
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(super) fn continuity_fragment_core(fragment: &str) -> Option<String> {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return None;
    }
    [
        "保持上一镜头已确认的",
        "保持上一镜头已确认",
        "保留上一镜头已确认的",
        "保留上一镜头已确认",
        "延续上一镜头已确认的",
        "延续上一镜头已确认",
        "保持上一镜头的",
        "保留上一镜头的",
        "延续上一镜头的",
        "保持上一镜头",
        "保留上一镜头",
        "延续上一镜头",
        "保持",
        "保留",
        "延续",
    ]
    .into_iter()
    .find_map(|prefix| {
        normalized
            .strip_prefix(prefix)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string)
    })
}

pub(super) fn continuity_fragment_prefix_and_body(fragment: &str) -> (String, String) {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return (String::new(), String::new());
    }
    for prefix in [
        "保持上一镜头已确认的",
        "保持上一镜头已确认",
        "保留上一镜头已确认的",
        "保留上一镜头已确认",
        "延续上一镜头已确认的",
        "延续上一镜头已确认",
        "保持上一镜头的",
        "保留上一镜头的",
        "延续上一镜头的",
        "保持上一镜头",
        "保留上一镜头",
        "延续上一镜头",
        "保持",
        "保留",
        "延续",
    ] {
        if let Some(body) = normalized.strip_prefix(prefix).map(str::trim) {
            if !body.is_empty() {
                return (prefix.to_string(), body.to_string());
            }
        }
    }
    (String::new(), normalized)
}

pub(super) fn collect_prompt_coverage(
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Vec<String> {
    let Some(fields) = structured_fields else {
        return Vec::new();
    };
    let camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join(", ");
    [
        fields.subject.as_str(),
        fields.action.as_str(),
        fields.setting.as_str(),
        fields.mood.as_str(),
        fields.lighting.as_str(),
        camera.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .filter(|fragment| !fragment.is_empty())
    .collect()
}

pub(super) fn compact_subject_clause(
    subject: &str,
    asset_coverage: &[String],
    _prompt_coverage: &[String],
    action: Option<&str>,
) -> Option<String> {
    let subject = trim_subject_action_overlap(subject, action).unwrap_or_else(|| subject.into());
    let compacted =
        compact_prompt_clause(&subject, asset_coverage, None, PromptClauseKind::Subject)?;
    (!prompt_clause_key_is_covered_by_anchor(&compacted, asset_coverage)).then_some(compacted)
}

pub(super) fn compact_setting_clause(
    setting: &str,
    asset_coverage: &[String],
    prompt_coverage: &[String],
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let compacted = strip_prompt_setting_subject_prefix(setting, prompt_coverage);
    let compacted =
        strip_prompt_setting_context_prefix(&compacted, subject, action).unwrap_or(compacted);
    let compacted =
        compact_prompt_clause(&compacted, asset_coverage, None, PromptClauseKind::Setting)?;
    let compacted = normalize_prompt_clause_compaction(&compacted, PromptClauseKind::Setting);
    (!compacted.is_empty()
        && !prompt_clause_key_is_covered_by_anchor(&compacted, asset_coverage)
        && !prompt_fragment_has_direct_coverage(&compacted, asset_coverage)
        && !prompt_fragment_has_direct_coverage(&compacted, prompt_coverage))
    .then_some(compacted)
}

pub(super) fn compact_action_clause(
    action: &str,
    asset_coverage: &[String],
    _prompt_coverage: &[String],
    dialogue: Option<&str>,
    setting: Option<&str>,
) -> Option<String> {
    let compacted =
        compact_prompt_clause(action, asset_coverage, setting, PromptClauseKind::Action)?;

    let trimmed = dialogue
        .and_then(|line| strip_dialogue_covered_action_suffix(&compacted, line))
        .unwrap_or(compacted);
    (!trimmed.is_empty()).then_some(trimmed)
}

pub(super) fn compact_hidden_speech_action_clause(
    action: &str,
    dialogue: &str,
    fields: &StructuredStoryboardDescription,
    context: Option<&VideoPromptContext>,
) -> Option<String> {
    let prompt = context
        .and_then(|value| value.storyboard_prompt.as_deref())
        .unwrap_or_default();
    let canonical_dialogue = canonical_dialogue_fragment(dialogue);
    if canonical_dialogue.is_empty()
        || !dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech(
            &canonical_dialogue,
            fields,
            prompt,
        )
    {
        return Some(action.to_string());
    }

    strip_low_visibility_dialogue_payload_from_action(action, &canonical_dialogue)
        .or_else(|| Some(action.to_string()))
}

#[derive(Debug, Clone, Copy)]
pub(super) enum PromptClauseKind {
    Subject,
    Setting,
    Action,
}

pub(super) fn compact_prompt_clause(
    raw: &str,
    asset_coverage: &[String],
    setting: Option<&str>,
    kind: PromptClauseKind,
) -> Option<String> {
    let normalized = normalize_prompt_text(raw);
    if normalized.is_empty() || prompt_fragment_has_direct_coverage(&normalized, asset_coverage) {
        return None;
    }

    let mut compacted = strip_action_setting_prefix(&normalized, setting, kind);
    compacted = strip_leading_covered_prompt_fragment(&compacted, asset_coverage);
    compacted = strip_action_object_prefix(&compacted, asset_coverage, kind);
    compacted = normalize_prompt_clause_compaction(&compacted, kind);
    if compacted.is_empty() {
        return None;
    }
    Some(compacted)
}

pub(super) fn strip_action_object_prefix(
    fragment: &str,
    coverage: &[String],
    kind: PromptClauseKind,
) -> String {
    if !matches!(kind, PromptClauseKind::Action) {
        return fragment.to_string();
    }

    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 2 {
                continue;
            }
            for verb in ACTION_OBJECT_PREFIX_VERBS {
                let Some(stripped) = compacted.strip_prefix(verb) else {
                    continue;
                };
                let Some(stripped) = stripped.strip_prefix(candidate) else {
                    continue;
                };
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            ':' | '：'
                                | ';'
                                | '；'
                                | ','
                                | '，'
                                | '/'
                                | '／'
                                | '、'
                                | '的'
                                | '着'
                                | '后'
                        )
                });
                if stripped.chars().count() < 2 {
                    continue;
                }
                compacted = stripped.to_string();
                changed = true;
                break;
            }
            if changed {
                break;
            }
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(super) fn prompt_fragment_has_direct_coverage(fragment: &str, coverage: &[String]) -> bool {
    let canonical_fragment = canonical_prompt_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }
    coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .any(|existing| !existing.is_empty() && existing == canonical_fragment)
}

pub(super) fn prompt_clause_key_is_covered_by_anchor(fragment: &str, coverage: &[String]) -> bool {
    let canonical_fragment = canonical_prompt_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }

    coverage.iter().any(|entry| {
        entry.split_once(':').is_some_and(|(anchor_key, _)| {
            let canonical_anchor = canonical_prompt_fragment(anchor_key);
            !canonical_anchor.is_empty() && canonical_anchor == canonical_fragment
        })
    })
}

pub(super) fn strip_leading_covered_prompt_fragment(fragment: &str, coverage: &[String]) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 2 {
                continue;
            }
            let stripped = strip_prompt_prefix_candidate(&compacted, candidate);
            let Some(stripped) = stripped else { continue };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ':' | '：'
                            | ';'
                            | '；'
                            | ','
                            | '，'
                            | '/'
                            | '／'
                            | '、'
                            | '的'
                            | '在'
                            | '向'
                            | '朝'
                            | '往'
                            | '从'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(super) fn strip_prompt_prefix_candidate<'a>(
    fragment: &'a str,
    candidate: &str,
) -> Option<&'a str> {
    fragment.strip_prefix(candidate).or_else(|| {
        strip_prompt_leading_bridge(fragment).and_then(|value| value.strip_prefix(candidate))
    })
}

pub(super) fn strip_prompt_leading_bridge(fragment: &str) -> Option<&str> {
    let trimmed = fragment.trim_start();
    PROMPT_LEADING_BRIDGES
        .into_iter()
        .find_map(|prefix| trimmed.strip_prefix(prefix))
}

pub(super) fn strip_action_setting_prefix(
    fragment: &str,
    setting: Option<&str>,
    kind: PromptClauseKind,
) -> String {
    if !matches!(kind, PromptClauseKind::Action) {
        return fragment.to_string();
    }

    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = build_prompt_setting_prefix_candidates(setting);
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 4 {
                continue;
            }
            let Some(stripped) = strip_prompt_prefix_candidate(&compacted, candidate) else {
                continue;
            };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(super) fn strip_prompt_setting_subject_prefix(
    setting: &str,
    prompt_coverage: &[String],
) -> String {
    let mut compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return compacted;
    }

    let mut coverage = prompt_coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    coverage.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &coverage {
            if candidate.chars().count() < 2 || !compacted.starts_with(candidate) {
                continue;
            }
            let rest = compacted[candidate.len()..].trim_start();
            for suffix in SETTING_SUBJECT_LEAD_IN_SUFFIXES {
                let Some(stripped) = rest.strip_prefix(suffix) else {
                    continue;
                };
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                        )
                });
                if stripped.chars().count() < 2 {
                    continue;
                }
                compacted = stripped.to_string();
                changed = true;
                break;
            }
            if changed {
                break;
            }
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(super) fn strip_prompt_setting_context_prefix(
    setting: &str,
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return None;
    }

    let locative_lead_in = prompt_setting_locative_lead_in(&compacted)?;
    if locative_lead_in.chars().count() < 4 {
        return None;
    }

    let covered_by_context = subject
        .into_iter()
        .chain(action)
        .flat_map(prompt_context_variants)
        .any(|candidate| candidate.starts_with(&locative_lead_in));
    if !covered_by_context {
        return None;
    }

    let (_, suffix) = strip_prompt_setting_descriptive_lead_in(&compacted)?;
    let suffix = suffix.trim_start_matches(|ch: char| {
        ch.is_whitespace()
            || matches!(
                ch,
                '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
            )
    });
    (suffix.chars().count() >= 2).then(|| suffix.to_string())
}

pub(super) fn build_prompt_setting_prefix_candidates(setting: Option<&str>) -> Vec<String> {
    let mut candidates = Vec::new();
    let Some(setting) = setting
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    else {
        return candidates;
    };

    candidates.push(setting.clone());
    if let Some(stripped) = strip_prompt_leading_bridge(&setting) {
        candidates.push(stripped.to_string());
    }
    if let Some((prefix, _)) = strip_prompt_setting_descriptive_lead_in(&setting) {
        candidates.push(prefix.to_string());
        if let Some(stripped) = strip_prompt_leading_bridge(prefix) {
            candidates.push(stripped.to_string());
        }
    }
    candidates.sort();
    candidates.dedup();
    candidates
}

pub(super) fn prompt_setting_locative_lead_in(setting: &str) -> Option<String> {
    let normalized = normalize_prompt_text(setting);
    let (prefix, _) = strip_prompt_setting_descriptive_lead_in(&normalized)?;
    let prefix = strip_prompt_leading_bridge(prefix).unwrap_or(prefix);
    let prefix = normalize_prompt_text(prefix);
    (!prefix.is_empty()).then_some(prefix)
}

pub(super) fn strip_prompt_setting_descriptive_lead_in(setting: &str) -> Option<(&str, &str)> {
    let normalized = setting.trim();
    let split_at = normalized.find('的')?;
    let (prefix, suffix_with_marker) = normalized.split_at(split_at);
    let suffix = suffix_with_marker.strip_prefix('的')?;
    let prefix = prefix.trim();
    let suffix = suffix.trim();
    (!prefix.is_empty() && !suffix.is_empty()).then_some((prefix, suffix))
}

pub(super) fn prompt_context_variants(value: &str) -> Vec<String> {
    let normalized = normalize_prompt_text(value);
    if normalized.is_empty() {
        return Vec::new();
    }

    let mut variants = vec![normalized.clone()];
    if let Some(stripped) = strip_prompt_subject_role_prefix(&normalized) {
        variants.push(stripped.to_string());
        if let Some(bridge) = strip_prompt_leading_bridge(stripped) {
            variants.push(bridge.to_string());
        }
    }
    if let Some(stripped) = strip_prompt_leading_bridge(&normalized) {
        variants.push(stripped.to_string());
    }
    variants.sort();
    variants.dedup();
    variants
}

pub(super) fn strip_prompt_subject_role_prefix(value: &str) -> Option<&str> {
    ACTION_SUBJECT_PREFIXES.iter().find_map(|prefix| {
        value.strip_prefix(prefix).map(|stripped| {
            stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
            })
        })
    })
}

pub(super) fn trim_subject_action_overlap(subject: &str, action: Option<&str>) -> Option<String> {
    let subject = normalize_prompt_text(subject);
    let action = action.map(normalize_prompt_text).unwrap_or_default();
    if subject.is_empty() || action.is_empty() {
        return None;
    }

    let identity_tail = strip_prompt_subject_role_prefix(&subject)?;
    if identity_tail.chars().count() < 3 {
        return None;
    }

    for overlap_len in (3..=identity_tail.chars().count().min(12)).rev() {
        let overlap = identity_tail.chars().take(overlap_len).collect::<String>();
        if overlap.chars().count() < 3 || !action.contains(&overlap) {
            continue;
        }
        let Some(trimmed) = subject.strip_suffix(&overlap) else {
            continue;
        };
        let trimmed = normalize_prompt_clause_compaction(trimmed, PromptClauseKind::Subject);
        if trimmed.chars().count() < 2
            || canonical_prompt_fragment(&trimmed) == canonical_prompt_fragment(&subject)
        {
            continue;
        }
        return Some(trimmed);
    }

    None
}

pub(super) fn normalize_prompt_clause_compaction(fragment: &str, kind: PromptClauseKind) -> String {
    let compacted = normalize_prompt_text(fragment)
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    ':' | '：' | ';' | '；' | ',' | '，' | '/' | '／' | '、' | '和' | '与'
                )
        })
        .to_string();
    if compacted.is_empty() {
        return compacted;
    }
    match kind {
        PromptClauseKind::Setting => compacted.trim_start_matches('的').to_string(),
        PromptClauseKind::Subject | PromptClauseKind::Action => compacted,
    }
}

pub(super) fn strip_dialogue_covered_action_suffix(action: &str, dialogue: &str) -> Option<String> {
    let canonical_dialogue = canonical_dialogue_fragment(dialogue);
    if canonical_dialogue.is_empty() {
        return None;
    }

    let normalized_action = normalize_prompt_text(action);
    if normalized_action.is_empty() {
        return None;
    }

    for speech_prefix in [
        "低声说",
        "轻声说",
        "小声说",
        "喃喃道",
        "喃喃说",
        "呢喃",
        "说道",
        "说出",
        "说",
        "喊道",
        "喊出",
        "大喊",
        "呼喊",
        "叫喊",
        "质问",
        "回答",
        "回应",
        "重复",
    ] {
        let patterns = [
            format!("并{speech_prefix}{canonical_dialogue}"),
            format!("后{speech_prefix}{canonical_dialogue}"),
            format!("再{speech_prefix}{canonical_dialogue}"),
            format!("{speech_prefix}{canonical_dialogue}"),
        ];
        for pattern in patterns {
            let Some(prefix) = normalized_action.strip_suffix(&pattern) else {
                continue;
            };
            let normalized_prefix = normalize_prompt_text(prefix);
            let trimmed = normalized_prefix.trim_end_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ',' | '，' | ';' | '；' | ':' | '：' | '、' | '并' | '后' | '再'
                    )
            });
            if trimmed.chars().count() < 2 || action_fragment_is_speech_delivery_only(trimmed) {
                continue;
            }
            return Some(trimmed.to_string());
        }
    }

    None
}

pub(super) fn strip_low_visibility_dialogue_payload_from_action(
    action: &str,
    canonical_dialogue: &str,
) -> Option<String> {
    let normalized_action = normalize_prompt_text(action);
    if normalized_action.is_empty() || canonical_dialogue.is_empty() {
        return None;
    }

    for speech_prefix in [
        "低声说",
        "轻声说",
        "小声说",
        "喃喃道",
        "喃喃说",
        "呢喃",
        "说道",
        "说出",
        "说",
        "喊道",
        "喊出",
        "大喊",
        "呼喊",
        "叫喊",
        "质问",
        "回答",
        "回应",
        "重复",
    ] {
        let patterns = [
            format!("并{speech_prefix}{canonical_dialogue}"),
            format!("后{speech_prefix}{canonical_dialogue}"),
            format!("再{speech_prefix}{canonical_dialogue}"),
            format!("{speech_prefix}{canonical_dialogue}"),
        ];
        for pattern in patterns {
            let Some(prefix) = normalized_action.strip_suffix(&pattern) else {
                continue;
            };
            let normalized_prefix = normalize_prompt_text(prefix);
            let trimmed = normalized_prefix.trim_end_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ',' | '，' | ';' | '；' | ':' | '：' | '、' | '并' | '后' | '再'
                    )
            });
            if trimmed.chars().count() >= 2 && !action_fragment_is_speech_delivery_only(trimmed) {
                return Some(trimmed.to_string());
            }

            return compact_low_visibility_speech_delivery(trimmed, speech_prefix);
        }
    }

    None
}

pub(super) fn compact_low_visibility_speech_delivery(
    fragment: &str,
    speech_prefix: &str,
) -> Option<String> {
    let normalized = normalize_prompt_text(fragment);
    if !normalized.is_empty() && !action_fragment_is_speech_delivery_only(&normalized) {
        return None;
    }

    Some(
        if speech_prefix.contains("低声") || speech_prefix.contains("小声") {
            "低声开口"
        } else if speech_prefix.contains("轻声") {
            "轻声开口"
        } else if speech_prefix.contains("喃喃") || speech_prefix.contains("呢喃") {
            "呢喃开口"
        } else if speech_prefix.contains("喊") {
            "急喊示意"
        } else if speech_prefix == "质问" {
            "开口质问"
        } else if speech_prefix == "回答" || speech_prefix == "回应" {
            "开口回应"
        } else if speech_prefix == "重复" {
            "重复示意"
        } else {
            "开口示意"
        }
        .to_string(),
    )
}

pub(super) fn action_fragment_is_speech_delivery_only(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && [
            "低声",
            "轻声",
            "小声",
            "喃喃",
            "呢喃",
            "压低声音",
            "提高嗓门",
        ]
        .iter()
        .any(|value| normalized == *value)
}

pub(super) fn prompt_clauses_substantially_overlap(lhs: Option<&str>, rhs: Option<&str>) -> bool {
    let Some(lhs) = lhs
        .map(canonical_prompt_fragment)
        .filter(|value| !value.is_empty())
    else {
        return false;
    };
    let Some(rhs) = rhs
        .map(canonical_prompt_fragment)
        .filter(|value| !value.is_empty())
    else {
        return false;
    };
    lhs == rhs
        || (lhs.chars().count() >= 6 && rhs.contains(&lhs))
        || (rhs.chars().count() >= 6 && lhs.contains(&rhs))
}

pub(super) fn extend_prompt_coverage(target: &mut Vec<String>, anchors: &[String]) {
    for anchor in anchors {
        for fragment in expand_prompt_coverage_fragments(anchor) {
            if target.iter().any(|existing| existing == &fragment) {
                continue;
            }
            target.push(fragment);
        }
    }
}

pub(super) fn expand_prompt_coverage_fragments(anchor: &str) -> Vec<String> {
    let mut fragments = Vec::new();
    for fragment in anchor
        .split([':', '：', ';', '；', ',', '，'])
        .map(normalize_prompt_text)
    {
        if fragment.is_empty() || fragments.iter().any(|existing| existing == &fragment) {
            continue;
        }
        fragments.push(fragment);
    }
    fragments
}

pub(super) fn prompt_fragment_is_covered(fragment: &str, coverage: &[String]) -> bool {
    let canonical_fragment = canonical_prompt_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }
    coverage.iter().any(|existing| {
        let canonical_existing = canonical_prompt_fragment(existing);
        if canonical_existing.is_empty() {
            return false;
        }
        canonical_existing == canonical_fragment
            || (canonical_fragment.chars().count() >= 4
                && canonical_existing.contains(&canonical_fragment))
            || (canonical_existing.chars().count() >= 4
                && canonical_fragment.contains(&canonical_existing))
    })
}

pub(super) fn prompt_style_field_is_covered(field: &str, coverage: &[String]) -> bool {
    prompt_fragment_is_covered(field, coverage)
        || coverage
            .iter()
            .any(|fragment| style_fragment_semantically_covers_field(fragment, field))
}

pub(super) fn style_fragment_semantically_covers_field(fragment: &str, field: &str) -> bool {
    let canonical_field = canonical_prompt_fragment(field);
    if canonical_field.is_empty() {
        return false;
    }

    let canonical_fragment = canonical_continuity_fragment(fragment);
    if canonical_fragment.is_empty() || !canonical_fragment.contains(&canonical_field) {
        return false;
    }

    let trimmed = canonical_style_field_fragment(&canonical_fragment);
    !trimmed.is_empty()
        && (trimmed == canonical_field
            || (trimmed.contains(&canonical_field)
                && normalize_prompt_text(&trimmed.replace(&canonical_field, "")).is_empty()))
}

pub(super) fn canonical_style_field_fragment(fragment: &str) -> String {
    [
        "风格",
        "质感",
        "氛围",
        "情绪",
        "光影",
        "色调",
        "影调",
        "气质",
        "颗粒",
        "电影感",
        "感",
    ]
    .into_iter()
    .fold(normalize_prompt_text(fragment), |acc, token| {
        acc.replace(token, "")
    })
}

pub(super) fn canonical_prompt_fragment(fragment: &str) -> String {
    normalize_prompt_text(fragment)
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ':' | '：' | ';' | '；' | ',' | '，' | '.' | '。')
        })
        .to_string()
}

pub(super) fn compact_project_director_note(
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

pub(super) fn project_director_fragment_is_redundant_with_reserved_style_anchors(
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
                && reserved_style_anchors
                    .iter()
                    .any(|anchor| anchor.starts_with("表演"))
        })
}

pub(super) fn project_director_mood_fragment_is_generic_carryover(mood: &str) -> bool {
    matches!(
        normalize_prompt_text(mood).as_str(),
        "克制" | "隐忍" | "压抑" | "沉静" | "冷静" | "隐忍克制" | "克制隐忍"
    )
}

pub(super) fn compact_project_director_fragment_language(fragment: &str) -> String {
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

pub(super) fn strip_generic_director_continuity_subfragments(fragment: &str) -> String {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return normalized;
    }

    let separated = ["并且", "同时", "以及", "并", "且"]
        .into_iter()
        .fold(normalized.clone(), |acc, needle| acc.replace(needle, "，"));
    let kept = separated
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .filter(|part| !project_director_fragment_is_generic_quality_tail_overlap(part))
        .collect::<Vec<_>>();
    if kept.is_empty() {
        normalized
    } else {
        kept.join("，")
    }
}

pub(super) fn project_director_fragment_is_generic_visual_placeholder(fragment: &str) -> bool {
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

pub(super) fn trim_project_director_fragment_against_storyboard_fields(
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

pub(super) fn score_project_director_fragment(
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

pub(super) struct ScriptAssetPromptAnchor {
    pub(super) asset_type: String,
    pub(super) value: String,
}

pub(super) fn compact_script_asset_anchor(
    row: ScriptRolePromptSeedRow,
) -> Option<ScriptAssetPromptAnchor> {
    let asset_type = normalize_prompt_text(&row.asset_type).to_lowercase();
    let max_chars = match asset_type.as_str() {
        "role" => 24,
        "scene" => 22,
        "tool" => 20,
        _ => return None,
    };
    let name = row
        .name
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text: &String| !text.is_empty())?;
    let describe = row
        .describe
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text: &String| !text.is_empty())
        .map(|text| clip_prompt_fragment(&text, max_chars))?;
    Some(ScriptAssetPromptAnchor {
        asset_type,
        value: format!("{name}: {describe}"),
    })
}

pub(super) fn project_director_fragment_relevant(fragment: &str) -> bool {
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

pub(super) fn continuity_fragment_matches_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    expected_camera: &str,
) -> bool {
    let canonical = canonical_continuity_fragment(fragment);
    if canonical.is_empty() {
        return false;
    }
    canonical == fields.subject
        || canonical == fields.action
        || (!expected_camera.is_empty()
            && (canonical == expected_camera
                || canonical == fields.shot
                || canonical == fields.camera_move
                || (!fields.shot.is_empty() && canonical.contains(&fields.shot))
                || (!fields.camera_move.is_empty() && canonical.contains(&fields.camera_move))))
        || (!fields.mood.is_empty() && canonical == fields.mood)
        || (!fields.lighting.is_empty() && canonical == fields.lighting)
        || (!fields.setting.is_empty() && canonical == fields.setting)
}

pub(super) fn canonical_continuity_fragment(fragment: &str) -> String {
    let mut canonical = normalize_prompt_text(fragment);
    loop {
        let mut changed = false;
        for prefix in [
            "保持上一镜头",
            "延续上一镜头",
            "保留上一镜头",
            "保持",
            "延续",
            "保留",
            "镜头",
            "情绪",
            "光影",
            "场景",
            "环境",
            "动作",
            "表演",
            "语气",
            "声场",
        ] {
            if let Some(stripped) = canonical.strip_prefix(prefix) {
                canonical = stripped
                    .trim_start_matches(|ch: char| {
                        ch.is_whitespace() || matches!(ch, ':' | '：' | ';' | '；' | ',' | '，')
                    })
                    .to_string();
                changed = true;
                break;
            }
        }
        if !changed {
            break;
        }
    }
    canonical
}

pub(super) fn resolve_video_prompt_duration(
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

pub(super) fn looks_like_silence(text: &str) -> bool {
    let normalized = text.trim().to_lowercase();
    normalized.is_empty()
        || normalized == "无"
        || normalized == "无台词"
        || normalized == "无音效"
        || normalized == "none"
        || normalized == "no dialogue"
        || normalized == "no sound"
}

pub(super) fn compact_dialogue_clause(
    dialogue: &str,
    fields: Option<&StructuredStoryboardDescription>,
    context: Option<&VideoPromptContext>,
) -> Option<String> {
    let normalized = normalize_prompt_text(dialogue);
    if normalized.is_empty() || looks_like_silence(&normalized) {
        return None;
    }

    let compacted = canonical_dialogue_fragment(&normalized);
    if compacted.is_empty() {
        return Some(normalized);
    }

    let normalized_len = normalized.chars().count();
    let compacted_len = compacted.chars().count();
    let selected = if compacted_len >= 2 && normalized_len.saturating_sub(compacted_len) >= 2 {
        compacted
    } else {
        normalized
    };

    if dialogue_fragment_is_non_semantic_vocalization(&selected) {
        return None;
    }

    let prompt = context
        .and_then(|value| value.storyboard_prompt.as_deref())
        .unwrap_or_default();
    if fields.is_some_and(|fields| {
        dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech(
            &selected, fields, prompt,
        )
    }) {
        return None;
    }

    Some(selected)
}

pub(super) fn dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech(
    dialogue: &str,
    fields: &StructuredStoryboardDescription,
    prompt: &str,
) -> bool {
    if storyboard_has_visible_speech_performance_risk(fields, Some(prompt))
        || current_storyboard_is_fragile_emotional_turn(fields)
    {
        return false;
    }

    let normalized = canonical_dialogue_fragment(dialogue);
    if normalized.is_empty() {
        return true;
    }

    let char_count = normalized.chars().count();
    if char_count <= 4 {
        return true;
    }

    if video_prompt_scene_has_motion_risk(fields) && video_prompt_scene_subject_count(fields) > 1 {
        return char_count <= 6 && !dialogue_fragment_has_high_semantic_density(&normalized);
    }

    false
}

pub(super) fn dialogue_fragment_has_high_semantic_density(dialogue: &str) -> bool {
    let normalized = canonical_dialogue_fragment(dialogue);
    if normalized.is_empty() {
        return false;
    }

    if normalized.chars().count() >= 8 {
        return true;
    }

    [
        "为什么",
        "怎么",
        "不能",
        "不要",
        "必须",
        "一定",
        "马上",
        "终于",
        "已经",
        "真的",
        "不是",
        "别再",
        "快点",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

pub(super) fn dialogue_fragment_is_non_semantic_vocalization(value: &str) -> bool {
    let normalized = canonical_dialogue_fragment(value);
    if normalized.is_empty() {
        return false;
    }

    let mut residual = normalized;
    for fragment in [
        "急促",
        "短促",
        "轻微",
        "微弱",
        "低低",
        "沙哑",
        "压抑地",
        "压着",
        "颤抖着",
        "颤声",
        "轻声",
        "低声",
        "缓缓",
        "忍不住",
        "一声",
        "几声",
        "地",
        "着",
        "了",
    ] {
        residual = residual.replace(fragment, "");
    }
    for fragment in [
        "倒吸一口气",
        "呼吸声",
        "喘息",
        "喘气",
        "呼吸",
        "吸气",
        "叹息",
        "长叹",
        "闷哼",
        "呻吟",
        "哽咽",
        "抽泣",
        "啜泣",
        "惊呼",
        "尖叫",
        "低吼",
        "嘶吼",
        "呜咽",
    ] {
        residual = residual.replace(fragment, "");
    }
    for fragment in ["啊", "嗯", "呃", "哈", "哼", "唔", "呀", "哦"] {
        residual = residual.replace(fragment, "");
    }

    normalize_prompt_text(&residual).is_empty()
}

pub(super) fn compact_sound_clause(
    sound: &str,
    dialogue: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let normalized = normalize_prompt_text(sound);
    if normalized.is_empty() || looks_like_silence(&normalized) {
        return None;
    }

    let dialogue = dialogue
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty() && !looks_like_silence(value));
    let mut kept = Vec::new();
    for fragment in split_prompt_clause_fragments(&normalized) {
        if looks_like_silence(&fragment) {
            continue;
        }
        let fragment = compact_sound_fragment(&fragment);
        if fragment.is_empty() || looks_like_silence(&fragment) {
            continue;
        }
        if sound_fragment_is_low_signal_ambient(&fragment) {
            continue;
        }
        if dialogue
            .as_deref()
            .is_some_and(|line| sound_fragment_is_dialogue_covered(&fragment, line))
        {
            continue;
        }
        if action.is_some_and(|line| sound_fragment_is_action_covered(&fragment, line)) {
            continue;
        }
        if kept.iter().any(|existing| existing == &fragment) {
            continue;
        }
        kept.push(fragment);
    }

    if kept.is_empty() {
        None
    } else {
        Some(kept.join("，"))
    }
}

pub(super) fn compact_sound_fragment(fragment: &str) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    loop {
        let mut changed = false;
        for prefix in [
            "伴随",
            "伴着",
            "伴有",
            "夹杂着",
            "夹杂",
            "传来",
            "响起",
            "回荡着",
            "回荡",
            "只剩下",
            "只剩",
            "能听见",
            "听见",
            "可闻",
            "耳边传来",
            "空气里只剩",
        ] {
            let Some(stripped) = compacted.strip_prefix(prefix) else {
                continue;
            };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ':' | '：' | ';' | '；' | ',' | '，' | '/' | '／' | '、' | '的'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(super) fn split_prompt_clause_fragments(value: &str) -> Vec<String> {
    value
        .split(['，', ',', '；', ';', '。', '！', '!', '？', '?', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .collect()
}

pub(super) fn sound_fragment_is_dialogue_covered(fragment: &str, dialogue: &str) -> bool {
    let canonical_dialogue = canonical_dialogue_fragment(dialogue);
    if canonical_dialogue.is_empty() {
        return false;
    }
    let canonical_fragment = canonical_dialogue_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }

    speech_like_fragment(fragment)
        && (canonical_fragment == canonical_dialogue
            || canonical_fragment.contains(&canonical_dialogue)
            || canonical_dialogue.contains(&canonical_fragment))
}

pub(super) fn sound_fragment_is_action_covered(fragment: &str, action: &str) -> bool {
    let fragment = normalize_prompt_text(fragment);
    let action = normalize_prompt_text(action);
    if fragment.is_empty() || action.is_empty() {
        return false;
    }
    if sound_fragment_has_high_value_acoustic_detail(&fragment) {
        return false;
    }

    if sound_fragment_matches_footstep_action(&fragment, &action) {
        return true;
    }
    if sound_fragment_matches_door_action(&fragment, &action) {
        return true;
    }
    false
}

pub(super) fn sound_fragment_has_high_value_acoustic_detail(fragment: &str) -> bool {
    [
        "急促",
        "沉重",
        "细碎",
        "凌乱",
        "由远及近",
        "回响",
        "回荡",
        "吱呀",
        "砰",
        "轰",
        "巨响",
        "闷响",
        "脆响",
        "刺耳",
        "低鸣",
        "风声",
        "雨声",
        "滴答",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}

pub(super) fn sound_fragment_is_low_signal_ambient(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() || sound_fragment_has_high_value_acoustic_detail(&normalized) {
        return false;
    }

    let generic_ambient = [
        "背景音乐",
        "音乐渐起",
        "配乐渐起",
        "氛围音乐",
        "一片死寂",
        "四周死寂",
        "四周寂静",
        "周围寂静",
        "环境安静",
        "安静无声",
        "空气凝固",
        "气氛压抑",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword));
    if !generic_ambient {
        return false;
    }

    ![
        "风声", "雨声", "脚步", "足音", "门", "敲", "回响", "回荡", "滴答", "雷声", "水声",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

pub(super) fn sound_fragment_matches_footstep_action(fragment: &str, action: &str) -> bool {
    (fragment.contains("脚步") || fragment.contains("足音"))
        && [
            "走近", "逼近", "靠近", "走来", "奔来", "跑来", "冲来", "踏入", "闯入", "离开", "走开",
            "退开",
        ]
        .iter()
        .any(|keyword| action.contains(keyword))
}

pub(super) fn sound_fragment_matches_door_action(fragment: &str, action: &str) -> bool {
    let is_door_sound = [
        "敲门声",
        "敲门",
        "门响",
        "开门声",
        "关门声",
        "门被推开",
        "门被拉开",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword));
    is_door_sound
        && ["推门", "开门", "关门", "拉门", "夺门", "闯入"]
            .iter()
            .any(|keyword| action.contains(keyword))
}

pub(super) fn canonical_dialogue_fragment(value: &str) -> String {
    let mut canonical = normalize_prompt_text(value)
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    '"' | '\'' | '“' | '”' | '‘' | '’' | '「' | '」' | '『' | '』' | ':' | '：'
                )
        })
        .to_string();
    loop {
        let mut changed = false;
        for prefix in [
            "低声说",
            "轻声说",
            "小声说",
            "喃喃道",
            "喃喃说",
            "呢喃",
            "说道",
            "说出",
            "说",
            "喊道",
            "喊出",
            "大喊",
            "呼喊",
            "叫喊",
            "质问",
            "回答",
            "回应",
            "重复",
            "台词",
            "对白",
            "旁白",
        ] {
            if let Some(stripped) = canonical.strip_prefix(prefix) {
                canonical = stripped
                    .trim_start_matches(|ch: char| {
                        ch.is_whitespace()
                            || matches!(
                                ch,
                                '"' | '\''
                                    | '“'
                                    | '”'
                                    | '‘'
                                    | '’'
                                    | '「'
                                    | '」'
                                    | '『'
                                    | '』'
                                    | ':'
                                    | '：'
                            )
                    })
                    .to_string();
                changed = true;
                break;
            }
        }
        if !changed {
            break;
        }
    }
    canonical
}

pub(super) fn speech_like_fragment(fragment: &str) -> bool {
    [
        "说", "喊", "台词", "对白", "旁白", "低声", "轻声", "呢喃", "喃喃", "口播", "voice",
        "dialogue",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}

pub(super) fn select_video_prompt_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let structured_fields = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description);
    let seeded_match_exists = rows.iter().any(|row| {
        row.name == "auto_scope_memory"
            && auto_scope_memory_tool_matches_video_prompt(row.content.as_str())
            && memory_storyboard_overlap_score(row.content.as_str(), storyboard_numeric_id) > 0
            && memory_prompt_seed_matches(
                row.content.as_str(),
                storyboard_numeric_id,
                current_prompt_seed,
            )
    });
    let mut scored = rows
        .iter()
        .filter_map(|row| {
            if row.name != "auto_scope_memory" {
                return None;
            }
            let content = row.content.as_str();
            if !auto_scope_memory_tool_matches_video_prompt(content) {
                return None;
            }
            if !auto_scope_memory_matches_current_prompt_seed(
                content,
                storyboard_numeric_id,
                current_prompt_seed,
                seeded_match_exists,
            ) {
                return None;
            }
            let score = memory_storyboard_overlap_score(content, storyboard_numeric_id);
            if score <= 0 {
                return None;
            }
            let note = extract_key_value(content, "summary")
                .or_else(|| extract_key_value(content, "result"))
                .and_then(|value| {
                    compact_storyboard_memory_continuity_note(&value, structured_fields.as_ref())
                })
                .and_then(|value| compact_auto_scope_continuity_summary(&value))
                .or_else(|| {
                    extract_key_value(content, "summary")
                        .or_else(|| extract_key_value(content, "result"))
                        .and_then(|value| {
                            compact_auto_scope_continuity_summary(&clip_prompt_fragment(
                                &value,
                                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                            ))
                        })
                })?;
            let continuity_score = score_continuity_note(&note, structured_fields.as_ref());
            if continuity_score <= 0 {
                return None;
            }
            if !continuity_note_matches_storyboard_risk(&note, structured_fields.as_ref()) {
                return None;
            }
            let specificity_score = score_continuity_specificity(&note);
            Some((
                score + continuity_score + specificity_score,
                specificity_score,
                continuity_score,
                note,
            ))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then(b.0.cmp(&a.0))
            .then(b.2.cmp(&a.2))
            .then(a.3.len().cmp(&b.3.len()))
            .then(a.3.cmp(&b.3))
    });

    let mut notes = Vec::new();
    for (_, _, _, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT {
            break;
        }
    }
    notes
}

pub(super) fn auto_scope_memory_tool_matches_video_prompt(content: &str) -> bool {
    extract_key_value(content, "tool").is_some_and(|tool| {
        matches!(
            tool.as_str(),
            "run_sub_agent_storyboard_panel"
                | "run_sub_agent_storyboard_gen"
                | "run_sub_agent_production_supervision"
                | "run_sub_agent_director_plan"
        )
    })
}

pub(super) fn auto_scope_memory_matches_current_prompt_seed(
    content: &str,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    seeded_match_exists: bool,
) -> bool {
    match current_prompt_seed.filter(|seed| !seed.is_empty()) {
        Some(seed) => match memory_prompt_seed_for_storyboard(content, storyboard_numeric_id) {
            Some(candidate_seed) => candidate_seed == seed,
            None => !seeded_match_exists,
        },
        None => true,
    }
}

pub(super) fn compact_auto_scope_continuity_summary(note: &str) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }

    let fragments = split_prompt_note_fragments(&normalized)
        .map(|fragment| strip_auto_scope_continuity_scaffolding(&fragment))
        .map(|fragment| compact_continuity_fragment_wording(&fragment))
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();
    let fragments = compact_auto_scope_continuity_fragments(fragments);
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

pub(super) fn compact_auto_scope_continuity_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut kept = Vec::new();
    for fragment in fragments {
        if kept.iter().any(|existing| existing == &fragment) {
            continue;
        }
        kept.push(fragment);
    }

    let has_specific_guidance = kept
        .iter()
        .any(|fragment| continuity_note_adds_specific_guidance(fragment));
    kept.iter()
        .filter(|fragment| {
            !auto_scope_continuity_fragment_is_covered(fragment, &kept, has_specific_guidance)
        })
        .cloned()
        .collect()
}

pub(super) fn auto_scope_continuity_fragment_is_covered(
    candidate: &str,
    fragments: &[String],
    has_specific_guidance: bool,
) -> bool {
    if auto_scope_continuity_fragment_is_generic(candidate) && has_specific_guidance {
        return true;
    }

    let candidate_axis = auto_scope_continuity_axis(candidate);
    let candidate_specificity = score_continuity_specificity(candidate);
    fragments.iter().any(|other| {
        if other == candidate {
            return false;
        }
        let same_axis = candidate_axis != AutoScopeContinuityAxis::None
            && candidate_axis == auto_scope_continuity_axis(other);
        same_axis
            && score_continuity_specificity(other) > candidate_specificity
            && auto_scope_continuity_fragments_share_anchor(candidate, other)
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum AutoScopeContinuityAxis {
    None,
    Positioning,
    Rhythm,
}

pub(super) fn auto_scope_continuity_axis(fragment: &str) -> AutoScopeContinuityAxis {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return AutoScopeContinuityAxis::None;
    }
    if [
        "跳轴",
        "视线",
        "方向",
        "构图",
        "站位",
        "走位",
        "位置",
        "前后景",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return AutoScopeContinuityAxis::Positioning;
    }
    if ["节奏", "动作"]
        .iter()
        .any(|keyword| normalized.contains(keyword))
    {
        return AutoScopeContinuityAxis::Rhythm;
    }
    AutoScopeContinuityAxis::None
}

pub(super) fn auto_scope_continuity_fragments_share_anchor(left: &str, right: &str) -> bool {
    let left = normalize_prompt_text(left);
    let right = normalize_prompt_text(right);
    if left.is_empty() || right.is_empty() {
        return false;
    }
    [
        "跳轴",
        "视线",
        "方向",
        "构图",
        "站位",
        "走位",
        "位置",
        "前后景",
        "节奏",
        "动作",
    ]
    .iter()
    .any(|keyword| left.contains(keyword) && right.contains(keyword))
}

pub(super) fn auto_scope_continuity_fragment_is_generic(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && !continuity_note_adds_specific_guidance(&normalized)
        && ["衔接", "连续", "统一", "一致", "延续", "保持"]
            .iter()
            .any(|keyword| normalized.contains(keyword))
}

pub(super) fn strip_auto_scope_continuity_scaffolding(fragment: &str) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    for pattern in [
        "当前镜头已确认的",
        "当前分镜已确认的",
        "本镜头已确认的",
        "该镜头已确认的",
        "当前镜头已确认",
        "当前分镜已确认",
        "本镜头已确认",
        "该镜头已确认",
    ] {
        compacted = compacted.replace(pattern, "");
    }
    for pattern in ["当前镜头", "当前分镜", "本镜头", "该镜头"] {
        compacted = compacted.replace(pattern, "");
    }
    compacted = normalize_prompt_text(&compacted);
    if compacted == "已确认" || compacted == "镜头已确认" || compacted == "分镜已确认"
    {
        return String::new();
    }
    clip_prompt_fragment(&compacted, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
}

pub(super) fn compact_storyboard_memory_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Option<String> {
    let compacted = compact_video_continuity_note(note)?;
    let Some(fields) = structured_fields else {
        return Some(compacted);
    };

    let fragments = compacted
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_continuity_fragment_against_storyboard_fields(&fragment, fields)
        })
        .map(|fragment| compact_continuity_fragment_wording(&fragment))
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

pub(super) fn score_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> i32 {
    let mut score = 0;
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return score;
    }
    for fragment in split_prompt_note_fragments(&normalized) {
        if fragment.is_empty() {
            continue;
        }
        if fragment.contains("上一镜头") {
            score += 24;
        }
        if [
            "走位", "站位", "方向", "构图", "衔接", "连续", "延续", "保持", "统一",
        ]
        .iter()
        .any(|keyword| fragment.contains(keyword))
        {
            score += 12;
        }
        if ["镜头", "情绪", "光影", "场景"]
            .iter()
            .any(|prefix| fragment.starts_with(prefix))
        {
            score += 2;
        }
    }

    if let Some(fields) = structured_fields {
        let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<String>();
        for fragment in split_prompt_note_fragments(&normalized) {
            if fragment.is_empty() {
                continue;
            }
            if continuity_fragment_matches_fields(&fragment, fields, &expected_camera) {
                score -= 8;
            }
        }
    }

    score
}

pub(super) fn score_continuity_specificity(note: &str) -> i32 {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return 0;
    }

    normalized
        .split('，')
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .map(|fragment| {
            let mut score = 0;
            if fragment.contains("跳轴") {
                score += 20;
            }
            if ["视线", "构图", "方向"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 16;
            }
            if ["站位", "走位", "位置", "前后景"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 12;
            }
            if ["节奏", "动作"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 8;
            }
            score
        })
        .sum()
}

pub(super) fn memory_storyboard_overlap_score(row: &str, storyboard_numeric_id: i32) -> i32 {
    if storyboard_numeric_id <= 0 {
        return 0;
    }
    let key = "storyboardIds";
    let mut remainder = row;
    let mut score = 0;
    while let Some(found) = remainder.find(key) {
        let next = &remainder[found + key.len()..];
        let Some(after_equal) = next.strip_prefix('=') else {
            remainder = next;
            continue;
        };
        let ids = parse_csv_positive_ints(after_equal);
        if ids.contains(&storyboard_numeric_id) {
            score += 10;
        }
        remainder = after_equal;
    }
    score
}

pub(super) fn parse_csv_positive_ints(text: &str) -> Vec<i32> {
    let raw = text
        .chars()
        .take_while(|ch| ch.is_ascii_digit() || *ch == ',' || ch.is_ascii_whitespace())
        .collect::<String>();
    raw.split(',')
        .filter_map(|part| part.trim().parse::<i32>().ok())
        .filter(|value| *value > 0)
        .collect()
}
