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
fn parse_structured_storyboard_description_extracts_duration() {
    let fields = parse_structured_storyboard_description(
            "（雨夜街角对峙、旧街、主角/反派、6秒、中景、手持跟拍、彼此逼近、紧张、霓虹潮湿反光、你终于来了、雨声脚步声、A1/A2）",
        )
        .expect("structured description");

    assert_eq!(fields.duration_seconds, Some(6));
    assert_eq!(fields.setting, "旧街");
    assert_eq!(fields.dialogue, "你终于来了");
}

#[test]
fn resolve_video_prompt_duration_prefers_hint_then_description_then_default() {
    assert_eq!(
        resolve_video_prompt_duration(
            Some(8),
            Some("（主角、城楼、主角、4s、全景、静止、站立、冷峻、冷光、无台词、风声、A1）"),
            None,
        ),
        8
    );
    assert_eq!(
        resolve_video_prompt_duration(
            None,
            Some("（主角、城楼、主角、4s、全景、静止、站立、冷峻、冷光、无台词、风声、A1）"),
            None,
        ),
        4
    );
    assert_eq!(
        resolve_video_prompt_duration(None, Some("普通描述"), None),
        5
    );
}

#[test]
fn resolve_video_prompt_duration_falls_back_to_storyboard_context() {
    let context = VideoPromptContext {
        storyboard_prompt: None,
        storyboard_video_desc: None,
        storyboard_duration: Some("7 秒".into()),
        storyboard_prompt_seed: None,
        project_art_style: None,
        project_director_manual: None,
        script_role_anchors: Vec::new(),
        script_scene_anchors: Vec::new(),
        script_tool_anchors: Vec::new(),
        memory_style_notes: Vec::new(),
        continuity_notes: Vec::new(),
    };
    assert_eq!(resolve_video_prompt_duration(None, None, Some(&context)), 7);
}

#[test]
fn generate_video_prompt_body_accepts_auto_quality_review_flag() {
    let body: GenerateVideoPromptBody = serde_json::from_str(
        r#"{"projectId":1,"scriptId":2,"storyboardId":3,"autoQualityReview":true}"#,
    )
    .unwrap();
    assert_eq!(body.project_id, Some(1));
    assert_eq!(body.script_id, 2);
    assert_eq!(body.storyboard_id, Some(3));
    assert!(body.auto_quality_review);
}

