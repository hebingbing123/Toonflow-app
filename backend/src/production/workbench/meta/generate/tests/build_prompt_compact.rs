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
fn build_video_prompt_compacts_structured_storyboard_description() {
    let prompt = build_video_prompt(
            Some("（主角独立城楼远眺苍茫大地、城楼、主角/城楼、4s、全景、缓慢推进、负手而立衣袂翻飞、坚定压抑、黄昏冷调侧逆光、无台词、风声衣袂声、A001/A003）"),
            Some("https://example.com/frame.png"),
            None,
        );

    assert!(prompt.contains("Single cinematic shot."));
    assert!(prompt.contains("Subject: 主角独立城楼远眺苍茫大地."));
    assert!(prompt.contains("Camera: 全景, 缓慢推进."));
    assert!(prompt.contains("Use the supplied frame as reference."));
    assert!(!prompt.contains("A001/A003"));
}

#[test]
fn build_video_prompt_adds_compact_project_visual_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一，光影偏冷".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感, 光影偏冷."),
        "{prompt}"
    );
    assert!(!prompt.contains("Format:"));
    assert!(!prompt.contains("镜头衔接统一"));
}

#[test]
fn build_video_prompt_drops_generic_director_visual_placeholders() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头语言统一，风格统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 质感克制粗粝."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头语言统一"), "{prompt}");
    assert!(!prompt.contains("风格统一"), "{prompt}");
    assert!(
        prompt.contains("Natural motion, stable continuity, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_trims_director_manual_fragments_already_covered_by_storyboard() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头稳定跟拍，情绪急迫，光影阴天冷光，镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑."));
    assert!(!prompt.contains("镜头稳定跟拍"));
    assert!(!prompt.contains("情绪急迫"));
    assert!(!prompt.contains("光影阴天冷光"));
}

#[test]
fn build_video_prompt_trims_subject_action_overlap_when_subject_identity_remains() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出旧宅后回望、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Subject: 主角."), "{prompt}");
    assert!(
        prompt.contains("Action: 快步推门冲出旧宅后回望."),
        "{prompt}"
    );
    assert!(!prompt.contains("Subject: 主角冲出旧宅."), "{prompt}");
}

#[test]
fn build_video_prompt_trims_subject_lead_in_from_setting_when_subject_already_exists() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足、主角身后的门厅、主角、5秒、中景、稳定跟拍、抬眼观察、紧张、阴天冷光、无台词、脚步回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Setting: 门厅."), "{prompt}");
    assert!(!prompt.contains("Setting: 主角身后的门厅."), "{prompt}");
}

#[test]
fn build_video_prompt_drops_subject_when_compaction_makes_it_duplicate_action() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角快步推门冲出、旧宅走廊、主角、5秒、中景、稳定跟拍、主角快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Subject:"));
    assert!(prompt.contains("Action: 快步推门冲出."));
}

