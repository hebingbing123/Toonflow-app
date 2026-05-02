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
fn compact_camera_clause_drops_axes_already_covered_by_style_anchor() {
    let camera = compact_camera_clause(
        "低机位近景",
        "稳定跟拍",
        &["镜头低机位近景稳定跟拍电影感".to_string()],
    );

    assert_eq!(camera, None);
}

#[test]
fn compact_camera_clause_keeps_only_uncovered_axis() {
    let camera = compact_camera_clause("中景", "稳定跟拍", &["镜头稳定跟拍压迫感".to_string()]);

    assert_eq!(camera.as_deref(), Some("中景"));
}

#[test]
fn compact_script_asset_anchor_skips_empty_describe_instead_of_emitting_generic_placeholder() {
    assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
        asset_type: "role".into(),
        name: Some("主角".into()),
        describe: None,
    })
    .is_none());
    assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
        asset_type: "scene".into(),
        name: Some("旧宅走廊".into()),
        describe: Some("   ".into()),
    })
    .is_none());
    assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
        asset_type: "tool".into(),
        name: Some("青铜匕首".into()),
        describe: None,
    })
    .is_none());
}

#[test]
fn compact_guardrail_sensitive_style_note_prefers_micro_performance_over_generic_emotion_carryover()
{
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚抬眼后低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中近景、缓推、抬眼后喉结轻滚再低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            duration: Some("4s".into()),
        };

    let note = compact_guardrail_sensitive_style_note(
        "情绪压抑克制，表演抬眼停顿，语气压低气息尾音发颤",
        &storyboard_row,
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_dialogue_guardrail: true,
            has_emotion_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    )
    .expect("guardrail-compacted note");
    assert!(note.contains("表演"), "{note}");
    assert!(!note.contains("情绪压抑"), "{note}");
}

#[test]
fn compact_guardrail_sensitive_style_note_prefers_lighting_over_decorative_environment() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前停住".into()),
            video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影、克制、暖金逆光、无台词、静场留白、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_guardrail_sensitive_style_note(
            "光影暖金逆光层次，环境镜面微雾",
            &storyboard_row,
            Some(VideoPromptConstraintPressure {
                has_identity_guardrail: true,
                has_lighting_guardrail: true,
                forces_compact_memory: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        Some("光影层次".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_drops_voice_fragment_when_trim_only_leaves_mood_tail() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边终于开口".into()),
            video_desc: Some("（林晚站在窗边终于开口、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A26）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演喉结滚动，语气低声克制", Some(&storyboard_row),),
        Some("表演喉结滚动".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_drops_generic_emotion_and_motion_carryover_for_dialogue_scene(
) {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边低声开口".into()),
            video_desc: Some("（林晚站在窗边低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、停顿后低声说你终于来了、隐忍 / 克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note(
            "情绪压抑克制，动作自然，表演喉结滚动",
            Some(&storyboard_row),
        ),
        Some("表演喉结滚动".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_drops_stale_role_voice_when_scene_turns_fragile() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚终于失声开口".into()),
            video_desc: Some("（林晚终于失声开口、咖啡厅窗边、林晚、4秒、中景、缓推、呼吸发颤后哽咽开口、哽咽压抑、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演呼吸发颤，语气轻声克制", Some(&storyboard_row),),
        Some("表演呼吸发颤".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_keeps_high_signal_performance_detail_for_dialogue_scene() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边低声开口".into()),
            video_desc: Some("（林晚站在窗边低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、停顿后低声说你终于来了、克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演喉结滚动，语气轻声克制", Some(&storyboard_row),),
        Some("语气轻声，表演喉结滚动".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_keeps_identity_micro_performance_for_silent_close_up() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前停住".into()),
            video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影、克制、暖金逆光、无台词、静场留白、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演眼神迟疑，语气轻声克制", Some(&storyboard_row),),
        Some("表演眼神迟疑".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_keeps_action_matched_performance_for_silent_identity_scene()
{
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前停住".into()),
            video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼停顿后看向镜中倒影、克制、暖金逆光、无台词、静场留白、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("光影暖金逆光，表演抬眼停顿", Some(&storyboard_row),),
        Some("表演抬眼停顿".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_drops_voice_fragment_for_low_visibility_hidden_speech() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚穿过雨幕回头".into()),
            video_desc: Some("（林晚穿过雨幕回头、雨夜街头、林晚、5秒、远景、手持跟拍、穿过雨幕奔跑并喊别回头、紧张、霓虹反光、别回头、脚步声和雨声混在一起、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("语气轻声克制，声场雨声回响", Some(&storyboard_row),),
        Some("声场雨声回响".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_drops_soft_voice_for_broken_breath_turn() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚失声后勉强开口".into()),
            video_desc: Some("（林晚失声后勉强开口、咖啡厅窗边、林晚、4秒、中景、缓推、抽气后失声开口、压抑、夜间冷蓝窗光、我没事、轻微环境声、A13）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演喉结滚动，语气轻声克制", Some(&storyboard_row),),
        None
    );
}

#[test]
fn compact_director_emotion_fragment_group_prefers_high_signal_cue() {
    assert_eq!(
        compact_director_emotion_fragment_group(
            "神情内敛，面容沉静",
            DirectorEmotionFragmentGroup::Face,
        )
        .as_deref(),
        Some("神情内敛")
    );
    assert_eq!(
        compact_director_emotion_fragment_group(
            "眼神深沉，眼底有情绪压抑",
            DirectorEmotionFragmentGroup::Eyes,
        )
        .as_deref(),
        Some("眼神深沉")
    );
    assert_eq!(
        compact_director_emotion_fragment_group(
            "眉心轻蹙，表情内敛",
            DirectorEmotionFragmentGroup::MicroExpression,
        )
        .as_deref(),
        Some("眉心轻蹙")
    );
}
