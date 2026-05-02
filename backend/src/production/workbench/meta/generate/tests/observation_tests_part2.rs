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

#[test]
fn prune_storyboard_observation_candidates_keeps_lighting_note_for_reflective_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（女主站在落地窗边、城市夜景落地窗边、女主、4秒、中景、缓推、看着雨丝划过玻璃、隐忍、冷蓝窗光与路灯反射、无台词、雨声、A18）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert_eq!(
        prune_storyboard_observation_candidates(
            vec!["avoid harsh backlight silhouette".into()],
            Some(&storyboard_row)
        ),
        vec!["avoid harsh backlight silhouette".to_string()]
    );
}

#[test]
fn prune_storyboard_observation_candidates_keeps_lip_sync_note_for_dialogue_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（女主逼近门厅、旧宅门厅、女主、5秒、近景、推进、停步回头、克制、冷调逆光、你别再骗我、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert_eq!(
        prune_storyboard_observation_candidates(
            vec!["avoid lip-sync mismatch".into()],
            Some(&storyboard_row)
        ),
        vec!["avoid lip-sync mismatch".to_string()]
    );
}

#[test]
fn prune_storyboard_observation_candidates_drops_lip_sync_note_for_brief_filler_utterance() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在门口低低应了一声".into()),
            video_desc: Some(
                "（主角停在门口、旧宅门口、主角、4秒、近景、静止、抿唇后轻轻应了一声、克制、冷调逆光、嗯、风声回响、A12）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert!(prune_storyboard_observation_candidates(
        vec!["avoid lip-sync mismatch".into()],
        Some(&storyboard_row)
    )
    .is_empty());
}

#[test]
fn prune_storyboard_observation_candidates_drops_lip_sync_note_for_wide_moving_dialogue_storyboard()
{
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在街口边跑边喊别管我".into()),
            video_desc: Some(
                "（主角穿过雨夜街口、雨夜街口、主角、5秒、全景、手持跟拍、奔跑间回头喊出别管我、紧张、霓虹反光、别管我、雨声车流声、A14）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert!(prune_storyboard_observation_candidates(
        vec!["avoid lip-sync mismatch".into()],
        Some(&storyboard_row)
    )
    .is_empty());
}

#[test]
fn prune_storyboard_observation_candidates_drops_blocking_note_for_grounded_low_risk_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚坐在窗边、雨夜书房、林晚、4秒、中景、静止、低头捏紧信纸、克制、室内暖光、你终于来了、雨声压过呼吸声、A21）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert!(prune_storyboard_observation_candidates(
        vec!["avoid extra shot changes or wrong framing".into()],
        Some(&storyboard_row)
    )
    .is_empty());
}

#[test]
fn prune_storyboard_observation_candidates_keeps_blocking_note_for_multi_subject_blocking_storyboard(
) {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚与顾承泽对峙、旧宅门厅、林晚/顾承泽、5秒、中景、稳定跟拍、林晚侧身让开后顾承泽逼近一步、压迫、冷调逆光、别过来、风声回响、A22）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert_eq!(
        prune_storyboard_observation_candidates(
            vec!["avoid extra shot changes or wrong framing".into()],
            Some(&storyboard_row)
        ),
        vec!["avoid extra shot changes or wrong framing".to_string()]
    );
}

#[test]
fn observation_note_conflict_filter_keeps_non_conflicting_half_of_combined_warning() {
    let close_up_storyboard = StoryboardPromptSeedRow {
        prompt: Some("门口逼视".into()),
        video_desc: Some(
            "（主角逼视来人、旧宅门口、主角、5秒、近景、静止、逼近对手、克制、侧逆光、、、A15）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    assert_eq!(
        compact_negative_constraint_against_storyboard_style(
            "avoid extreme camera angle or overly tight close-up framing",
            None,
            Some(&close_up_storyboard),
        ),
        Some("avoid extreme camera angle".to_string())
    );

    let cold_light_storyboard = StoryboardPromptSeedRow {
        prompt: Some("冷光对峙".into()),
        video_desc: Some(
            "（主角对峙、旧宅门厅、主角、5秒、中景、静止、盯住来人、冷峻压迫、室内冷光、、、A16）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    assert_eq!(
        compact_negative_constraint_against_storyboard_style(
            "avoid flat cold lighting or harsh backlight silhouette",
            None,
            Some(&cold_light_storyboard),
        ),
        Some("avoid harsh backlight silhouette".to_string())
    );
}

#[test]
fn observation_note_conflict_filter_understands_handheld_follow_and_neon_context() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角穿过霓虹雨巷".into()),
            video_desc: Some(
                "（主角穿过霓虹雨巷、雨夜巷口、主角、5秒、中景、手持跟拍、踩水快步穿行、悲怆、霓虹反光、无台词、雨声脚步声、A14）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

    assert!(video_prompt_observation_conflicts_with_style(
        "avoid shaky handheld motion",
        None,
        Some(&storyboard_row),
    ));
    assert!(video_prompt_observation_conflicts_with_style(
        "avoid distracting neon reflections",
        None,
        Some(&storyboard_row),
    ));
    assert!(video_prompt_observation_conflicts_with_style(
        "avoid heavy tragic mood",
        None,
        Some(&storyboard_row),
    ));
    assert!(!video_prompt_observation_conflicts_with_style(
        "avoid lip-sync mismatch",
        None,
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_irrelevant_filter_skips_lip_sync_for_silent_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角贴墙前行".into()),
            video_desc: Some(
                "（主角贴墙前行、旧宅走廊、主角、5秒、近景、稳定跟拍、贴墙前行、压迫、冷调逆光、无台词、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

    assert!(video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
    assert!(!video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid shaky handheld motion",
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_irrelevant_filter_keeps_lip_sync_for_dialogue_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角低声说你终于来了".into()),
            video_desc: Some(
                "（主角低声说你终于来了、旧宅门口、主角、5秒、近景、稳定跟拍、停步低声说出、压迫、冷调逆光、你终于来了、风声压过呼吸声、A13）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

    assert!(!video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_irrelevant_filter_skips_lip_sync_for_brief_filler_utterance() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在门口低低应了一声".into()),
            video_desc: Some(
                "（主角停在门口、旧宅门口、主角、4秒、近景、静止、抿唇后轻轻应了一声、克制、冷调逆光、嗯、风声回响、A12）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert!(video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_irrelevant_filter_skips_lip_sync_for_wide_moving_dialogue_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在街口边跑边喊别管我".into()),
            video_desc: Some(
                "（主角穿过雨夜街口、雨夜街口、主角、5秒、全景、手持跟拍、奔跑间回头喊出别管我、紧张、霓虹反光、别管我、雨声车流声、A14）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert!(video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
}
