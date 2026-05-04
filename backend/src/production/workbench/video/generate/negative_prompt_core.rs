use std::collections::HashMap;

use super::*;
use crate::production::workbench::meta::generate::constraints::{
    derive_recent_quality_constraint_pressure, RecentQualitySignalRow,
    VideoPromptConstraintPressure,
};
use crate::production::workbench::video_prompt_memory::{
    extract_key_value, normalize_prompt_text, parse_structured_storyboard_description,
    select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias,
    select_selected_video_memory_notes_for_storyboard, selected_memory_subject_aliases,
    storyboard_prompt_seed, AgentMemoryRow, StoryboardPromptSeedRow,
    VideoPromptMemorySelectionBias,
};

use super::fragment_operations::{
    merge_prioritized_negative_prompt_fragment_groups, split_negative_prompt_fragments,
};
use super::memory_integration::filter_selected_rows_for_subject;
use super::negative_prompt_analysis::{
    compact_rejected_fragments_against_review_focus,
    compact_review_fragments_against_rejected_memory, filter_conflicting_negative_fragments,
    filter_conflicting_review_fragments, resolve_negative_filter_style_note,
    storyboard_dialogue_is_empty,
};
use super::negative_prompt_risk::{
    negative_fragment_requires_strict_continuity_budget,
    negative_fragment_targets_identity_consistency, negative_prompt_scene_needs_expanded_budget,
};
use super::quality_control::{
    collect_negative_review_fragments, quality_review_storyboard_target_id,
    recent_quality_storyboard_target_id,
};

#[allow(dead_code)]
pub(super) fn build_storyboard_negative_prompts(
    storyboard_ids: &[i32],
    review_rows: &[QualityReviewSeedRow],
    rejected_rows: &[AgentMemoryRow],
    selected_rows: &[AgentMemoryRow],
    storyboard_seed_rows: &HashMap<i32, StoryboardPromptSeedRow>,
) -> HashMap<i32, AutoNegativePromptSelection> {
    build_storyboard_negative_prompts_with_recent_quality(
        storyboard_ids,
        review_rows,
        rejected_rows,
        selected_rows,
        storyboard_seed_rows,
        &[],
    )
}

#[cfg(test)]
pub(in crate::production::workbench::video::generate) fn build_storyboard_negative_prompts_test(
    storyboard_ids: &[i32],
    review_rows: &[QualityReviewSeedRow],
    rejected_rows: &[AgentMemoryRow],
    selected_rows: &[AgentMemoryRow],
    storyboard_seed_rows: &HashMap<i32, StoryboardPromptSeedRow>,
) -> HashMap<i32, AutoNegativePromptSelection> {
    build_storyboard_negative_prompts(
        storyboard_ids,
        review_rows,
        rejected_rows,
        selected_rows,
        storyboard_seed_rows,
    )
}

pub(super) fn build_storyboard_negative_prompts_with_recent_quality(
    storyboard_ids: &[i32],
    review_rows: &[QualityReviewSeedRow],
    rejected_rows: &[AgentMemoryRow],
    selected_rows: &[AgentMemoryRow],
    storyboard_seed_rows: &HashMap<i32, StoryboardPromptSeedRow>,
    recent_quality_rows: &[RecentQualitySignalSeedRow],
) -> HashMap<i32, AutoNegativePromptSelection> {
    let contexts = build_storyboard_negative_prompt_contexts(
        storyboard_ids,
        review_rows,
        recent_quality_rows,
        selected_rows,
        storyboard_seed_rows.clone(),
    );

    storyboard_ids
        .iter()
        .copied()
        .map(|storyboard_id| {
            let selection = contexts
                .get(&storyboard_id)
                .map(|context| build_storyboard_negative_prompt_selection(context, rejected_rows).0)
                .unwrap_or_else(|| {
                    build_storyboard_negative_prompt_selection(
                        &StoryboardNegativePromptContext {
                            storyboard_id,
                            storyboard_review_rows: Vec::new(),
                            recent_quality_pressure: None,
                            selected_rows: selected_rows.to_vec(),
                            storyboard_row: None,
                            current_prompt_seed: None,
                            subject_candidates: Vec::new(),
                        },
                        rejected_rows,
                    )
                    .0
                });
            (storyboard_id, selection)
        })
        .collect()
}

