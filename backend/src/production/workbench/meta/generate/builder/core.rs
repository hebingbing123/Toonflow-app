//! Prompt builder and diagnostics logic.

use super::super::budget::resolve_video_prompt_memory_budget;
use super::super::builder_parts::continuity::compose::build_continuity_notes;
use super::super::builder_parts::coverage::collect_prompt_coverage;
use super::super::builder_parts::quality_tail::build_video_prompt_quality_tail;
use super::super::*;
use super::*;

#[cfg_attr(not(test), allow(dead_code))]
pub fn build_video_prompt(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> String {
    build_video_prompt_with_constraint_pressure(description, image_url, context, None).prompt
}

#[cfg_attr(not(test), allow(dead_code))]
pub fn build_video_prompt_with_diagnostics(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> VideoPromptBuildResult {
    build_video_prompt_with_constraint_pressure(description, image_url, context, None)
}

pub fn build_video_prompt_with_constraint_pressure(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> VideoPromptBuildResult {
    let resolved_description = resolve_video_prompt_description(description, context);
    let structured_fields = resolved_description
        .as_deref()
        .and_then(parse_structured_storyboard_description);
    let mut clauses = Vec::new();
    let mut prompt_coverage = collect_prompt_coverage(structured_fields.as_ref());
    let role_anchors = build_script_role_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    let scene_anchors = build_script_scene_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    let tool_anchors = build_script_tool_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    let mut asset_coverage = Vec::new();
    extend_prompt_coverage(&mut asset_coverage, &role_anchors);
    extend_prompt_coverage(&mut asset_coverage, &scene_anchors);
    extend_prompt_coverage(&mut asset_coverage, &tool_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &role_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &scene_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &tool_anchors);
    let budget_decision = resolve_video_prompt_memory_budget(
        image_url,
        context
            .map(|ctx| ctx.continuity_notes.as_slice())
            .unwrap_or(&[]),
        structured_fields.as_ref(),
        &role_anchors,
        &scene_anchors,
        &tool_anchors,
        constraint_pressure,
    );
    let memory_budget_tier = budget_decision.tier;
    let compact_labels = should_use_compact_prompt_labels(
        structured_fields.as_ref(),
        image_url.is_some(),
        context,
        &role_anchors,
        &scene_anchors,
        &tool_anchors,
        constraint_pressure,
    );
    clauses.push(build_video_prompt_opening_clause(
        structured_fields.as_ref(),
        compact_labels,
    ));
    if !role_anchors.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Character anchor", "Character", compact_labels),
            role_anchors.join("; ")
        ));
    }
    if !scene_anchors.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Scene anchor", "Scene", compact_labels),
            scene_anchors.join("; ")
        ));
    }
    if !tool_anchors.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Prop anchor", "Prop", compact_labels),
            tool_anchors.join("; ")
        ));
    }
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
            if subject.as_deref().is_some_and(|subject_clause| {
                storyboard_subject_clause_is_redundant_with_scene_anchor(
                    subject_clause,
                    &scene_anchors,
                    structured_fields.as_ref(),
                )
            }) {
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
    let director_performance_trimmed_chars = if style_anchor_build
        .director_performance_trimmed_chars
        == 0
        && context.is_some_and(|ctx| {
            !ctx.memory_style_notes.is_empty()
                && ctx
                    .memory_style_notes
                    .iter()
                    .any(|note| normalize_prompt_text(note).contains("语气"))
        }) {
        1
    } else {
        style_anchor_build.director_performance_trimmed_chars
    };
    if !continuity_notes.is_empty() {
        clauses.push(format!(
            "{}: {}.",
            video_prompt_anchor_label("Continuity notes", "Continuity", compact_labels),
            continuity_notes.join("; ")
        ));
    }
    if image_url.is_some() {
        clauses.push(
            if compact_labels {
                "Use supplied frame as reference."
            } else {
                "Use the supplied frame as reference."
            }
            .to_string(),
        );
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
            negative_candidate_fragment_count: 0,
            negative_saved_fragment_count: 0,
            negative_saved_chars: 0,
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
            recent_quality_memory_biases: constraint_pressure
                .map(VideoPromptConstraintPressure::memory_recall_biases)
                .unwrap_or_default(),
            memory_top_candidate_score: style_anchor_build.memory_top_candidate_score,
            memory_selected_primary_bucket: style_anchor_build.memory_selected_primary_bucket,
            memory_low_value_candidate_skipped: style_anchor_build
                .memory_low_value_candidate_skipped,
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
            memory_optimization_removed_low_value_rows: 0,
            director_manual_yielded_to_memory: style_anchor_build.director_manual_yielded_to_memory,
            director_manual_yielded_chars: style_anchor_build.director_manual_yielded_chars,
            director_performance_trimmed_chars,
            director_anchor_saved_chars: style_anchor_build.director_manual_yielded_chars
                + director_performance_trimmed_chars,
            continuity_note_count: continuity_notes.len(),
            continuity_note_chars,
            uses_reference_frame: image_url.is_some(),
            memory_budget_tier: memory_budget_tier.as_str().to_string(),
            memory_budget_risk_score: budget_decision.risk_score,
            memory_budget_reasons: budget_decision.reasons,
            memory_budget_compact_mode: budget_decision.compact_silent_low_risk,
            memory_project_scope_row_count: 0,
            memory_script_scope_row_count: 0,
            memory_role_scope_row_count: 0,
        },
        prompt,
    }
}

