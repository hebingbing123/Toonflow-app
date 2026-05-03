//! Prompt builder module - split from builder.rs for maintainability.
//!
//! This module contains the video prompt building logic, organized into 8 submodules:
//! - core: Main building functions and orchestration
//! - memory: Memory style selection and processing
//! - anchors: Script asset anchors (role, scene, tool)
//! - fields: Field processing and compaction
//! - validation: Validation and condition checking
//! - transformation: Transformation, scoring, and selection logic
//! - trimming: Fragment trimming functions
//! - utils: Utility functions and text processing

#![allow(unused_imports)]

mod anchors;
mod continuity;
mod core;
mod fields;
mod memory;
mod transformation;
mod trimming;
mod utils;
mod validation;

pub(super) use super::builder_parts::clauses::compact::{
    compact_action_clause, compact_hidden_speech_action_clause, compact_setting_clause,
    compact_subject_clause, prompt_clauses_substantially_overlap,
};
pub(super) use super::builder_parts::clauses::dialogue::{
    compact_dialogue_clause, dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech,
};
pub(super) use super::builder_parts::clauses::sound::{
    compact_sound_clause, sound_fragment_has_high_value_acoustic_detail,
};
pub(super) use super::builder_parts::coverage::{
    canonical_prompt_fragment, extend_prompt_coverage, prompt_fragment_is_covered,
    prompt_style_field_is_covered, style_fragment_semantically_covers_field,
};

// Re-export all public APIs to maintain compatibility
pub(super) use core::{
    build_project_visual_anchors, build_video_prompt, build_video_prompt_opening_clause,
    build_video_prompt_with_constraint_pressure, build_video_prompt_with_diagnostics,
};

pub(super) use anchors::{
    build_script_role_anchors, build_script_scene_anchors, build_script_tool_anchors,
    compact_script_asset_anchor, compact_selected_script_asset_anchor,
    scene_anchor_suffix_candidates, scene_anchor_suffix_looks_specific, score_scene_ref_match,
    score_script_asset_anchor, score_subject_ref_match, script_asset_anchor_fragment_is_covered,
    script_asset_anchor_note_is_generic_placeholder, script_asset_anchor_overlap_fields,
    select_script_asset_anchors, structured_setting_ref_names, structured_subject_ref_names,
    trim_script_asset_anchor_fragment_against_storyboard_fields, ScriptAssetAnchorKind,
};

pub(super) use continuity::{
    auto_scope_continuity_axis, auto_scope_continuity_fragment_is_covered,
    auto_scope_continuity_fragment_is_generic, auto_scope_continuity_fragments_share_anchor,
    auto_scope_memory_matches_current_prompt_seed, auto_scope_memory_tool_matches_video_prompt,
    canonical_continuity_fragment, compact_auto_scope_continuity_fragments,
    compact_auto_scope_continuity_summary, compact_storyboard_memory_continuity_note,
    continuity_fragment_is_generic_quality_tail_overlap,
    continuity_fragment_is_semantically_covered, continuity_fragment_matches_fields,
    continuity_note_adds_specific_guidance, parse_csv_positive_ints, score_continuity_note,
    score_continuity_specificity, select_video_prompt_memory_notes,
    strip_auto_scope_continuity_scaffolding, strip_generic_director_continuity_subfragments,
};

pub(super) use fields::{
    compact_camera_clause, compact_contextual_video_style_note, compact_neighbor_video_style_note,
    compact_project_art_style_note, compact_project_director_fragment_language,
    compact_project_director_note, fallback_contextual_performance_fragment,
    neighbor_style_fragment_matches_storyboard,
    project_director_fragment_adds_visual_style_guidance,
    project_director_fragment_is_generic_quality_tail_overlap,
    project_director_note_has_unique_visual_signal, prompt_style_fragment_overlaps_field,
    sound_stage_fragment_too_generic_after_trim,
    trim_project_director_fragment_against_storyboard_fields, video_prompt_anchor_label,
};