pub(super) fn build_storyboard_negative_prompt_contexts(
    storyboard_ids: &[i32],
    review_rows: &[QualityReviewSeedRow],
    recent_quality_rows: &[RecentQualitySignalSeedRow],
    selected_rows: &[AgentMemoryRow],
    mut storyboard_seed_rows: HashMap<i32, StoryboardPromptSeedRow>,
) -> HashMap<i32, StoryboardNegativePromptContext> {
    let mut storyboard_review_rows = storyboard_ids
        .iter()
        .copied()
        .map(|storyboard_id| (storyboard_id, Vec::new()))
        .collect::<HashMap<_, _>>();
    let global_review_rows = review_rows
        .iter()
        .filter(|row| quality_review_storyboard_target_id(row).is_none())
        .cloned()
        .collect::<Vec<_>>();
    for row in review_rows {
        if let Some(storyboard_id) = quality_review_storyboard_target_id(row) {
            if let Some(group) = storyboard_review_rows.get_mut(&storyboard_id) {
                group.push(row.clone());
            }
        }
    }
    let mut storyboard_quality_rows = storyboard_ids
        .iter()
        .copied()
        .map(|storyboard_id| (storyboard_id, Vec::new()))
        .collect::<HashMap<_, _>>();
    let global_quality_rows = recent_quality_rows
        .iter()
        .filter(|row| recent_quality_storyboard_target_id(row).is_none())
        .cloned()
        .collect::<Vec<_>>();
    for row in recent_quality_rows {
        if let Some(storyboard_id) = recent_quality_storyboard_target_id(row) {
            if let Some(group) = storyboard_quality_rows.get_mut(&storyboard_id) {
                group.push(row.clone());
            }
        }
    }

    storyboard_ids
        .iter()
        .copied()
        .map(|storyboard_id| {
            let storyboard_row = storyboard_seed_rows.remove(&storyboard_id);
            let current_prompt_seed = storyboard_row.as_ref().and_then(storyboard_prompt_seed);
            let subject_candidates = storyboard_row
                .as_ref()
                .and_then(|row| row.video_desc.as_deref())
                .and_then(parse_structured_storyboard_description)
                .map(|fields| {
                    selected_memory_subject_aliases(&fields.subject, &fields.subject_refs)
                })
                .unwrap_or_default();
            let storyboard_selected_rows =
                filter_selected_rows_for_subject(selected_rows, &subject_candidates);
            let review_rows = storyboard_review_rows
                .remove(&storyboard_id)
                .unwrap_or_default()
                .into_iter()
                .chain(global_review_rows.iter().cloned())
                .collect::<Vec<_>>();
            let recent_quality_pressure = derive_recent_quality_constraint_pressure(
                &storyboard_quality_rows
                    .remove(&storyboard_id)
                    .unwrap_or_default()
                    .into_iter()
                    .chain(global_quality_rows.iter().cloned())
                    .map(RecentQualitySignalRow::from)
                    .collect::<Vec<_>>(),
            );
            (
                storyboard_id,
                StoryboardNegativePromptContext {
                    storyboard_id,
                    storyboard_review_rows: review_rows,
                    recent_quality_pressure,
                    selected_rows: storyboard_selected_rows,
                    storyboard_row,
                    current_prompt_seed,
                    subject_candidates,
                },
            )
        })
        .collect()
}

