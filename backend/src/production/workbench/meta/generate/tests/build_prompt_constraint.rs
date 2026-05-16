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
fn build_video_prompt_constraint_pressure_can_pull_emotional_scene_back_to_lean_when_base_anchors_are_present(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停步回头、旧宅走廊、林晚、4秒、中景、缓推、回头后强忍情绪低声开口、压抑哽咽、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["旧宅走廊: 冷蓝反光墙面".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪压抑克制，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        None,
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_emotion_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("情绪压抑克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_reference_frame_yields_decorative_style_anchors_for_fragile_dialogue_turn(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边低声开口、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、抿唇停顿后低声说你终于来了、隐忍 / 克制、夜间冷蓝窗光、你终于来了、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演喉结滚动，语气压低气息尾音发颤，环境咖啡热气".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result
        .prompt
        .contains("Use the supplied frame as reference."));
    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(
        result.prompt.contains("语气压低气息尾音发颤"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("咖啡热气"), "{}", result.prompt);
    assert!(!result.prompt.contains("动作自然"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_reference_frame_keeps_visual_style_anchor_when_lighting_guardrail_is_active(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚在镜前低声开口、化妆镜前、林晚、4秒、近景、静止、抿唇停顿后低声说我没事、克制隐忍、暖金逆光、我没事、静场留白、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["化妆镜前: 镜面暖光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演眼神迟疑，光影暖金逆光层次".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(
        result.prompt.contains("光影暖金逆光层次"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_constraint_pressure_keeps_micro_performance_but_drops_generic_voice_and_mood_memory(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、低声说你别看我后喉结发紧、压抑哽咽、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪压抑克制，语气低声克制，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_emotion_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声"), "{}", result.prompt);
    assert!(!result.prompt.contains("情绪压抑"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_identity_guardrail_drops_generic_environment_and_motion_memory() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚在窗边停住、咖啡厅窗边、林晚、4秒、中景、缓推、停住后看向门外、克制、夜间暖光、无台词、轻微杯碟声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与暖色玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["动作克制自然，环境雨丝玻璃，表演眼神迟疑".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演眼神迟疑"), "{}", result.prompt);
    assert!(!result.prompt.contains("动作克制自然"), "{}", result.prompt);
    assert!(!result.prompt.contains("环境雨丝玻璃"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_constraint_pressure_adds_guardrail_performance_anchor_for_flat_dialogue_scene(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边开口、咖啡厅窗边、林晚、4秒、中景、缓推、看向门外说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
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

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_emotion_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(
        result.prompt.contains("气息带情绪起伏"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_constraint_pressure_skips_guardrail_performance_anchor_when_micro_performance_already_present(
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

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_identity_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(
        !result.prompt.contains("眼神先动再开口"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("气息带情绪起伏"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_constraint_pressure_drops_decorative_environment_texture_for_dialogue_guardrail_scene(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（沈知微站在落地窗旁开口、城市夜景落地窗边、沈知微、4秒、中景、缓推、抬眼后压低气息说你终于来了、隐忍 / 克制、冷蓝窗光与路灯反射、你终于来了、雨声、A13）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["沈知微: 米色风衣".into()],
            script_scene_anchors: vec!["城市夜景落地窗边: 雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_identity_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演抬眼停顿"), "{}", result.prompt);
    assert!(
        result.prompt.contains("语气压低气息尾音发颤"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("赛璐璐动态质感"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_constraint_pressure_still_keeps_environment_anchor_for_non_dialogue_lighting_guardrail(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在车窗边停住、雨夜街边车窗、林晚、4秒、中景、静止、抬眼看向倒影、克制隐忍、霓虹反光逆光、无台词、车流闷响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["雨夜街边车窗: 玻璃水痕".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["光影霓虹反光层次".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(
        result.prompt.contains("霓虹") || result.prompt.contains("反光"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_constraint_pressure_keeps_micro_performance_and_lighting_pair_for_identity_close_up(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影、克制隐忍、暖金逆光、无台词、静场留白、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["化妆镜前: 镜面暖光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演眼神迟疑，光影暖金逆光层次，环境镜面微雾".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演眼神迟疑"), "{}", result.prompt);
    assert!(
        result.prompt.contains("光影暖金逆光层次"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("环境镜面微雾"), "{}", result.prompt);
    assert!(
        result.diagnostics.memory_style_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS,
        "{:?}",
        result.diagnostics
    );
}

#[test]
fn build_video_prompt_constraint_pressure_keeps_delivery_and_lighting_pair_for_fragile_dialogue_turn(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚含泪低声说别走、雨夜窗边、林晚、4秒、近景、静止、含泪停顿后低声开口、哽咽克制、冷蓝窗光夹霓虹反光、别走、雨声压住呼吸、A18）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 深灰针织外套".into()],
            script_scene_anchors: vec!["雨夜窗边: 玻璃有潮湿反光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演呼吸发颤，语气低声尾音发颤，光影冷蓝反光层次".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_emotion_guardrail: true,
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演呼吸发颤"), "{}", result.prompt);
    assert!(
        result.prompt.contains("光影冷蓝反光层次"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("语气低声尾音发颤"),
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
fn build_video_prompt_with_reference_frame_compacts_labels_for_crowded_dialogue_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、停顿后低声说你终于来了、隐忍 / 克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气轻声尾音发颤".into()],
            continuity_notes: vec!["保持上一镜头走位连续".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("Single shot."), "{}", result.prompt);
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
    assert!(result.prompt.contains("Style:"), "{}", result.prompt);
    assert!(
        result.prompt.contains("Use supplied frame as reference."),
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
    assert!(
        !result
            .prompt
            .contains("Use the supplied frame as reference."),
        "{}",
        result.prompt
    );
}
