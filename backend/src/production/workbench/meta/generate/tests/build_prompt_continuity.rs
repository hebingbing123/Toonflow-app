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
fn build_video_prompt_keeps_only_non_duplicate_continuity_fragments() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["主角冲出旧宅，镜头中景稳定跟拍，情绪急迫，保持上一镜头压迫感".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Continuity notes: 保持上一镜头压迫感."));
    assert!(!prompt.contains("镜头中景稳定跟拍，情绪急迫"));
}

#[test]
fn build_video_prompt_skips_continuity_fragments_covered_after_prefix_trim() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪冷峻压迫，光影冷调逆光".into()],
            continuity_notes: vec!["保持上一镜头冷峻压迫，保留上一镜头走位连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 情绪冷峻压迫，光影冷调逆光."));
    assert!(prompt.contains("Continuity notes: 保留上一镜头走位连续."));
    assert!(!prompt.contains("Continuity notes: 保持上一镜头冷峻压迫"));
}

#[test]
fn build_video_prompt_skips_continuity_fragments_already_covered_by_anchors() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一".into()),
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "黑色风衣，冷色长廊，刀身旧磨损，保持低机位压迫感，保留上一镜头走位连续"
                    .into(),
            ],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
        "{prompt}"
    );
    assert!(
        prompt.contains("Continuity notes: 保留上一镜头走位连续."),
        "{prompt}"
    );
    assert!(!prompt.contains("Continuity notes: 黑色风衣"));
    assert!(!prompt.contains("Continuity notes: 冷色长廊"));
    assert!(!prompt.contains("Continuity notes: 刀身旧磨损"));
    assert!(!prompt.contains("Continuity notes: 保持低机位压迫感"));
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_single_strongest_continuity_note() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一".into()),
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "黑色风衣，冷色长廊，刀身旧磨损，保持低机位压迫感".into(),
                "保留上一镜头走位连续，人物站位不要跳轴".into(),
            ],
        };

    let prompt = build_video_prompt(None, None, Some(&context));
    let continuity_clause = prompt
        .split("Continuity notes: ")
        .nth(1)
        .and_then(|value| value.split('.').next())
        .unwrap_or("");

    assert!(prompt.contains("Continuity notes: 保留上一镜头走位连续，站位不要跳轴."));
    assert_eq!(prompt.matches("Continuity notes:").count(), 1);
    assert!(!continuity_clause.contains("保持低机位压迫感"));
    assert!(prompt.contains("Natural motion, no extra shot changes."));
}

#[test]
fn build_video_prompt_prefers_axis_guidance_over_generic_continuity_under_single_note_budget() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保留上一镜头走位连续".into(), "人物站位不要跳轴".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 站位不要跳轴."),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Continuity notes: 保留上一镜头走位连续."),
        "{prompt}"
    );
    assert!(
        prompt.contains("Natural motion, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_trims_storyboard_subject_and_action_from_continuity_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["主角快步推门冲出保留上一镜头走位连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 保留上一镜头走位连续."),
        "{prompt}"
    );
    assert!(!prompt.contains("主角快步推门冲出"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_full_quality_tail_without_continuity_signal() {
    let prompt = build_video_prompt(
        Some("主角在空旷仓库内缓慢抬头，周围静止无风。"),
        None,
        Some(&VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: None,
            storyboard_duration: None,
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        }),
    );

    assert!(prompt.contains("Natural motion, stable continuity, no extra shot changes."));
}

#[test]
fn build_video_prompt_keeps_full_quality_tail_when_generic_director_continuity_is_trimmed() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片悬疑."), "{prompt}");
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
    assert!(
        prompt.contains("Natural motion, stable continuity, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_pressure_prefers_axis_continuity_for_identity_dialogue_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停顿后看向顾承泽、雨夜走廊、林晚/顾承泽、5秒、近景、静止、林晚抬眼停顿后低声开口、压抑、冷调逆光、你终于来了、雨声压过呼吸声、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "保持上一镜头冷调逆光层次连续".into(),
                "保持上一镜头视线方向一致，人物站位不要跳轴".into(),
            ],
        };
    let pressure = Some(VideoPromptConstraintPressure {
        has_identity_guardrail: true,
        has_dialogue_guardrail: true,
        forces_compact_memory: true,
        ..VideoPromptConstraintPressure::default()
    });

    let result = build_video_prompt_with_constraint_pressure(None, None, Some(&context), pressure);

    assert!(
        result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
    assert!(result.prompt.contains("视线方向一致"), "{}", result.prompt);
    assert!(result.prompt.contains("站位不要跳轴"), "{}", result.prompt);
    assert!(
        !result.prompt.contains("冷调逆光层次连续"),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("No extra shot changes."),
        "{}",
        result.prompt
    );
    assert!(
        !result
            .prompt
            .contains("Natural motion, no extra shot changes."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_drops_generic_continuity_note_when_tail_already_covers_it() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头衔接统一".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Continuity notes:"));
    assert!(prompt.contains("Natural motion, stable continuity, no extra shot changes."));
}

#[test]
fn build_video_prompt_keeps_specific_continuity_guidance_while_dropping_generic_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头衔接统一，人物站位不要跳轴".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Continuity notes: 站位不要跳轴."));
    assert!(!prompt.contains("Continuity notes: 保持上一镜头衔接统一"));
    assert!(prompt.contains("Natural motion, no extra shot changes."));
}

#[test]
fn build_video_prompt_shortens_specific_continuity_wording_without_dropping_guidance() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角对视后停步、旧宅门厅、主角、5秒、中景、静止、停步抬眼、克制紧张、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["人物视线方向一致，镜头方向连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 视线方向一致."),
        "{prompt}"
    );
    assert!(!prompt.contains("人物视线方向一致"), "{prompt}");
    assert!(!prompt.contains("镜头方向连续"), "{prompt}");
}
