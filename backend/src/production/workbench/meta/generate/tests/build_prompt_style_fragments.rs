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
fn build_video_prompt_drops_low_value_lighting_continuity_for_grounded_indoor_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（男主坐在木桌前、室内书房、男主、4秒、中景、静止、低头翻开信纸、克制、室内暖光、无台词、纸张摩擦声、A03）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头暖光层次".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Continuity notes:"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_lighting_continuity_for_reflective_night_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（女主站在落地窗边、城市夜景落地窗边、女主、4秒、中景、缓推、看着雨丝划过玻璃、隐忍、冷蓝窗光与路灯反射、无台词、雨声、A18）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头冷蓝反光层次".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 保持上一镜头冷蓝反光层次."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_skips_mood_and_lighting_when_style_anchor_already_covers_them() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪冷峻压迫，光影冷调逆光".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑."), "{prompt}");
    assert!(prompt.contains("Mood: 冷峻压迫."), "{prompt}");
    assert!(prompt.contains("Lighting: 冷调逆光."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_mood_and_lighting_when_style_anchor_is_generic() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
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

    assert!(prompt.contains("Style anchor: 胶片悬疑."));
    assert!(!prompt.contains("镜头衔接统一."));
    assert!(prompt.contains("Mood: 冷峻压迫."));
    assert!(prompt.contains("Lighting: 冷调逆光."));
}

#[test]
fn build_video_prompt_trims_redundant_camera_half_but_keeps_extra_style_hint() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、稳定跟拍、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍压迫感，光影冷调逆光颗粒".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 镜头压迫感，光影颗粒."),
        "{prompt}"
    );
    assert_eq!(prompt.matches("稳定跟拍").count(), 1, "{prompt}");
    assert!(!prompt.contains("光影冷调逆光颗粒"), "{prompt}");
}

#[test]
fn build_video_prompt_deduplicates_semantic_style_fragments_across_sources() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头低机位压迫感，情绪冷峻压迫".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
        "{prompt}"
    );
    assert_eq!(prompt.matches("低机位压迫感").count(), 1, "{prompt}");
    assert!(!prompt.contains("镜头低机位压迫感"), "{prompt}");
    assert!(prompt.contains("Mood: 冷峻压迫."), "{prompt}");
}

#[test]
fn build_video_prompt_skips_explicit_mood_and_lighting_when_style_anchor_already_covers_them() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持冷峻压迫风格，冷调逆光质感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 冷峻压迫风格, 冷调逆光质感."),
        "{prompt}"
    );
    assert!(!prompt.contains("Mood: 冷峻压迫."), "{prompt}");
    assert!(!prompt.contains("Lighting: 冷调逆光."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_tool_prefix_action_when_no_followup_motion_exists() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧青铜匕首、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
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

    assert!(prompt.contains("Action: 握紧青铜匕首."));
}

#[test]
fn build_video_prompt_trims_dialogue_payload_from_action_when_motion_remains() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头并低声说你终于来了、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Action: 驻足回头."), "{prompt}");
    assert!(
        !prompt.contains("Action: 驻足回头并低声说你终于来了."),
        "{prompt}"
    );
    assert!(prompt.contains("Dialogue: 你终于来了."), "{prompt}");
}