#[test]
fn build_video_prompt_with_diagnostics_reports_trimmed_director_performance_chars() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚低声开口、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后压住气息低声说你终于来了、隐忍压抑、冷蓝窗光、你终于来了、雨声、A31）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演神情低落，眼神黯淡，眉心轻蹙，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert!(result.diagnostics.director_performance_trimmed_chars > 0);
    assert_eq!(result.diagnostics.director_manual_yielded_chars, 0);
    assert_eq!(
        result.diagnostics.director_anchor_saved_chars,
        result.diagnostics.director_performance_trimmed_chars
    );
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_grounded_low_risk_shot_in_lean_tier_when_continuity_note_is_only_generic_tail(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: vec!["保持上一镜头衔接统一".into()],
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(result.prompt.contains("Single shot."), "{}", result.prompt);
    assert!(
        !result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_drops_specific_continuity_note_without_scene_risk() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: vec!["保留上一镜头走位连续，人物站位不要跳轴".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(!result.prompt.contains("Continuity:"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_single_specific_continuity_note_when_axis_risk_exists()
{
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚对视后停步、咖啡厅门口、林晚、4秒、中景、缓推、对视后停步回头、克制紧张、夜间暖光、你怎么来了、杯碟轻响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅门口: 木门与暖色玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: vec!["保留上一镜头走位连续，人物站位不要跳轴".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "expanded");
    assert_eq!(result.diagnostics.continuity_note_count, 1);
    assert!(
        result
            .prompt
            .contains("Continuity notes: 保留上一镜头走位连续，站位不要跳轴."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_drops_axis_continuity_for_single_subject_dialogue_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边低声说话、咖啡厅窗边、林晚、4秒、中景、缓推、看向门口后低声说你终于来了、隐忍、夜间暖光、你终于来了、轻微杯碟声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与暖色玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演呼吸压住情绪，眼神迟疑".into()],
            continuity_notes: vec!["保留上一镜头走位连续，人物站位不要跳轴".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(!result.prompt.contains("Continuity:"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_drops_axis_continuity_for_multi_subject_filler_utterance_scene(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚和顾承泽对视、咖啡厅门口、林晚/顾承泽、4秒、中景、缓推、对视后微微点头、克制紧张、夜间暖光、嗯、轻微杯碟声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into(), "顾承泽: 深灰大衣".into()],
            script_scene_anchors: vec!["咖啡厅门口: 木门与暖色玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神迟疑，动作轻缓克制".into()],
            continuity_notes: vec!["保留上一镜头走位连续，人物站位不要跳轴".into()],
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(!result.prompt.contains("Continuity:"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_grounded_anchor_complete_shot_in_lean_tier_without_reference_frame(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(result.prompt.contains("Single shot."), "{}", result.prompt);
    assert!(
        result.prompt.contains("Character: 林晚:黑色针织外套."),
        "{}",
        result.prompt
    );
    assert!(
        !result
            .prompt
            .contains("Use the supplied frame as reference."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_drops_subject_and_setting_when_anchor_keys_match() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert!(!result.prompt.contains("Subject:"), "{}", result.prompt);
    assert!(!result.prompt.contains("Setting:"), "{}", result.prompt);
    assert!(
        result.prompt.contains("Character: 林晚:黑色针织外套."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Scene: 咖啡厅窗边:木桌与雨痕玻璃."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Action: 看向窗外."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_subject_when_anchor_key_only_partially_matches() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚看向门外、雨夜门厅、林晚、4秒、中景、稳定跟拍、停步回头、克制、冷调逆光、无台词、雨声回响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚礼服版: 黑色丝绒长裙".into()],
            script_scene_anchors: vec!["旧宅门厅: 雨水反光石阶".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert!(
        result.prompt.contains("Subject: 林晚."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Setting: 雨夜门厅."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_skips_voice_fragment_for_truly_silent_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、隐忍克制、夜间冷蓝窗光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("表演抬眼停顿"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气轻声"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_drops_mood_only_voice_tail_for_emotional_lean_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、欲言又止后低声开口、隐忍哽咽、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气低声克制，环境咖啡热气".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气克制"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声克制"), "{}", result.prompt);
    assert!(!result.prompt.contains("环境咖啡热气"), "{}", result.prompt);
    assert!(
        result.diagnostics.memory_style_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS,
        "{:?}",
        result.diagnostics
    );
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_full_labels_for_high_risk_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚冲出旧宅、旧宅走廊、林晚/青铜匕首、5秒、中景、稳定跟拍、快步推门冲出、哽咽压抑、逆光雨夜、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色风衣，短发".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损".into()],
            memory_style_notes: vec!["表演呼吸发颤，语气哽咽克制".into()],
            continuity_notes: vec!["保留上一镜头走位连续".into()],
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert!(
        result
            .prompt
            .contains("Character anchor: 林晚:黑色风衣，短发."),
        "{}",
        result.prompt
    );
    assert!(
        result
            .prompt
            .contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损."),
        "{}",
        result.prompt
    );
    assert!(result.prompt.contains("Style anchor:"), "{}", result.prompt);
    assert!(
        result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("Character: 林晚"),
        "{}",
        result.prompt
    );
    assert_eq!(result.diagnostics.memory_budget_tier, "expanded");
}

#[test]
fn parse_director_emotion_cues_reads_bundled_emotion_table() {
    let profile = art_style_director_profile("成熟都市言情二次元动画").expect("matched art style");
    let cues = parse_director_emotion_cues(profile.director_storyboard);

    assert!(cues.iter().any(|cue| {
        cue.emotion_terms.iter().any(|term| term == "隐忍")
            && cue.face == "神情内敛，面容沉静"
            && cue.eyes == "眼神深沉，眼底有情绪压抑"
    }));
}

#[test]
fn parse_director_environment_cues_reads_bundled_environment_section() {
    let profile = art_style_director_profile("真人都市写实").expect("matched art style");
    let cues = parse_director_environment_cues(profile.director_storyboard_table_style);

    assert!(cues.iter().any(|cue| cue == "咖啡热气"));
    assert!(cues.iter().any(|cue| cue == "手机屏幕亮灭"));
}

#[test]
fn parse_director_environment_texture_cues_reads_bundled_texture_section() {
    let profile = art_style_director_profile("成熟都市言情二次元动画").expect("matched art style");
    let cues = parse_director_environment_texture_cues(profile.director_storyboard_table_style);

    assert!(cues.iter().any(|cue| cue.cue == "手绘光影斑驳"));
    assert!(cues.iter().any(|cue| cue.cue == "细腻线条动态"));
    assert!(cues.iter().any(|cue| cue.cue == "赛璐璐动态质感"));
}
