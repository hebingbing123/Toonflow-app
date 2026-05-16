//! Tests for video prompt generation.

use crate::production::workbench::meta::generate::{
    art_style_director_profile, build_auto_quality_review_model_params,
    build_pending_video_observation_note_from_runtime,
    build_pending_video_observation_selection_from_runtime, build_video_prompt,
    build_video_prompt_memory_notes, build_video_prompt_with_constraint_pressure,
    build_video_prompt_with_diagnostics, compact_camera_clause,
    compact_contextual_video_style_note, compact_director_emotion_fragment_group,
    compact_guardrail_sensitive_style_note, compact_negative_constraint_against_storyboard_style,
    compact_script_asset_anchor, exact_style_notes_should_yield_to_role_memory,
    observation_style_note_context_evidence, parse_director_emotion_cues,
    parse_director_environment_cues, parse_director_environment_texture_cues,
    parse_director_motion_cue, parse_structured_storyboard_description,
    prefer_role_memory_only_for_silent_identity_scene, prune_low_signal_observation_candidates,
    prune_storyboard_observation_candidates, resolve_observation_filter_style_note,
    resolve_video_prompt_duration, resolve_video_prompt_memory_budget_tier,
    score_compacted_style_note_against_constraint_pressure,
    score_video_prompt_observation_specificity, select_best_video_prompt_observation_note,
    select_contextual_observation_summary_style_note,
    select_pressure_prioritized_style_note_candidate, select_script_asset_anchors,
    select_video_prompt_asset_seed_rows, select_video_prompt_memory_notes,
    select_video_prompt_style_notes, trim_video_prompt_memory_rows,
    trim_video_prompt_memory_rows_with_context, trim_video_prompt_observation_rows,
    video_prompt_observation_conflicts_with_style,
    video_prompt_observation_is_irrelevant_to_storyboard, DirectorEmotionFragmentGroup,
    GenerateVideoPromptBody, GenerateVideoPromptDiagnostics, GenerateVideoPromptResponse,
    ScriptRolePromptSeedRow, VideoPromptConstraintPressure, VideoPromptContext,
    VideoPromptMemoryBudgetTier, VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS,
    VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT,
};
use crate::production::workbench::video::generate::{
    AutoNegativePromptSelection, StoryboardNegativePromptRuntime,
};
use crate::production::workbench::video_prompt_memory::{
    select_neighbor_selected_video_memory_notes,
    select_pending_rejected_video_observation_candidates_for_subject,
    select_prioritized_video_style_note, select_project_video_style_memory_notes,
    select_script_video_style_memory_notes, selected_memory_subject_aliases, AgentMemoryRow,
    StoryboardPromptSeedRow, StructuredStoryboardDescription,
};
use proptest::prelude::*;

use super::test_helpers::{
    elevated_risk_fields, grounded_low_risk_fields, sample_generate_video_prompt_diagnostics,
};

// No tests in this module yet