pub(super) fn build_storyboard_negative_prompt_selection(
    context: &StoryboardNegativePromptContext,
    rejected_rows: &[AgentMemoryRow],
) -> (AutoNegativePromptSelection, Vec<String>) {
    let selected_style_note = select_selected_video_memory_notes_for_storyboard(
        &context.selected_rows,
        context.storyboard_id,
        context.current_prompt_seed.as_deref(),
        context.storyboard_row.as_ref(),
    )
    .into_iter()
    .next();
    let prioritized_style_note = resolve_negative_filter_style_note(
        &context.selected_rows,
        context.storyboard_id,
        context.current_prompt_seed.as_deref(),
        context.storyboard_row.as_ref(),
        selected_style_note,
        &context.subject_candidates,
        context.recent_quality_pressure,
    );
    let review_fragments = filter_conflicting_review_fragments(
        collect_negative_review_fragments(
            &context.storyboard_review_rows,
            context.storyboard_id,
            context.recent_quality_pressure,
        ),
        prioritized_style_note.as_deref(),
        context.storyboard_row.as_ref(),
    );
    let rejected_memory_selection =
        select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias(
            rejected_rows,
            context.storyboard_id,
            context.current_prompt_seed.as_deref(),
            &context.subject_candidates,
            context.storyboard_row.as_ref(),
            recent_quality_memory_selection_bias(context.recent_quality_pressure),
        );
    let negative_memory_notes = rejected_memory_selection.negative_notes;
    let pending_observation_candidates = rejected_memory_selection.observation_notes;
    let has_exact_rejected_prompt_seed_match = rejected_memory_has_exact_prompt_seed_match(
        rejected_rows,
        context.storyboard_id,
        context.current_prompt_seed.as_deref(),
    );
    let rejected_fragments = filter_conflicting_negative_fragments(
        split_negative_prompt_fragments(negative_memory_notes.into_iter().next().as_deref()),
        prioritized_style_note.as_deref(),
        context.storyboard_row.as_ref(),
    );
    let review_fragments =
        prune_storyboard_negative_fragments(review_fragments, context.storyboard_row.as_ref());
    let rejected_fragments = if has_exact_rejected_prompt_seed_match {
        rejected_fragments
    } else {
        prune_storyboard_negative_fragments(rejected_fragments, context.storyboard_row.as_ref())
    };
    let review_fragments =
        compact_review_fragments_against_rejected_memory(review_fragments, &rejected_fragments);
    let rejected_fragments = compact_rejected_fragments_against_review_focus(
        rejected_fragments,
        &review_fragments,
        context.storyboard_row.as_ref(),
    );
    let observation_fragments = if rejected_fragments.is_empty() && review_fragments.is_empty() {
        build_storyboard_observation_negative_fragments(
            pending_observation_candidates.clone(),
            prioritized_style_note.as_deref(),
            context.storyboard_row.as_ref(),
        )
    } else {
        Vec::new()
    };
    let effective_rejected_fragments =
        if rejected_fragments.is_empty() && review_fragments.is_empty() {
            observation_fragments.clone()
        } else {
            rejected_fragments.clone()
        };
    let budget_tier = resolve_negative_prompt_budget_tier(
        context.storyboard_row.as_ref(),
        &context.storyboard_review_rows,
        &effective_rejected_fragments,
        &review_fragments,
        context.subject_candidates.len(),
    );
    let review_fragment_count = review_fragments.len();
    let rejected_memory_fragment_count = effective_rejected_fragments.len();
    let candidate_fragment_count = review_fragment_count + rejected_memory_fragment_count;
    let candidate_chars = review_fragments
        .iter()
        .chain(effective_rejected_fragments.iter())
        .map(|fragment| normalize_prompt_text(fragment).chars().count())
        .sum::<usize>();
    let used_pending_observation_fallback = rejected_fragments.is_empty()
        && review_fragments.is_empty()
        && !observation_fragments.is_empty();
    let prompt = merge_prioritized_negative_prompt_fragment_groups(
        &[effective_rejected_fragments, review_fragments],
        budget_tier,
        context.recent_quality_pressure,
    );
    let fragment_count = prompt
        .as_deref()
        .map(|value| split_negative_prompt_fragments(Some(value)).len())
        .unwrap_or(0);
    let saved_fragment_count = candidate_fragment_count.saturating_sub(fragment_count);
    let final_chars = prompt
        .as_deref()
        .map(normalize_prompt_text)
        .map(|value| value.chars().count())
        .unwrap_or(0);
    let saved_chars = candidate_chars.saturating_sub(final_chars);

    (
        AutoNegativePromptSelection {
            prompt,
            fragment_count,
            candidate_fragment_count,
            saved_fragment_count,
            saved_chars,
            budget_tier: budget_tier.as_str(),
            review_fragment_count,
            rejected_memory_fragment_count,
            used_pending_observation_fallback,
        },
        pending_observation_candidates,
    )
}

