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

proptest! {
    #![proptest_config(ProptestConfig::with_cases(20))]

    // Feature: drama-platform-completion, Property 8: 低风险镜头 lean 预算约束
    // 验证：需求 15.3
    #[test]
    fn prop_grounded_low_risk_shot_stays_in_lean_budget(
        subject in "[A-Za-z]{2,8}",
        setting in "[A-Za-z]{2,10}",
        has_reference_frame in any::<bool>(),
        use_scene_anchor in any::<bool>(),
        use_tool_anchor in any::<bool>(),
    ) {
        prop_assume!(use_scene_anchor || use_tool_anchor);

        let fields = grounded_low_risk_fields(subject.clone(), setting.clone());
        let role_anchors = vec![format!("{subject}: 黑色针织外套")];
        let scene_anchors = use_scene_anchor
            .then_some(vec![format!("{setting}: 木桌与雨痕玻璃")])
            .unwrap_or_default();
        let tool_anchors = use_tool_anchor
            .then_some(vec!["咖啡杯: 陶瓷白杯".to_string()])
            .unwrap_or_default();
        let image_url = has_reference_frame.then_some("https://example.com/frame.png");

        let tier = resolve_video_prompt_memory_budget_tier(
            image_url,
            None,
            Some(&fields),
            &role_anchors,
            &scene_anchors,
            &tool_anchors,
            None,
        );

        prop_assert_eq!(tier, VideoPromptMemoryBudgetTier::Lean);
    }

    // Feature: drama-platform-completion, Property 9: 高风险镜头 expanded 预算约束
    // 验证：需求 15.4
    #[test]
    fn prop_high_risk_shot_escalates_to_expanded_budget(
        subject in "[A-Za-z]{2,8}",
        setting in "[A-Za-z]{2,10}",
    ) {
        let fields = elevated_risk_fields(subject, setting);
        let tier = resolve_video_prompt_memory_budget_tier(
            None,
            None,
            Some(&fields),
            &[],
            &[],
            &[],
            None,
        );

        prop_assert_eq!(tier, VideoPromptMemoryBudgetTier::Expanded);
    }

    // Feature: drama-platform-completion, Property 10: 低信号观察笔记淘汰
    // 验证：需求 16.2
    #[test]
    fn prop_low_signal_observation_notes_are_pruned(
        generic_notes in proptest::collection::vec(prop_oneof![
            Just("avoid repeating stable follow camera".to_string()),
            Just("avoid oppressive or frantic mood".to_string()),
            Just("avoid overly cold emotional tone".to_string()),
            Just("avoid heavy tragic mood".to_string()),
        ], 1..6usize),
        specific_suffix in "[A-Za-z ]{3,18}",
    ) {
        let specific_note = format!("avoid extreme camera angle {}", specific_suffix.trim());
        let mut candidates = generic_notes;
        candidates.push(specific_note.clone());

        let kept = prune_low_signal_observation_candidates(candidates);

        prop_assert_eq!(kept, vec![specific_note]);
    }

    // Feature: drama-platform-completion, Property 11: 观察笔记冲突过滤
    // 验证：需求 16.3
    #[test]
    fn prop_observation_notes_conflicting_with_style_are_filtered(
        pair in prop_oneof![
            Just((
                "avoid flat cold lighting".to_string(),
                "镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string(),
            )),
            Just((
                "avoid oppressive or frantic mood".to_string(),
                "镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string(),
            )),
        ],
        safe_note in prop_oneof![
            Just("avoid face drift or costume inconsistency".to_string()),
            Just("avoid shaky handheld motion".to_string()),
        ],
    ) {
        prop_assert!(video_prompt_observation_conflicts_with_style(
            &pair.0,
            Some(&pair.1),
            None,
        ));
        prop_assert!(!video_prompt_observation_conflicts_with_style(
            &safe_note,
            Some(&pair.1),
            None,
        ));
    }

    // Feature: drama-platform-completion, Property 12: 自动负向约束可追踪
    // 验证：需求 16.5, 16.7
    #[test]
    fn prop_auto_negative_source_remains_traceable_in_review_params(
        source in prop_oneof![
            Just("pending_observation_note".to_string()),
            Just("rejected_memory".to_string()),
            Just("quality_review".to_string()),
        ],
    ) {
        let diagnostics = sample_generate_video_prompt_diagnostics(Some(source.clone()));
        let params = build_auto_quality_review_model_params(&diagnostics);

        prop_assert_eq!(
            params
                .get("diagnostics")
                .and_then(|item| item.get("autoNegativeSource"))
                .and_then(serde_json::Value::as_str),
            Some(source.as_str())
        );
    }
}

#[test]
fn build_video_prompt_keeps_concrete_director_fragment_while_dropping_generic_visual_placeholder() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头语言统一，保持低机位压迫感，光影一致".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头语言统一"), "{prompt}");
    assert!(!prompt.contains("光影一致"), "{prompt}");
}

#[test]
fn build_video_prompt_prioritizes_high_value_director_manual_fragments() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("场景旧宅走廊，保持低机位压迫感，镜头衔接统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感, 质感克制粗粝."));
    assert!(!prompt.contains("场景旧宅走廊"));
    assert!(!prompt.contains("镜头衔接统一"));
}

#[test]
fn build_video_prompt_keeps_action_when_only_dialogue_delivery_remains() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、低声说你终于来了、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Action: 低声说你终于来了."), "{prompt}");
    assert!(prompt.contains("Dialogue: 你终于来了."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_full_template_for_high_risk_emotional_shot() {
    let prompt = build_video_prompt(
            Some("（林晚冲出旧宅、旧宅走廊、林晚、5秒、中景、稳定跟拍、快步推门冲出、哽咽压抑、逆光雨夜、别回头、脚步声门响、A12）"),
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

    assert!(prompt.contains("Single cinematic shot."), "{prompt}");
    assert!(
        prompt.contains("Natural motion, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_keeps_semantic_short_dialogue() {
    let prompt = build_video_prompt(
            Some("（主角猛然回头、旧宅门厅、主角、5秒、中景、推进、猛然回头后抬手示警、紧张、冷调逆光、别出声、风声压过呼吸声、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 别出声."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_fragile_dialogue_even_when_speech_visibility_is_limited() {
    let prompt = build_video_prompt(
            Some("（林晚背对镜头停在走廊尽头、医院走廊、林晚、5秒、远景、拉远、背对镜头停步后失声说我真的撑不住了、崩溃压抑、冷白顶光、我真的撑不住了、空调低鸣、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 我真的撑不住了."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_detailed_door_sound_even_when_action_mentions_door() {
    let prompt = build_video_prompt(
            Some("（林夏、旧宅门厅、林夏、5秒、中景、推进、推门闯入、压迫、冷调逆光、无台词、门轴吱呀作响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Action: 推门闯入."), "{prompt}");
    assert!(prompt.contains("Sound: 门轴吱呀作响."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_unique_director_camera_fragment_after_dropping_generic_mood() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、夜间冷蓝窗光、无台词、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: Some("低机位压迫感，情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("低机位压迫感"), "{prompt}");
    assert!(!prompt.contains("情绪隐忍克制"), "{prompt}");
    assert!(prompt.contains("神情内敛, 眼神深沉, 唇线收紧"), "{prompt}");
}
