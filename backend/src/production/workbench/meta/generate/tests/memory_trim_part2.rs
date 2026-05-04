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
fn prioritized_video_prompt_memory_prefers_script_summary_over_neighbor_local_framing_when_context_is_missing(
) {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头稳定近景，情绪冷色压迫感 | note=镜头稳定近景，情绪冷色压迫感".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=6 | style=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊 | note=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊".into(),
            },
        ];

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, None),
        Some("情绪冷色压迫感，光影冷调逆光".to_string())
    );
}

#[test]
fn prioritized_video_prompt_memory_keeps_neighbor_local_framing_when_no_summary_exists() {
    let rows = vec![AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | style=镜头稳定近景，情绪冷色压迫感 | note=镜头稳定近景，情绪冷色压迫感".into(),
        }];

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, None),
        Some("情绪冷色压迫感".to_string())
    );
}

#[test]
fn prioritized_video_prompt_memory_prefers_shorter_summary_when_context_signal_is_equal() {
    let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷色压迫感，光影冷调逆光 | note=镜头稳定跟拍，情绪冷色压迫感，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=情绪冷色压迫感，光影冷调逆光 | note=情绪冷色压迫感，光影冷调逆光".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在走廊里停步回头".into()),
            video_desc: Some("（主角停步回头、旧宅走廊、主角、5秒、中景、静止、停步回头、冷色压迫感、冷调逆光、无台词、风声回响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)),
        Some("情绪冷色压迫感，光影冷调逆光".to_string())
    );
}

#[test]
fn build_auto_quality_review_model_params_includes_memory_diagnostics() {
    let diagnostics = GenerateVideoPromptDiagnostics {
        prompt_chars: 120,
        negative_prompt_chars: 24,
        negative_constraint_count: 1,
        negative_candidate_fragment_count: 3,
        negative_saved_fragment_count: 2,
        negative_saved_chars: 29,
        negative_budget_tier: "lean".into(),
        auto_negative_source: Some("rejected_memory".into()),
        auto_negative_review_fragment_count: 1,
        auto_negative_memory_fragment_count: 1,
        observation_note_chars: 18,
        role_anchor_count: 1,
        scene_anchor_count: 1,
        tool_anchor_count: 0,
        style_anchor_count: 2,
        memory_style_anchor_count: 1,
        memory_delivery_anchor_count: 1,
        memory_delivery_priority_applied: true,
        recent_quality_memory_biases: vec!["delivery".into()],
        memory_top_candidate_score: 17,
        memory_selected_primary_bucket: Some("表演".into()),
        memory_low_value_candidate_skipped: true,
        memory_style_chars: 22,
        memory_visual_chars: 0,
        memory_delivery_chars: 22,
        memory_hit_buckets: vec!["表演".into()],
        memory_suppressed_buckets: vec!["环境".into()],
        memory_hit_bucket_counts: [("表演".into(), 1usize)].into_iter().collect(),
        memory_suppressed_bucket_counts: [("环境".into(), 1usize)].into_iter().collect(),
        memory_optimization_applied: false,
        memory_optimization_removed_rows: 0,
        memory_optimization_removed_chars: 0,
        memory_optimization_removed_visual_rows: 0,
        memory_optimization_removed_duplicate_rows: 0,
        memory_optimization_removed_low_value_rows: 0,
        director_manual_yielded_to_memory: false,
        director_manual_yielded_chars: 0,
        director_performance_trimmed_chars: 0,
        director_anchor_saved_chars: 0,
        continuity_note_count: 0,
        continuity_note_chars: 0,
        uses_reference_frame: true,
        memory_budget_tier: "lean".into(),
        memory_budget_risk_score: 0,
        memory_budget_reasons: vec!["grounded_anchor_credit".into()],
        memory_budget_compact_mode: false,
        memory_project_scope_row_count: 2,
        memory_script_scope_row_count: 5,
        memory_role_scope_row_count: 3,
    };

    let value = build_auto_quality_review_model_params(&diagnostics);

    assert_eq!(
        value
            .pointer("/diagnostics/memoryTopCandidateScore")
            .and_then(serde_json::Value::as_i64),
        Some(17)
    );
    assert_eq!(
        value
            .pointer("/diagnostics/memorySelectedPrimaryBucket")
            .and_then(serde_json::Value::as_str),
        Some("表演")
    );
    assert_eq!(
        value
            .pointer("/diagnostics/memoryLowValueCandidateSkipped")
            .and_then(serde_json::Value::as_bool),
        Some(true)
    );
    assert_eq!(
        value
            .pointer("/diagnostics/negativeSavedChars")
            .and_then(serde_json::Value::as_u64),
        Some(29)
    );
    assert_eq!(
        value
            .pointer("/diagnostics/memoryProjectScopeRowCount")
            .and_then(serde_json::Value::as_u64),
        Some(2)
    );
    assert_eq!(
        value
            .pointer("/diagnostics/memoryScriptScopeRowCount")
            .and_then(serde_json::Value::as_u64),
        Some(5)
    );
    assert_eq!(
        value
            .pointer("/diagnostics/memoryRoleScopeRowCount")
            .and_then(serde_json::Value::as_u64),
        Some(3)
    );
}