fn rejected_memory_has_exact_prompt_seed_match(
    rows: &[AgentMemoryRow],
    storyboard_id: i32,
    current_prompt_seed: Option<&str>,
) -> bool {
    let Some(current_prompt_seed) = current_prompt_seed else {
        return false;
    };

    rows.iter().any(|row| {
        row.name == "rejected_video_negative_memory"
            && extract_key_value(&row.content, "promptSeed").as_deref() == Some(current_prompt_seed)
            && extract_key_value(&row.content, "storyboardIds").is_some_and(|value| {
                value
                    .split(',')
                    .filter_map(|part| part.trim().parse::<i32>().ok())
                    .any(|value| value == storyboard_id)
            })
    })
}

pub(super) fn build_storyboard_observation_negative_fragments(
    observation_fragments: Vec<String>,
    prioritized_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let observation_fragments = filter_conflicting_negative_fragments(
        observation_fragments,
        prioritized_style_note,
        storyboard_row,
    );
    prune_storyboard_negative_fragments(observation_fragments, storyboard_row)
}

impl From<RecentQualitySignalSeedRow> for RecentQualitySignalRow {
    fn from(value: RecentQualitySignalSeedRow) -> Self {
        Self {
            passed: value.passed,
            overall_score: value.overall_score,
            dialogue_naturalness: value.dialogue_naturalness,
            character_consistency: value.character_consistency,
            visual_quality: value.visual_quality,
            memory_delivery_priority_applied: value.memory_delivery_priority_applied,
            is_bad_case: value.is_bad_case,
            bad_case_category: value.bad_case_category,
            comments: value.comments,
            feedback_memory_focus_tags: value
                .feedback_memory_focus_tags
                .as_ref()
                .and_then(serde_json::Value::as_array)
                .into_iter()
                .flat_map(|items| items.iter())
                .filter_map(|item| item.as_str().map(str::to_string))
                .collect(),
        }
    }
}

pub(super) fn recent_quality_memory_selection_bias(
    pressure: Option<VideoPromptConstraintPressure>,
) -> Option<VideoPromptMemorySelectionBias> {
    pressure.and_then(|pressure| {
        let bias = VideoPromptMemorySelectionBias {
            prefer_delivery: pressure.prefer_delivery_memory_recall,
            prefer_visual_continuity: pressure.prefer_visual_continuity_memory_recall,
        };
        (bias.prefer_delivery || bias.prefer_visual_continuity).then_some(bias)
    })
}

fn resolve_negative_prompt_budget_tier(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    storyboard_review_rows: &[QualityReviewSeedRow],
    rejected_fragments: &[String],
    review_fragments: &[String],
    subject_alias_count: usize,
) -> VideoNegativePromptBudgetTier {
    let mut risk_score = 0;
    if subject_aliases_need_expanded_negative_budget(
        subject_alias_count,
        rejected_fragments,
        review_fragments,
    ) {
        risk_score += 1;
    }
    if storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| negative_prompt_scene_needs_expanded_budget(&fields))
    {
        risk_score += 1;
    }
    if !storyboard_review_rows.is_empty() {
        risk_score += 1;
    }
    if rejected_fragments.len() >= 2 {
        risk_score += 1;
    }
    if review_fragments
        .iter()
        .chain(rejected_fragments.iter())
        .any(|fragment| negative_fragment_requires_strict_continuity_budget(fragment))
    {
        risk_score += 1;
    }

    if risk_score >= 2 {
        VideoNegativePromptBudgetTier::Expanded
    } else {
        VideoNegativePromptBudgetTier::Lean
    }
}

fn subject_aliases_need_expanded_negative_budget(
    _subject_alias_count: usize,
    rejected_fragments: &[String],
    review_fragments: &[String],
) -> bool {
    review_fragments
        .iter()
        .chain(rejected_fragments.iter())
        .any(|fragment| negative_fragment_targets_identity_consistency(fragment))
}

pub(super) fn prune_storyboard_negative_fragments(
    fragments: Vec<String>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let mut kept = fragments
        .into_iter()
        .filter_map(|fragment| {
            compact_negative_fragment_against_storyboard_risk(&fragment, storyboard_row)
        })
        .filter(|fragment| negative_fragment_matches_storyboard_risk(fragment, storyboard_row))
        .collect::<Vec<_>>();
    kept.dedup();
    kept
}

