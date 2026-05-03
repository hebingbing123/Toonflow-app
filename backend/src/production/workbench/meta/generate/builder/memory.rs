//! Prompt builder and diagnostics logic.

use super::super::*;
use super::*;

pub fn selected_memory_style_primary_bucket(note: &str) -> Option<String> {
    let mut counts = std::collections::BTreeMap::new();
    accumulate_memory_style_bucket_counts(&mut counts, note);
    [
        "表演", "语气", "情绪", "动作", "光影", "环境", "声场", "镜头",
    ]
    .into_iter()
    .filter_map(|bucket| counts.get(bucket).copied().map(|count| (bucket, count)))
    .max_by(|left, right| left.1.cmp(&right.1).then_with(|| left.0.cmp(right.0)))
    .map(|(bucket, _)| bucket.to_string())
}

pub fn should_skip_low_value_memory_candidate(
    note: &str,
    score: i32,
    structured_fields: Option<&StructuredStoryboardDescription>,
    has_reference_frame: bool,
    has_base_style_anchor: bool,
    memory_budget_tier: VideoPromptMemoryBudgetTier,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    if memory_budget_tier != VideoPromptMemoryBudgetTier::Lean || score > 4 {
        return false;
    }
    if constraint_pressure.is_some_and(|pressure| pressure.has_active_guardrail()) {
        return false;
    }
    if memory_style_anchor_has_delivery_signal(note)
        || style_note_contains_family(note, "光影")
        || style_note_contains_family(note, "动作")
    {
        return false;
    }
    let Some(fields) = structured_fields else {
        return has_reference_frame || has_base_style_anchor;
    };
    if video_prompt_scene_needs_emotional_memory(fields)
        || video_prompt_scene_needs_dialogue_performance_memory(fields, constraint_pressure)
        || video_prompt_scene_needs_identity_memory(fields)
        || video_prompt_scene_has_lighting_risk(fields)
        || video_prompt_scene_has_motion_risk(fields)
        || current_storyboard_is_fragile_emotional_turn(fields)
    {
        return false;
    }

    has_reference_frame || has_base_style_anchor
}

pub fn count_memory_style_buckets<'a>(
    notes: impl Iterator<Item = &'a str>,
) -> std::collections::BTreeMap<String, usize> {
    let mut counts = std::collections::BTreeMap::new();
    for note in notes {
        accumulate_memory_style_bucket_counts(&mut counts, note);
    }
    counts
}