#[test]
fn build_video_prompt_shortens_quality_tail_when_camera_already_implies_stability() {
    let prompt = build_video_prompt(
            Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）"),
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

    assert!(prompt.contains("Natural motion, no extra shot changes."));
    assert!(!prompt.contains("Natural motion, stable continuity, no extra shot changes."));
}

#[test]
fn build_video_prompt_uses_compact_template_for_grounded_low_risk_shot() {
    let prompt = build_video_prompt(
            Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、看向窗外、平静、暖光、无台词、轻微环境声、A12）"),
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

    assert!(prompt.contains("Single shot."), "{prompt}");
    assert!(!prompt.contains("Single cinematic shot."), "{prompt}");
    assert!(prompt.contains("No extra shot changes."), "{prompt}");
    assert!(!prompt.contains("Natural motion"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_sound_fragments_already_covered_by_dialogue() {
    let prompt = build_video_prompt(
            Some("（主角贴墙疾行、旧宅走廊、主角、5秒、中景、稳定跟拍、屏息快步贴墙前进、紧张、阴天冷光、别回头、低声说别回头，脚步声逼近、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 别回头."));
    assert!(prompt.contains("Sound: 脚步声逼近."));
    assert!(!prompt.contains("Sound: 低声说别回头"));
}

#[test]
fn build_video_prompt_compacts_dialogue_wrapper_prefixes() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 你终于来了."));
    assert!(!prompt.contains("Dialogue: 轻声说：你终于来了."));
}

#[test]
fn build_video_prompt_drops_non_semantic_vocalization_dialogue() {
    let prompt = build_video_prompt(
            Some("（主角踉跄扶墙、废弃走廊、主角、5秒、中景、手持跟拍、踉跄扶墙前行、紧张压迫、冷调逆光、急促喘息、脚步声拖行、A12）"),
            None,
            None,
        );

    assert!(!prompt.contains("Dialogue:"), "{prompt}");
    assert!(prompt.contains("Sound: 脚步声拖行."), "{prompt}");
}

#[test]
fn build_video_prompt_trims_sound_against_compacted_dialogue() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、轻声说：你终于来了、轻声说你终于来了，风声回响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 你终于来了."));
    assert!(prompt.contains("Sound: 风声回响."));
    assert!(!prompt.contains("Sound: 轻声说你终于来了"));
}

#[test]
fn build_video_prompt_drops_brief_dialogue_for_wide_moving_low_visibility_scene() {
    let prompt = build_video_prompt(
            Some("（林晚奔向街口、雨夜街头、林晚、5秒、远景、手持跟拍、穿过雨幕奔跑并喊别回头、紧张、霓虹反光、别回头、脚步声和雨声混在一起、A12）"),
            None,
            None,
        );

    assert!(!prompt.contains("Dialogue:"), "{prompt}");
    assert!(prompt.contains("Action: 穿过雨幕奔跑"), "{prompt}");
    assert!(prompt.contains("Sound: 脚步声和雨声混在一起."), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_speech_only_action_when_low_visibility_dialogue_is_dropped() {
    let prompt = build_video_prompt(
            Some("（林晚冲向街口、雨夜街头、林晚、5秒、远景、手持跟拍、喊别回头、紧张、霓虹反光、别回头、脚步声和雨声混在一起、A12）"),
            None,
            None,
        );

    assert!(!prompt.contains("Dialogue:"), "{prompt}");
    assert!(prompt.contains("Action: 急喊示意."), "{prompt}");
    assert!(!prompt.contains("Action: 喊别回头."), "{prompt}");
}

#[test]
fn build_video_prompt_drops_sound_clause_when_only_dialogue_wrapper_remains() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、你终于来了、轻声说你终于来了、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 你终于来了."));
    assert!(!prompt.contains("Sound:"));
}

#[test]
fn build_video_prompt_compacts_sound_wrapper_prefixes() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、无台词、伴随风声回响，传来木门吱呀声、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Sound: 风声回响，木门吱呀声."), "{prompt}");
    assert!(!prompt.contains("Sound: 伴随风声回响"));
    assert!(!prompt.contains("传来木门吱呀声"));
}

#[test]
fn build_video_prompt_drops_sound_wrapper_when_only_dialogue_payload_remains() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、你终于来了、耳边传来轻声说你终于来了，空气里只剩无音效、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 你终于来了."));
    assert!(!prompt.contains("Sound:"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_low_signal_ambient_sound_clause() {
    let prompt = build_video_prompt(
            Some("（主角缓步推门、旧宅门厅、主角、5秒、中景、慢推、缓步推门进入、压抑、冷调逆光、无台词、背景音乐渐起，四周一片死寂、A12）"),
            None,
            None,
        );

    assert!(!prompt.contains("Sound:"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_generic_footstep_sound_when_action_already_covers_it() {
    let prompt = build_video_prompt(
            Some("（黑衣人、走廊尽头、黑衣人、5秒、中景、慢推、脚步逼近门口、紧张、冷光、、脚步声逼近、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Action: 脚步逼近门口."), "{prompt}");
    assert!(!prompt.contains("Sound:"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_director_micro_expression_when_storyboard_already_states_it() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A14）".into()),
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

    assert!(prompt.contains("Style anchor: 真人都市写实;"), "{prompt}");
    assert!(!prompt.contains("唇线收紧"), "{prompt}");
}
