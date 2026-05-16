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
fn build_video_prompt_adds_matching_script_role_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec![
                "主角: 黑色风衣，短发，克制冷峻".into(),
                "路人: 灰色外套".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."),);
    assert!(!prompt.contains("路人:灰色外套"));
    assert!(!prompt.contains("Subject: 主角."));
}

#[test]
fn build_video_prompt_keeps_only_strongest_matching_role_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角扶住同伴冲出旧宅、旧宅走廊、主角/同伴、5秒、中景、稳定跟拍、扶住同伴冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec![
                "同伴: 灰色毛衣，神情惊惶".into(),
                "主角: 黑色风衣，短发，克制冷峻".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
    assert!(!prompt.contains("同伴:灰色毛衣，神情惊惶"));
}

#[test]
fn build_video_prompt_skips_generic_role_anchor_without_describe() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 视觉设定延续".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Character anchor:"), "{prompt}");
}

#[test]
fn build_video_prompt_adds_matching_scene_and_tool_anchors() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "街角: 雨夜霓虹".into(),
            ],
            script_tool_anchors: vec![
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
                "雨伞: 黑伞".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
    assert!(!prompt.contains("街角:雨夜霓虹"));
    assert!(!prompt.contains("雨伞:黑伞"));
    assert!(!prompt.contains("Setting: 旧宅走廊."));
}