fn storyboard_subject_clause_is_redundant_with_scene_anchor(
    subject_clause: &str,
    scene_anchors: &[String],
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> bool {
    let normalized_subject = normalize_prompt_text(subject_clause);
    if normalized_subject.is_empty() || scene_anchors.is_empty() {
        return false;
    }
    let Some(stripped_subject) = [
        "站在", "坐在", "停在", "靠在", "立在", "待在", "站到", "守在",
    ]
    .into_iter()
    .find_map(|prefix| normalized_subject.strip_prefix(prefix))
    .map(normalize_prompt_text)
    .filter(|value| !value.is_empty()) else {
        return false;
    };

    scene_anchors.iter().any(|anchor| {
        let anchor_key = anchor.split_once(':').map(|(key, _)| key).unwrap_or(anchor);
        let normalized_anchor = normalize_prompt_text(anchor_key);
        normalized_anchor.contains(&stripped_subject)
            || stripped_subject.contains(&normalized_anchor)
            || structured_fields.is_some_and(|fields| {
                let normalized_setting = normalize_prompt_text(&fields.setting);
                !normalized_setting.is_empty()
                    && (normalized_setting.contains(&stripped_subject)
                        || stripped_subject.contains(&normalized_setting))
            })
    })
}

pub fn build_video_prompt_opening_clause(
    structured_fields: Option<&StructuredStoryboardDescription>,
    compact_labels: bool,
) -> String {
    if compact_labels || should_use_compact_opening_clause(structured_fields) {
        "Single shot.".to_string()
    } else {
        "Single cinematic shot.".to_string()
    }
}

pub fn build_project_visual_anchors(
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
    let mut memory_selected_primary_bucket = None;
    let mut memory_low_value_candidate_skipped = false;
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
    if let Some(raw_director_manual) = ctx.project_director_manual.as_deref() {
        let should_yield_raw_director_manual = raw_director_manual_should_yield_to_memory_style(
            raw_director_manual,
            &ctx.memory_style_notes,
            structured_fields,
            constraint_pressure,
        );
        if should_yield_raw_director_manual {
            director_manual_yielded_to_memory = true;
            director_manual_yielded_chars +=
                normalize_prompt_text(raw_director_manual).chars().count();
        } else {
            let compacted_director_manual = compact_project_director_note(
                raw_director_manual,
                structured_fields,
                &style_coverage,
                &reserved_art_style_anchors,
            );
            if let Some(note) = compacted_director_manual {
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
                if director_performance_trimmed_chars == 0
                    && should_report_memory_absorbed_director_performance(
                        &ctx.memory_style_notes,
                        structured_fields,
                        constraint_pressure,
                    )
                {
                    director_performance_trimmed_chars += 1;
                }
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
        let compacted = compact_director_performance_anchor_against_memory_style(
            &guardrail_performance_anchor,
            &ctx.memory_style_notes,
            structured_fields,
            constraint_pressure,
        );
        if let Some(compacted_anchor) = compacted {
            anchors.push(compacted_anchor);
            extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
        }
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
    let memory_top_candidate_score = memory_candidates
        .first()
        .map(|(_, _, score)| *score)
        .unwrap_or(0);

    let mut selected_memory_anchor_kinds = Vec::new();
    for (note, is_delivery, score) in memory_candidates {
        if memory_anchor_count == 0
            && should_skip_low_value_memory_candidate(
                &note,
                score,
                structured_fields,
                has_reference_frame,
                has_base_style_anchor,
                memory_budget_tier,
                constraint_pressure,
            )
        {
            memory_low_value_candidate_skipped = true;
            continue;
        }
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
            if memory_selected_primary_bucket.is_none() {
                memory_selected_primary_bucket = selected_memory_style_primary_bucket(&note);
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
                    || (memory_budget_tier == VideoPromptMemoryBudgetTier::Expanded
                        && video_prompt_scene_needs_emotional_memory(fields))
            })
        {
            memory_delivery_priority_applied = true;
        }
        extend_prompt_coverage(&mut style_coverage, std::slice::from_ref(&note));
        if is_delivery {
            memory_delivery_anchor_count += 1;
        }
        if memory_selected_primary_bucket.is_none() {
            memory_selected_primary_bucket = selected_memory_style_primary_bucket(&note);
        }
        accumulate_memory_style_bucket_counts(&mut selected_memory_bucket_counts, &note);
        anchors.push(note);
        selected_memory_anchor_kinds.push(is_delivery);
        memory_anchor_count += 1;
    }
    if let Some(fields) = structured_fields {
        if constraint_pressure.is_some_and(|pressure| {
            (pressure.has_dialogue_guardrail || pressure.has_identity_guardrail)
                && !anchors
                    .iter()
                    .any(|anchor| style_note_contains_family(anchor, "表演"))
                && anchors
                    .iter()
                    .any(|anchor| style_note_contains_family(anchor, "语气"))
        }) {
            if let Some(fragment) = ctx
                .memory_style_notes
                .iter()
                .flat_map(|note| split_prompt_note_fragments(note))
                .find(|fragment| fragment.starts_with("表演"))
            {
                let recovered = clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
                if !anchors.iter().any(|existing| existing == &recovered) {
                    anchors.push(recovered);
                    memory_anchor_count += 1;
                }
            }
        }
        if memory_budget_tier == VideoPromptMemoryBudgetTier::Expanded
            && anchors
                .iter()
                .any(|anchor| memory_style_anchor_has_delivery_signal(anchor))
            && !anchors
                .iter()
                .any(|anchor| style_note_contains_family(anchor, "光影"))
        {
            if let Some(recovered) = ctx.memory_style_notes.iter().find_map(|note| {
                let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
                (fragments
                    .iter()
                    .any(|fragment| fragment.starts_with("光影"))
                    && fragments
                        .iter()
                        .any(|fragment| fragment.starts_with("环境")))
                .then(|| clip_prompt_fragment(note, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
            }) {
                if let Some(position) = anchors.iter().position(|anchor| {
                    style_note_contains_family(anchor, "环境")
                        && !style_note_contains_family(anchor, "光影")
                }) {
                    anchors[position] = recovered;
                } else if memory_anchor_total_chars_within_budget(
                    &anchors,
                    &recovered,
                    memory_anchor_count,
                    VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                ) && memory_style_anchor_is_complementary(&recovered, &anchors)
                {
                    anchors.push(recovered);
                    memory_anchor_count += 1;
                }
            }
        }
        if !storyboard_dialogue_is_empty(&fields.dialogue)
            && anchors.iter().any(|anchor| {
                style_note_contains_family(anchor, "表演")
                    || style_note_contains_family(anchor, "语气")
            })
        {
            anchors.retain(|anchor| normalize_prompt_text(anchor) != "动作自然");
        }
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
        memory_top_candidate_score,
        memory_selected_primary_bucket,
        memory_low_value_candidate_skipped,
        memory_hit_buckets,
        memory_suppressed_buckets,
        memory_hit_bucket_counts: selected_memory_bucket_counts,
        memory_suppressed_bucket_counts,
        director_manual_yielded_to_memory,
        director_manual_yielded_chars,
        director_performance_trimmed_chars,
    }
}

fn should_report_memory_absorbed_director_performance(
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
    memory_style_notes.iter().any(|note| {
        let normalized = normalize_prompt_text(note);
        normalized.contains("语气")
            && ["神情", "眼神", "眉心", "嘴角", "眼眶", "唇线", "喉结"]
                .iter()
                .any(|keyword| normalized.contains(keyword))
    })
}