pub fn accumulate_memory_style_bucket_counts(
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

pub fn flatten_memory_style_bucket_counts(
    counts: &std::collections::BTreeMap<String, usize>,
) -> Vec<String> {
    counts
        .iter()
        .filter(|(_, count)| **count > 0)
        .map(|(bucket, _)| bucket.clone())
        .collect()
}

pub fn flatten_suppressed_memory_style_bucket_counts(
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

pub fn project_director_note_should_yield_to_memory_style(
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

pub fn raw_director_manual_should_yield_to_memory_style(
    director_note: &str,
    memory_style_notes: &[String],
    structured_fields: Option<&StructuredStoryboardDescription>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    let normalized = normalize_prompt_text(director_note);
    if normalized.is_empty() {
        return false;
    }
    let has_high_value_memory_fragment = memory_style_notes.iter().any(|note| {
        split_prompt_note_fragments(note)
            .any(|fragment| role_memory_fragment_is_high_value(&fragment))
    });
    if !has_high_value_memory_fragment {
        return false;
    }

    project_director_note_should_yield_to_memory_style(
        &normalized,
        memory_style_notes,
        structured_fields,
        constraint_pressure,
    ) || normalized.starts_with("情绪")
}

pub fn compact_director_performance_anchor_against_memory_style(
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
        && !storyboard_has_visible_speech_performance_risk(fields, None)
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
    let memory_has_high_value_expressive_detail =
        expressive_memory_fragments.iter().any(|fragment| {
            let family = style_note_fragment_family(fragment);
            memory_style_anchor_has_delivery_signal(fragment)
                || score_memory_fragment_human_performance_detail(fragment, family) >= 3
        });
    let retained = split_prompt_note_fragments(anchor)
        .filter(|fragment| {
            !(prompt_fragment_is_covered(fragment, &expressive_memory_fragments)
                || style_note_matches_shared_keyword_family(
                    fragment,
                    &expressive_memory_refs,
                    PERFORMANCE_SHARED_KEYWORD_FAMILIES,
                )
                || memory_has_high_value_expressive_detail
                    && director_performance_fragment_is_generic_proactive_hint(fragment))
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

pub fn memory_style_anchor_has_delivery_signal(note: &str) -> bool {
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
    let has_voice_signal = [
        "轻声", "低声", "压低", "尾音", "发颤", "哽咽", "呢喃", "短促", "颤声", "鼻音",
    ]
    .iter()
    .any(|keyword| note.contains(keyword));

    has_performance_signal && has_voice_signal
}

pub fn memory_style_anchor_char_breakdown(anchors: &[String]) -> (usize, usize) {
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

pub fn memory_anchor_total_chars_within_budget(
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

pub fn memory_style_anchor_is_complementary(note: &str, anchors: &[String]) -> bool {
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

pub fn compact_memory_style_anchor(
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
                if let Some(compacted_visual_fragment) =
                    compact_expanded_visual_memory_fragment(&fragment, fields, memory_budget_tier)
                {
                    return Some(compacted_visual_fragment);
                }
                if expanded_visual_memory_fragment_should_bypass_storyboard_trim(
                    &fragment,
                    fields,
                    memory_budget_tier,
                ) {
                    return Some(fragment);
                }
                return trim_style_fragment_against_storyboard_fields(&fragment, fields);
            }
            Some(fragment)
        })
        .filter_map(|fragment| {
            let keep_expanded_visual_memory_fragment = structured_fields.is_some_and(|fields| {
                expanded_visual_memory_fragment_should_bypass_storyboard_trim(
                    &fragment,
                    fields,
                    memory_budget_tier,
                )
            });
            if keep_expanded_visual_memory_fragment {
                return Some(fragment);
            }
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
            let keep_expanded_visual_memory_fragment = structured_fields.is_some_and(|fields| {
                expanded_visual_memory_fragment_should_bypass_storyboard_trim(
                    fragment,
                    fields,
                    memory_budget_tier,
                )
            });
            let keep_storyboard_matched_fragment = structured_fields.is_some_and(|fields| {
                allow_prompt_covered_style_fragments
                    && style_fragment_matches_prompt_style_field(fragment, fields)
                    && matches!(
                        style_note_fragment_family(fragment),
                        Some("表演") | Some("语气")
                    )
            });
            if let (Some(fields), Some(camera)) = (structured_fields, expected_camera.as_deref()) {
                if continuity_fragment_matches_fields(fragment, fields, camera)
                    && !keep_storyboard_matched_fragment
                    && !keep_expanded_visual_memory_fragment
                {
                    return false;
                }
            }
            !style_fragment_or_body_is_semantically_covered(fragment, prompt_coverage)
                || keep_storyboard_matched_fragment
                || keep_expanded_visual_memory_fragment
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
    Some(restore_reference_guardrail_style_detail(
        &note,
        &normalized,
        structured_fields,
        constraint_pressure,
    ))
}

pub fn select_best_memory_style_note_for_lean_tier(
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

    let pair_focuses =
        collect_lean_memory_pair_focuses(fields, constraint_pressure).collect::<Vec<_>>();
    if pair_focuses.is_empty() {
        return Some(best_single);
    }

    let best_pair = pair_focuses
        .into_iter()
        .filter_map(|pair_focus| {
            select_best_expressive_memory_pair_for_lean_tier(
                fragments,
                fields,
                constraint_pressure,
                pair_focus,
            )
            .map(|(pair, score)| {
                let focus_rank = match pair_focus {
                    LeanMemoryPairFocus::Dialogue => 3,
                    LeanMemoryPairFocus::DeliveryLighting => 2,
                    LeanMemoryPairFocus::IdentityLighting => 1,
                    LeanMemoryPairFocus::Emotional => 0,
                };
                (pair, score, focus_rank)
            })
        })
        .max_by(|left, right| {
            left.1
                .cmp(&right.1)
                .then_with(|| left.2.cmp(&right.2))
                .then_with(|| right.0.chars().count().cmp(&left.0.chars().count()))
                .then_with(|| right.0.cmp(&left.0))
        })
        .map(|(pair, score, _)| (pair, score));
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