#[test]
fn build_video_prompt_with_diagnostics_reports_anchor_and_memory_counts() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、停步回头确认身后动静、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损".into()],
            memory_style_notes: vec!["镜头低机位压迫感".into()],
            continuity_notes: vec!["保留上一镜头走位连续".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result
        .prompt
        .contains("Use the supplied frame as reference."));
    assert_eq!(result.diagnostics.role_anchor_count, 1);
    assert_eq!(result.diagnostics.scene_anchor_count, 1);
    assert_eq!(result.diagnostics.tool_anchor_count, 1);
    assert_eq!(result.diagnostics.style_anchor_count, 2);
    assert_eq!(result.diagnostics.memory_style_anchor_count, 1);
    assert_eq!(result.diagnostics.memory_delivery_anchor_count, 0);
    assert!(result.diagnostics.memory_style_chars > 0);
    assert!(result.diagnostics.memory_visual_chars > 0);
    assert_eq!(result.diagnostics.memory_delivery_chars, 0);
    assert!(!result.diagnostics.director_manual_yielded_to_memory);
    assert_eq!(result.diagnostics.director_manual_yielded_chars, 0);
    assert_eq!(result.diagnostics.director_performance_trimmed_chars, 0);
    assert_eq!(result.diagnostics.director_anchor_saved_chars, 0);
    assert_eq!(result.diagnostics.continuity_note_count, 1);
    assert!(result.diagnostics.continuity_note_chars > 0);
    assert!(result.diagnostics.uses_reference_frame);
    assert_eq!(result.diagnostics.memory_budget_tier, "expanded");
    assert!(result.diagnostics.prompt_chars > 0);
}

#[test]
fn build_video_prompt_with_diagnostics_reports_memory_yield_and_delivery_anchor_usage() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A31）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: Some("情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_style_anchor_count, 1);
    assert_eq!(result.diagnostics.memory_delivery_anchor_count, 1);
    assert_eq!(result.diagnostics.memory_visual_chars, 0);
    assert!(result.diagnostics.memory_delivery_chars > 0);
    assert!(result.diagnostics.director_manual_yielded_to_memory);
    assert!(result.diagnostics.director_manual_yielded_chars > 0);
    assert_eq!(
        result.diagnostics.director_anchor_saved_chars,
        result.diagnostics.director_manual_yielded_chars
            + result.diagnostics.director_performance_trimmed_chars
    );
}