#[test]
fn build_video_prompt_drops_continuity_style_note_when_style_anchor_already_covers_it() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头低机位压迫感，人物站位不要跳轴".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
        "{prompt}"
    );
    assert!(
        prompt.contains("Continuity notes: 站位不要跳轴."),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Continuity notes: 保持上一镜头低机位压迫感"),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_drops_continuity_half_already_split_between_storyboard_and_style_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["光影冷调逆光颗粒".into()],
            continuity_notes: vec!["保持上一镜头冷调逆光颗粒".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 光影颗粒."),
        "{prompt}"
    );
    assert!(!prompt.contains("Continuity notes:"), "{prompt}");
    assert_eq!(prompt.matches("颗粒").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_pressure_prefers_lighting_continuity_for_reflection_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在落地窗边、雨夜落地窗边、林晚、5秒、中近景、缓推、停步望向玻璃反光、克制、冷调逆光与霓虹反光、无台词、雨声与车流闷响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "保持上一镜头动作节奏自然".into(),
                "保持上一镜头玻璃反光不过曝".into(),
            ],
        };
    let pressure = Some(VideoPromptConstraintPressure {
        has_lighting_guardrail: true,
        forces_compact_memory: true,
        ..VideoPromptConstraintPressure::default()
    });

    let result = build_video_prompt_with_constraint_pressure(None, None, Some(&context), pressure);

    assert!(
        result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("玻璃反光不过曝"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("动作节奏自然"), "{}", result.prompt);
    assert!(
        result.prompt.contains("No extra shot changes."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_drops_voice_fragment_when_action_and_mood_already_cover_it() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、低声开口后停顿、克制、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_drops_stale_soft_voice_fragment_for_fragile_turning_point() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、呼吸发颤后哽咽开口、哽咽压抑、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气轻声"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_identity_dialogue_scene_keeps_micro_performance_and_high_signal_voice_pair() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚近景低声开口、咖啡厅窗边、林晚、4秒、近景、缓推、抬眼后压低气息说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(
        result.prompt.contains("语气压低气息尾音发颤"),
        "{}",
        result.prompt
    );
    assert!(
        result.diagnostics.memory_style_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS,
        "{:?}",
        result.diagnostics
    );
}

#[test]
fn build_video_prompt_identity_dialogue_scene_still_skips_generic_voice_pair() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚近景低声开口、咖啡厅窗边、林晚、4秒、近景、缓推、抬眼后低声说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_adds_proactive_performance_anchor_for_fragile_dialogue_scene_without_pressure(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚强忍泪意低声说我没事、病房门口、林晚、4秒、近景、缓推、抽气后低声说我没事、压抑、冷白侧光、我没事、空调低鸣、A18）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["病房门口: 冷白墙面与玻璃门".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, Some("https://example.com/frame.png"), Some(&context));

    assert!(prompt.contains("开口前先压住气息"), "{prompt}");
    assert!(prompt.contains("尾音带轻颤"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_proactive_performance_anchor_when_storyboard_already_has_micro_performance(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚近景低声开口、咖啡厅窗边、林晚、4秒、近景、缓推、抬眼后压低气息说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, Some("https://example.com/frame.png"), Some(&context));

    assert!(!prompt.contains("眼神先动再开口"), "{prompt}");
    assert!(!prompt.contains("开口前先压住气息"), "{prompt}");
    assert!(!prompt.contains("尾音带轻颤"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_generic_emotion_and_motion_carryover_for_dialogue_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、停顿后低声说你终于来了、隐忍克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪压抑克制，动作自然，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("情绪压抑"), "{}", result.prompt);
    assert!(!result.prompt.contains("情绪克制"), "{}", result.prompt);
    assert!(!result.prompt.contains("动作自然"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_drops_motion_tail_when_continuity_note_already_carries_motion_guidance() {
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
            continuity_notes: vec!["保持上一镜头动作节奏连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 动作节奏连续."),
        "{prompt}"
    );
    assert!(prompt.contains("No extra shot changes."), "{prompt}");
    assert!(!prompt.contains("Natural motion"), "{prompt}");
    assert!(!prompt.contains("stable continuity"), "{prompt}");
}

#[test]
fn build_video_prompt_adds_environment_style_anchor_for_matching_setting() {
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

    assert!(prompt.contains("咖啡热气"), "{prompt}");
    assert!(prompt.contains("动作自然"), "{prompt}");
}

#[test]
fn build_video_prompt_adds_environment_texture_style_anchor_for_matching_setting() {
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

    assert_eq!(prompt.matches("雨丝划过玻璃").count(), 1, "{prompt}");
    assert!(prompt.contains("赛璐璐动态质感"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_environment_style_anchor_for_dense_environment_storyboard() {
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

    assert!(!prompt.contains("窗帘轻摆"), "{prompt}");
    assert!(!prompt.contains("车流光影"), "{prompt}");
    assert!(!prompt.contains("路灯光晕闪烁"), "{prompt}");
    assert!(prompt.contains("赛璐璐动态质感"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_weak_environment_texture_fallback_without_direct_match() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在公司走廊尽头、公司走廊尽头、林晚、4秒、中景、缓推、拽了拽袖口后停住、隐忍 / 克制、灰冷顶色、无台词、空调低鸣、A41）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色西装外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("细腻线条动态"), "{prompt}");
    assert!(!prompt.contains("手绘光影斑驳"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_shared_performance_keywords_but_keeps_micro_expression_detail() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A24）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿喉结滚动，语气低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(!prompt.contains("表演抬眼停顿喉结滚动"), "{prompt}");
    assert!(!prompt.contains("表演抬眼"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_synonymous_performance_micro_expression_but_keeps_unique_detail() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A25）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演唇线收紧喉结滚动，语气低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(!prompt.contains("表演唇线收紧喉结滚动"), "{prompt}");
    assert!(!prompt.contains("唇线收紧"), "{prompt}");
}