pub(super) use memory::{
    accumulate_memory_style_bucket_counts,
    compact_director_performance_anchor_against_memory_style, compact_memory_style_anchor,
    count_memory_style_buckets, flatten_memory_style_bucket_counts,
    flatten_suppressed_memory_style_bucket_counts, memory_anchor_total_chars_within_budget,
    memory_style_anchor_char_breakdown, memory_style_anchor_has_delivery_signal,
    memory_style_anchor_is_complementary, project_director_note_should_yield_to_memory_style,
    raw_director_manual_should_yield_to_memory_style, select_best_memory_style_note_for_lean_tier,
    selected_memory_style_primary_bucket, should_skip_low_value_memory_candidate,
};

pub(super) use transformation::{
    collect_lean_memory_pair_focuses, collect_reserved_art_style_anchors,
    collect_suppressed_memory_style_bucket_counts, compact_expanded_visual_memory_fragment,
    director_performance_fragment_is_generic_proactive_hint, generic_motion_style_fragment,
    lighting_fragment_retains_specific_detail, memory_fragment_has_high_signal_voice_detail,
    performance_fragment_has_unique_micro_detail, preserve_high_signal_performance_fragment,
    resolve_video_prompt_description, resolve_video_prompt_duration,
    resolve_video_prompt_memory_budget_tier, restore_reference_guardrail_style_detail,
    score_compacted_style_note_against_constraint_pressure,
    score_memory_fragment_against_constraint_pressure,
    score_memory_fragment_human_performance_detail, score_memory_style_fragment_for_lean_tier,
    score_memory_style_note_for_expanded_tier, select_best_expressive_memory_pair_for_lean_tier,
    LeanMemoryPairFocus,
};

pub(super) use trimming::{
    trim_director_performance_fragment_against_storyboard_fields,
    trim_fragment_by_shared_keyword_families, trim_prefixed_style_fragment,
    trim_style_fragment_against_prompt_coverage, trim_style_fragment_against_storyboard_fields,
    trim_style_fragment_by_shared_mood_keywords,
    trim_style_fragment_by_shared_performance_keywords,
    trim_style_fragment_by_shared_voice_keywords, PERFORMANCE_SHARED_KEYWORD_FAMILIES,
    SOUND_SHARED_KEYWORD_FAMILIES, VOICE_SHARED_KEYWORD_FAMILIES,
};

pub(super) use utils::{
    current_storyboard_is_fragile_emotional_turn, current_storyboard_voice_family,
    memory_style_bucket, project_director_reserved_anchor_already_carries_performance,
    style_fragment_body, style_fragment_is_low_gain_hidden_speech_voice,
    style_fragment_is_low_gain_mood_carryover, style_fragment_is_semantically_covered,
    style_fragment_lags_current_emotional_turn, style_fragment_matches_prompt_style_field,
    style_fragment_or_body_is_semantically_covered, style_fragment_prefix,
    style_fragment_prefix_and_body, style_note_contains_family, style_voice_family_for_generate,
};

pub(super) use super::builder_parts::continuity::risk::{
    continuity_note_matches_storyboard_risk, video_prompt_scene_has_axis_risk,
    video_prompt_scene_has_blocking_risk, video_prompt_scene_subject_count,
};

pub(super) use validation::{
    expanded_visual_memory_fragment_should_bypass_storyboard_trim,
    memory_style_fragment_should_yield_to_negative_pressure, mood_fragment_is_generic_carryover,
    project_director_mood_fragment_is_generic_carryover, should_compact_decorative_style_anchors,
    should_keep_environment_style_anchor_under_pressure,
    should_keep_motion_style_anchor_under_pressure, should_use_compact_opening_clause,
    should_use_compact_prompt_labels, should_yield_decorative_style_to_reference_frame,
    storyboard_supports_voice_style, video_prompt_has_effective_continuity_note_for_budget,
    video_prompt_scene_is_grounded_low_risk,
    video_prompt_scene_needs_delivery_lighting_pair_memory,
    video_prompt_scene_needs_dialogue_performance_memory,
    video_prompt_scene_needs_emotional_memory,
    video_prompt_scene_needs_identity_lighting_pair_memory,
    voice_fragment_token_is_generic_mood_carryover,
};