pub(super) fn compact_negative_fragment_against_storyboard_risk(
    fragment: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    use super::fragment_parsing::canonical_negative_fragment;
    use super::negative_prompt_risk::*;

    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return None;
    }

    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return Some(trimmed.to_string());
    };

    match canonical_negative_fragment(trimmed).as_str() {
        "avoid extra shot changes or wrong framing" => {
            let has_shot_change_risk = negative_prompt_scene_has_shot_change_risk(&fields);
            let has_extreme_angle_risk = negative_prompt_scene_has_extreme_angle_risk(&fields);
            let has_tight_close_up_risk = negative_prompt_scene_has_tight_close_up_risk(&fields);
            match (
                has_shot_change_risk,
                has_extreme_angle_risk,
                has_tight_close_up_risk,
            ) {
                (true, true, true) => Some(trimmed.to_string()),
                (true, true, false) => {
                    Some("avoid unnecessary shot changes, avoid extreme camera angle".to_string())
                }
                (true, false, true) => Some(
                    "avoid unnecessary shot changes, avoid overly tight close-up framing"
                        .to_string(),
                ),
                (true, false, false) => Some("avoid unnecessary shot changes".to_string()),
                (false, true, true) => {
                    Some("avoid extreme camera angle or overly tight close-up framing".to_string())
                }
                (false, true, false) => Some("avoid extreme camera angle".to_string()),
                (false, false, true) => Some("avoid overly tight close-up framing".to_string()),
                (false, false, false) => Some("avoid unnecessary shot changes".to_string()),
            }
        }
        "avoid warped anatomy, blur, flicker" => {
            if negative_prompt_scene_has_motion_risk(&fields) {
                Some(trimmed.to_string())
            } else {
                Some("avoid warped anatomy or blur".to_string())
            }
        }
        "avoid flat cold lighting or harsh backlight silhouette" => {
            let has_flat_cold_lighting = negative_prompt_scene_has_flat_cold_lighting_risk(&fields);
            let has_backlight = negative_prompt_scene_has_backlight_silhouette_risk(&fields);
            let has_neon_reflections = negative_prompt_scene_has_neon_reflection_risk(&fields);
            match (has_flat_cold_lighting, has_backlight) {
                (true, true) => Some(trimmed.to_string()),
                (true, false) => Some("avoid flat cold lighting".to_string()),
                (false, true) => Some("avoid harsh backlight silhouette".to_string()),
                (false, false) if has_neon_reflections => {
                    Some("avoid distracting neon reflections".to_string())
                }
                (false, false) => {
                    negative_prompt_scene_has_lighting_risk(&fields).then_some(trimmed.to_string())
                }
            }
        }
        "avoid oppressive or frantic mood" | "avoid overly cold, oppressive, or frantic mood" => {
            if negative_prompt_scene_intends_frantic_mood(&fields) {
                None
            } else if negative_prompt_scene_prefers_restrained_emotional_guard(&fields) {
                Some("avoid frantic mood".to_string())
            } else {
                Some(trimmed.to_string())
            }
        }
        "avoid blank expression or monotone delivery" => {
            negative_prompt_scene_needs_expressive_performance_guard(&fields)
                .then_some(trimmed.to_string())
        }
        _ => Some(trimmed.to_string()),
    }
}

pub(super) fn negative_fragment_matches_storyboard_risk(
    fragment: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    use super::fragment_parsing::negative_fragment_family;
    use super::negative_prompt_risk::*;

    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return true;
    };

    match negative_fragment_family(fragment) {
        "shot_change_only" => true,
        "lip_sync_mismatch" => !storyboard_dialogue_is_empty(&fields.dialogue),
        "lighting_backlight" => negative_prompt_scene_has_lighting_risk(&fields),
        "rushed_motion" => true,
        "mood_tone" => negative_prompt_scene_needs_emotional_memory(&fields),
        "performance_delivery" => negative_prompt_scene_needs_expressive_performance_guard(&fields),
        "camera_framing" | "shot_change_framing" => negative_prompt_scene_has_framing_risk(&fields),
        _ => true,
    }
}
