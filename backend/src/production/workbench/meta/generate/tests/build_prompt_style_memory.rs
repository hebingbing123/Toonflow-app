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
fn build_video_prompt_trims_project_director_style_half_already_covered_by_storyboard() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("光影冷调逆光颗粒，镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 光影颗粒."),
        "{prompt}"
    );
    assert!(!prompt.contains("光影冷调逆光颗粒"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_project_art_style_fragments_already_covered_elsewhere() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片颗粒，冷调逆光，冷峻压迫".into()),
            project_director_manual: Some("镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片颗粒."), "{prompt}");
    assert!(!prompt.contains("冷调逆光;"));
    assert!(!prompt.contains("冷峻压迫;"));
}

#[test]
fn build_video_prompt_shortens_quality_tail_when_director_continuity_survives_style_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持稳定跟拍，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 稳定跟拍, 质感克制粗粝."),
        "{prompt}"
    );
    assert!(prompt.contains("No extra shot changes."), "{prompt}");
    assert!(!prompt.contains("Natural motion"), "{prompt}");
    assert!(!prompt.contains("stable continuity"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_generic_continuity_clause_inside_fused_director_style_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持稳定跟拍且镜头衔接统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 稳定跟拍, 质感克制粗粝."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
    assert!(prompt.contains("No extra shot changes."), "{prompt}");
    assert!(!prompt.contains("Natural motion"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_generic_continuity_clause_inside_fused_director_lighting_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("光影偏冷并保持镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 光影偏冷."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
    assert!(
        prompt.contains("Natural motion, stable continuity, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_adds_art_style_performance_anchor_for_matching_mood() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、夜间冷蓝窗光、无台词、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 真人都市写实; 神情内敛, 眼神深沉, 唇线收紧"),
        "{prompt}"
    );
    assert!(prompt.contains("动作自然"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_generic_director_mood_when_art_style_performance_anchor_exists() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、夜间冷蓝窗光、无台词、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: Some("情绪隐忍克制，镜头衔接统一".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 真人都市写实; 神情内敛, 眼神深沉, 唇线收紧"),
        "{prompt}"
    );
    assert!(!prompt.contains("情绪隐忍克制"), "{prompt}");
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
}

#[test]
fn build_video_prompt_prefers_fragile_director_anchor_for_broken_voice_turn() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、抽气后失声开口、隐忍哽咽、夜间冷蓝窗光、我没事、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 真人都市写实; 神情低落, 眼神黯淡, 眉心轻蹙"),
        "{prompt}"
    );
    assert!(!prompt.contains("动作自然"), "{prompt}");
    assert!(!prompt.contains("神情内敛"), "{prompt}");
    assert!(!prompt.contains("眼神深沉"), "{prompt}");
    assert!(!prompt.contains("唇线收紧"), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_director_performance_anchor_to_high_signal_cues() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（沈知微站在落地窗旁、城市夜景落地窗边、沈知微、4秒、中景、缓推、看着雨丝划过玻璃并轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A13）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["沈知微: 米色风衣".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 成熟都市言情动画风格; 神情内敛, 眼神深沉, 唇线收紧;"),
        "{prompt}"
    );
    assert!(!prompt.contains("面容沉静"), "{prompt}");
    assert!(!prompt.contains("眼底有情绪压抑"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_performance_anchor_without_matching_art_style_profile() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在门口停下、门口、主角、4秒、中景、静止、停步回望、紧张、阴天冷光、无台词、风声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("眼神深沉"));
    assert!(!prompt.contains("表情略带茫然"));
}