#[test]
fn build_video_prompt_with_diagnostics_adds_complementary_memory_anchor_in_expanded_tier() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚缓慢开口、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头微动后低声说你终于来了、隐忍压抑、冷蓝窗光、你终于来了、雨声回响、A31）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec![
                "光影冷蓝窗光，环境雨丝玻璃".into(),
                "表演喉结滚动，语气压低尾音发颤".into(),
            ],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_budget_tier, "expanded");
    assert_eq!(result.diagnostics.memory_style_anchor_count, 2);
    assert_eq!(result.diagnostics.memory_delivery_anchor_count, 1);
    assert!(result.diagnostics.memory_delivery_priority_applied);
    assert!(result.diagnostics.memory_visual_chars > 0);
    assert!(result.diagnostics.memory_delivery_chars > 0);
    assert!(
        result.diagnostics.memory_style_chars <= 56,
        "{}",
        result.prompt
    );
    assert!(
        result
            .prompt
            .contains("Style anchor: 表演喉结滚动，语气压低尾音发颤; 光影冷蓝窗光，环境雨丝玻璃."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_uses_lean_memory_tier_for_grounded_low_risk_shot() {
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

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(result.diagnostics.memory_style_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS);
    assert!(
        !result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
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
        result.prompt.contains("Prop: 咖啡杯:陶瓷白杯."),
        "{}",
        result.prompt
    );
    assert!(
        result
            .prompt
            .contains("Style: 真人都市写实; 咖啡热气; 动作自然; 表演眼神放松."),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("Character anchor:"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("Scene anchor:"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("Prop anchor:"), "{}", result.prompt);
    assert!(
        !result.prompt.contains("Style anchor:"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_prefers_performance_fragment_in_lean_memory_tier() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，环境咖啡热气，表演眼神放松".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演眼神放松"), "{}", result.prompt);
    assert!(!result.prompt.contains("镜头稳定跟拍"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_prefers_micro_expression_fragment_in_lean_memory_tier() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、欲言又止后停顿片刻、隐忍克制、夜间冷蓝窗光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演自然克制，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("表演自然克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_identity_guardrail_drops_generic_voice_memory_without_micro_detail() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、低声说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["语气低声克制，表演喉结滚动".into()],
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
}

#[test]
fn build_video_prompt_with_diagnostics_prefers_lighting_fragment_in_lean_memory_tier_for_reflective_scene(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚立在车窗边、雨夜街边车窗、林晚、4秒、中景、静止、抬眼看向倒影、克制隐忍、霓虹反光逆光、无台词、车流闷响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["雨夜街边车窗: 玻璃水痕".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演眼神放松，光影霓虹反光层次，环境车窗水痕".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(
        result.prompt.contains("光影霓虹反光层次"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("表演眼神放松"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_prefers_motion_fragment_in_lean_memory_tier_for_follow_shot()
{
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚穿过旧楼梯口、旧楼梯口、林晚、4秒、中景、稳定跟拍、快步下楼回头、紧张克制、冷色走廊灯、无台词、脚步空响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色风衣".into()],
            script_scene_anchors: vec!["旧楼梯口: 冷色墙面".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演呼吸发颤，镜头稳定跟拍压迫，动作快步回头停顿".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(
        result.prompt.contains("动作快步回头停顿") || result.prompt.contains("镜头稳定跟拍压迫"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("表演呼吸发颤"), "{}", result.prompt);
    assert!(
        !result.prompt.contains("Natural motion"),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("No extra shot changes."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_skips_low_value_memory_anchor_in_low_risk_lean_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚坐在客厅沙发、客厅沙发、林晚、4秒、中景、静止、安静看向桌面、平静、室内自然光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 米色针织衫".into()],
            script_scene_anchors: vec!["客厅沙发: 木桌与浅灰布艺".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["环境客厅空气安静".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.memory_top_candidate_score, 3);
    assert_eq!(result.diagnostics.memory_selected_primary_bucket, None);
    assert!(result.diagnostics.memory_low_value_candidate_skipped);
    assert_eq!(result.diagnostics.memory_style_anchor_count, 0);
    assert_eq!(result.diagnostics.memory_style_chars, 0);
    assert!(
        !result.prompt.contains("环境客厅空气安静"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_keeps_unique_micro_expression_when_memory_overlaps_director_anchor() {
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
            memory_style_notes: vec!["表演神情内敛眼神深沉喉结滚动，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 真人都市写实; 神情内敛, 眼神深沉, 唇线收紧;"),
        "{prompt}"
    );
    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(!prompt.contains("表演神情内敛眼神深沉喉结滚动"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_director_performance_anchor_when_delivery_memory_already_covers_fragile_turn(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抽气后失声开口、隐忍哽咽、冷蓝窗光、我没事、雨声、A14）".into()),
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

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 真人都市写实;"), "{prompt}");
    assert!(prompt.contains("表演神情低落"), "{prompt}");
    assert!(prompt.contains("语气压低气息尾音发颤"), "{prompt}");
    assert!(
        !prompt.contains("神情低落, 眼神黯淡, 眉心轻蹙;"),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_lets_high_value_memory_replace_generic_director_mood_on_fragile_turn() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A14）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: Some("情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(prompt.contains("语气压低气息尾音发颤"), "{prompt}");
    assert!(!prompt.contains("情绪隐忍克制"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_visual_director_note_even_when_memory_handles_delivery() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A14）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: Some("低机位压迫感，情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("低机位压迫感"), "{prompt}");
    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(prompt.contains("语气压低气息尾音发颤"), "{prompt}");
    assert!(!prompt.contains("情绪隐忍克制"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_compacted_delivery_memory_anchor_high_value() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A31）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: Some("情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("表演喉结滚动低声"), "{prompt}");
}