#[test]
fn build_video_prompt_skips_generic_scene_and_tool_anchor_without_describe() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 场景设定延续".into()],
            script_tool_anchors: vec!["青铜匕首: 道具设定延续".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Scene anchor:"), "{prompt}");
    assert!(!prompt.contains("Prop anchor:"), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_subject_and_action_leading_role_name_when_anchored() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅走廊、旧宅走廊、主角、5秒、中景、稳定跟拍、主角快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
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

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
    assert!(prompt.contains("Subject: 冲出旧宅走廊."));
    assert!(prompt.contains("Action: 快步推门冲出."));
    assert!(!prompt.contains("Action: 主角快步推门冲出."));
}

#[test]
fn build_video_prompt_drops_subject_after_overlap_trim_when_role_anchor_already_covers_identity() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出旧宅后回望、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
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

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
    assert!(!prompt.contains("Subject:"), "{prompt}");
    assert!(
        prompt.contains("Action: 快步推门冲出旧宅后回望."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_trims_role_anchor_fragment_that_mostly_repeats_prompt_mood() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
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

    assert!(prompt.contains("Character anchor: 主角:短发."), "{prompt}");
    assert!(
        !prompt.contains("Character anchor: 主角:黑色风衣"),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Character anchor: 主角:短发，克制冷峻"),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_trims_role_anchor_fragment_that_repeats_prompt_lighting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，阴天冷光侧边高光".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Character anchor: 主角:侧边高光."),
        "{prompt}"
    );
    assert!(!prompt.contains("Character anchor: 主角:黑色风衣，阴天冷光侧边高光."));
    assert_eq!(prompt.matches("阴天冷光").count(), 1, "{prompt}");
    assert_eq!(prompt.matches("黑色风衣").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_trims_role_anchor_fragment_that_repeats_prompt_subject() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣主角，短发碎发".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Character anchor: 主角:短发碎发."),
        "{prompt}"
    );
    assert!(!prompt.contains("Character anchor: 主角:黑色风衣主角，短发碎发."));
    assert_eq!(prompt.matches("黑色风衣主角").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_uses_subject_refs_to_keep_two_role_anchors_for_multi_character_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（两人巷口对峙、雨夜巷口、主角/反派、5秒、中景、稳定跟拍、互相逼近、紧张压迫、冷调逆光、无台词、雨声脚步声、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec![
                "主角: 黑色风衣，短发，左脸旧疤".into(),
                "反派: 湿发，深灰长外套，压低肩线".into(),
                "路人: 模糊背影".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains(
            "Character anchor: 主角:黑色风衣，短发，左脸旧疤; 反派:湿发，深灰长外套，压低肩线."
        ),
        "{prompt}"
    );
    assert!(!prompt.contains("路人:模糊背影"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_scene_anchor_when_it_only_repeats_existing_setting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、潮湿斑驳的旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Scene anchor:"), "{prompt}");
    assert!(!prompt.contains("Setting: 潮湿斑驳的旧宅走廊."), "{prompt}");
}

#[test]
fn build_video_prompt_trims_scene_anchor_fragment_that_repeats_prompt_lighting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，阴天冷光积水反光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，积水反光."),
        "{prompt}"
    );
    assert!(!prompt.contains("旧宅走廊:潮湿斑驳，阴天冷光积水反光."));
    assert_eq!(prompt.matches("阴天冷光").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_trims_scene_anchor_fragment_that_repeats_prompt_setting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 旧宅走廊尽头积水反光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Scene anchor: 旧宅走廊:尽头积水反光."),
        "{prompt}"
    );
    assert!(!prompt.contains("Scene anchor: 旧宅走廊:旧宅走廊尽头积水反光."));
    assert_eq!(prompt.matches("旧宅走廊").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_compacts_tool_prefix_action_when_anchor_already_covers_prop() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首快步穿行、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧青铜匕首快步穿行并回头确认、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
    assert!(prompt.contains("Action: 快步穿行并回头确认."));
    assert!(!prompt.contains("Action: 握紧青铜匕首快步穿行并回头确认."));
}

#[test]
fn build_video_prompt_keeps_two_tool_anchors_for_multi_prop_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊握紧青铜匕首撬开门锁、旧宅走廊、主角/青铜匕首/门锁、5秒、中景、稳定跟拍、握紧匕首撬开门锁后回头确认、急迫、阴天冷光、无台词、金属摩擦声脚步声、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec![
                "门锁: 生锈锁芯，金属划痕".into(),
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
                "雨伞: 黑伞".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Prop anchor: 门锁:生锈锁芯，金属划痕; 青铜匕首:刀身旧磨损，寒光克制."),
        "{prompt}"
    );
    assert!(!prompt.contains("雨伞:黑伞"), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_setting_prefix_already_covered_by_scene_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、缓慢停步抬头观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
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

    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(prompt.contains("Setting: 尽头的门厅."));
    assert!(!prompt.contains("Setting: 旧宅走廊尽头的门厅."));
}

#[test]
fn build_video_prompt_compacts_leading_bridge_before_scene_prefix() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊尽头回头、在旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
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

    assert!(prompt.contains("Setting: 门厅."), "{prompt}");
    assert!(prompt.contains("Action: 停步回头."), "{prompt}");
    assert!(!prompt.contains("Setting: 尽头的门厅."), "{prompt}");
    assert!(!prompt.contains("Action: 尽头停步回头."), "{prompt}");
    assert!(!prompt.contains("Setting: 在旧宅走廊尽头的门厅."));
    assert!(!prompt.contains("Action: 在旧宅走廊尽头停步回头."));
}

#[test]
fn build_video_prompt_keeps_strongest_scene_anchor_but_two_directly_referenced_tool_anchors() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊握紧青铜匕首回头、旧宅走廊/门厅、主角/青铜匕首/门锁、5秒、中景、稳定跟拍、握紧匕首回头、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "门厅: 破损玻璃，潮湿回声".into(),
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
            ],
            script_tool_anchors: vec![
                "门锁: 生锈锁芯".into(),
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(
        prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制; 门锁:生锈锁芯.")
            || prompt.contains("Prop anchor: 门锁:生锈锁芯; 青铜匕首:刀身旧磨损，寒光克制."),
        "{prompt}"
    );
    assert!(!prompt.contains("门厅:破损玻璃，潮湿回声"));
}

#[test]
fn build_video_prompt_keeps_two_scene_anchors_for_transition_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊尽头回头、在旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
                "医院门厅: 冷白瓷砖，回声明亮".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊; 旧宅门厅:破损玻璃，潮湿回声.")
            || prompt.contains(
                "Scene anchor: 旧宅门厅:破损玻璃，潮湿回声; 旧宅走廊:潮湿斑驳，冷色长廊."
            ),
        "{prompt}"
    );
    assert!(!prompt.contains("医院门厅:冷白瓷砖，回声明亮"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_two_scene_anchors_for_structured_multi_setting_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅门厅/走廊尽头、主角、5秒、中景、稳定跟拍、停步回头确认身后动静、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
                "医院门厅: 冷白瓷砖，回声明亮".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊; 旧宅门厅:破损玻璃，潮湿回声.")
            || prompt.contains(
                "Scene anchor: 旧宅门厅:破损玻璃，潮湿回声; 旧宅走廊:潮湿斑驳，冷色长廊."
            ),
        "{prompt}"
    );
    assert!(!prompt.contains("医院门厅:冷白瓷砖，回声明亮"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_single_scene_anchor_for_regular_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(!prompt.contains("旧宅门厅:破损玻璃，潮湿回声"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_leading_asset_coverage_from_fused_continuity_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["黑色风衣主角保留上一镜头走位连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 保留上一镜头走位连续."),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Continuity notes: 黑色风衣主角"),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_prefers_fragile_director_anchor_for_sad_anime_turn() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（沈知微停在雨夜落地窗旁、城市夜景落地窗边、沈知微、4秒、中景、缓推、哽咽后强忍泪意看向窗外、隐忍哽咽、冷蓝窗光与路灯反射、无台词、雨声、A13）".into()),
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
        prompt.contains("Style anchor: 成熟都市言情二次元动画; 神情哀戚, 眼神低垂, 眉头轻锁"),
        "{prompt}"
    );
    assert!(!prompt.contains("动作缓慢"), "{prompt}");
    assert!(!prompt.contains("神情内敛"), "{prompt}");
    assert!(!prompt.contains("眼神深沉"), "{prompt}");
    assert!(!prompt.contains("唇线收紧"), "{prompt}");
}
