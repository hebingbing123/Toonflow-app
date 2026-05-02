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
fn build_pending_video_observation_note_from_runtime_reuses_loaded_rows() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚强忍泪意看向门外".into()),
            video_desc: Some("（晚晚强忍泪意看向门外、雨夜门厅、晚晚/林晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、克制、冷调逆光、无台词、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let runtime = StoryboardNegativePromptRuntime {
            storyboard_id: 12,
            selection: AutoNegativePromptSelection {
                prompt: None,
                fragment_count: 0,
                candidate_fragment_count: 0,
                saved_fragment_count: 0,
                saved_chars: 0,
                budget_tier: "lean",
                review_fragment_count: 0,
                rejected_memory_fragment_count: 0,
                used_pending_observation_fallback: false,
            },
            pending_observation_candidates: vec!["avoid identity drift".into()],
            rejected_rows: Vec::new(),
            selected_rows: Vec::new(),
            prompt_support_rows: vec![
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | avoid=avoid identity drift".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=晚晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演抬眼停顿，语气轻声克制".into(),
                },
            ],
            storyboard_row: Some(storyboard_row),
            current_prompt_seed: None,
            subject_candidates,
        };

    assert_eq!(
        build_pending_video_observation_note_from_runtime(&runtime),
        Some("待观察失败倾向：avoid identity drift".to_string())
    );
}

#[test]
fn build_pending_video_observation_note_from_runtime_uses_cached_candidates() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚强忍泪意看向门外".into()),
            video_desc: Some("（晚晚强忍泪意看向门外、雨夜门厅、晚晚/林晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、克制、冷调逆光、无台词、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let runtime = StoryboardNegativePromptRuntime {
            storyboard_id: 12,
            selection: AutoNegativePromptSelection {
                prompt: None,
                fragment_count: 0,
                candidate_fragment_count: 0,
                saved_fragment_count: 0,
                saved_chars: 0,
                budget_tier: "lean",
                review_fragment_count: 0,
                rejected_memory_fragment_count: 0,
                used_pending_observation_fallback: false,
            },
            pending_observation_candidates: vec!["avoid identity drift".into()],
            rejected_rows: Vec::new(),
            selected_rows: Vec::new(),
            prompt_support_rows: vec![AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=晚晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演抬眼停顿，语气轻声克制".into(),
            }],
            storyboard_row: Some(storyboard_row),
            current_prompt_seed: None,
            subject_candidates,
        };

    assert_eq!(
        build_pending_video_observation_note_from_runtime(&runtime),
        Some("待观察失败倾向：avoid identity drift".to_string())
    );
}

#[test]
fn build_pending_video_observation_note_from_runtime_can_use_role_observation_summary_rows() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头低声开口".into()),
            video_desc: Some(
                "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let runtime = StoryboardNegativePromptRuntime {
            storyboard_id: 15,
            selection: AutoNegativePromptSelection {
                prompt: None,
                fragment_count: 0,
                candidate_fragment_count: 0,
                saved_fragment_count: 0,
                saved_chars: 0,
                budget_tier: "lean",
                review_fragment_count: 0,
                rejected_memory_fragment_count: 0,
                used_pending_observation_fallback: false,
            },
            pending_observation_candidates: vec![
                "avoid face distortion or identity drift".into(),
                "avoid blank expression or monotone delivery".into(),
            ],
            rejected_rows: Vec::new(),
            selected_rows: Vec::new(),
            prompt_support_rows: vec![AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=5 | riskTags=identity/dialogue/lighting | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
            }],
            storyboard_row: Some(storyboard_row),
            current_prompt_seed: None,
            subject_candidates,
        };

    assert_eq!(
        build_pending_video_observation_note_from_runtime(&runtime),
        Some("待观察失败倾向：avoid blank expression or monotone delivery".to_string())
    );
}

#[test]
fn build_pending_video_observation_selection_from_runtime_reports_rejected_observation_source() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚强忍泪意看向门外".into()),
            video_desc: Some("（晚晚强忍泪意看向门外、雨夜门厅、晚晚/林晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、克制、冷调逆光、无台词、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let runtime = StoryboardNegativePromptRuntime {
            storyboard_id: 12,
            selection: AutoNegativePromptSelection {
                prompt: None,
                fragment_count: 0,
                candidate_fragment_count: 0,
                saved_fragment_count: 0,
                saved_chars: 0,
                budget_tier: "lean",
                review_fragment_count: 0,
                rejected_memory_fragment_count: 0,
                used_pending_observation_fallback: false,
            },
            pending_observation_candidates: vec!["avoid identity drift".into()],
            rejected_rows: Vec::new(),
            selected_rows: Vec::new(),
            prompt_support_rows: vec![AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | avoid=avoid identity drift".into(),
            }],
            storyboard_row: Some(storyboard_row),
            current_prompt_seed: None,
            subject_candidates,
        };

    let selection = build_pending_video_observation_selection_from_runtime(&runtime)
        .expect("pending observation selection");

    assert_eq!(selection.note, "待观察失败倾向：avoid identity drift");
    assert_eq!(selection.source, "pending_rejected_observation");
}

#[test]
fn build_pending_video_observation_selection_from_runtime_can_use_patch_attribution_source() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚与顾承泽门厅对峙".into()),
            video_desc: Some("（林晚与顾承泽对峙、旧宅门厅、林晚/顾承泽、5秒、中景、稳定跟拍、林晚侧身让开后顾承泽逼近一步、压迫、冷调逆光、别过来、风声回响、A22）".into()),
            duration: Some("5s".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let runtime = StoryboardNegativePromptRuntime {
            storyboard_id: 22,
            selection: AutoNegativePromptSelection {
                prompt: None,
                fragment_count: 0,
                candidate_fragment_count: 0,
                saved_fragment_count: 0,
                saved_chars: 0,
                budget_tier: "lean",
                review_fragment_count: 0,
                rejected_memory_fragment_count: 0,
                used_pending_observation_fallback: false,
            },
            pending_observation_candidates: Vec::new(),
            rejected_rows: Vec::new(),
            selected_rows: Vec::new(),
            prompt_support_rows: vec![AgentMemoryRow {
                name: "patch_attribution:visual_continuity_error:22".into(),
                content: r#"{"category":"visual_continuity_error","summary":"视觉连续性错误，建议先回到 storyboard_panel 修连续性。"}"#.into(),
            }],
            storyboard_row: Some(storyboard_row),
            current_prompt_seed: None,
            subject_candidates,
        };

    let selection = build_pending_video_observation_selection_from_runtime(&runtime)
        .expect("patch attribution observation");

    assert_eq!(
        selection.note,
        "待观察失败倾向：avoid face drift or costume inconsistency"
    );
    assert_eq!(selection.source, "patch_attribution");
}

#[test]
fn generate_video_prompt_response_serializes_observation_note() {
    let value = serde_json::to_value(GenerateVideoPromptResponse {
        prompt: "Single cinematic shot.".into(),
        negative_prompt: None,
        observation_note: Some("待观察失败倾向：avoid shaky handheld motion".into()),
        diagnostics: GenerateVideoPromptDiagnostics {
            prompt_chars: 22,
            negative_prompt_chars: 0,
            negative_constraint_count: 0,
            negative_candidate_fragment_count: 2,
            negative_saved_fragment_count: 2,
            negative_saved_chars: 34,
            negative_budget_tier: "lean".into(),
            auto_negative_source: Some("pending_observation_note".into()),
            auto_negative_review_fragment_count: 0,
            auto_negative_memory_fragment_count: 0,
            observation_note_chars: 40,
            role_anchor_count: 1,
            scene_anchor_count: 1,
            tool_anchor_count: 0,
            style_anchor_count: 1,
            memory_style_anchor_count: 0,
            memory_delivery_anchor_count: 0,
            memory_delivery_priority_applied: false,
            recent_quality_memory_biases: vec!["delivery".into(), "visual_continuity".into()],
            memory_top_candidate_score: 11,
            memory_selected_primary_bucket: Some("表演".into()),
            memory_low_value_candidate_skipped: false,
            memory_style_chars: 0,
            memory_visual_chars: 0,
            memory_delivery_chars: 0,
            memory_hit_buckets: vec!["表演".into(), "语气".into()],
            memory_suppressed_buckets: vec!["动作".into()],
            memory_hit_bucket_counts: [("表演".into(), 2usize), ("语气".into(), 1usize)]
                .into_iter()
                .collect(),
            memory_suppressed_bucket_counts: [("动作".into(), 3usize)].into_iter().collect(),
            memory_optimization_applied: true,
            memory_optimization_removed_rows: 2,
            memory_optimization_removed_chars: 88,
            memory_optimization_removed_visual_rows: 1,
            memory_optimization_removed_duplicate_rows: 1,
            director_manual_yielded_to_memory: false,
            director_manual_yielded_chars: 0,
            director_performance_trimmed_chars: 0,
            director_anchor_saved_chars: 0,
            continuity_note_count: 0,
            continuity_note_chars: 0,
            uses_reference_frame: false,
            memory_budget_tier: "lean".into(),
            memory_budget_risk_score: 0,
            memory_budget_reasons: Vec::new(),
            memory_budget_compact_mode: false,
            memory_project_scope_row_count: 1,
            memory_script_scope_row_count: 2,
            memory_role_scope_row_count: 1,
        },
        model: "runway-gen-2".into(),
        duration: 5,
    })
    .expect("serialize response");

    assert_eq!(
        value
            .get("observationNote")
            .and_then(serde_json::Value::as_str),
        Some("待观察失败倾向：avoid shaky handheld motion")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("recentQualityMemoryBiases"))
            .and_then(serde_json::Value::as_array)
            .map(|items| items.len()),
        Some(2)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("negativeSavedChars"))
            .and_then(serde_json::Value::as_u64),
        Some(34)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryProjectScopeRowCount"))
            .and_then(serde_json::Value::as_u64),
        Some(1)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryScriptScopeRowCount"))
            .and_then(serde_json::Value::as_u64),
        Some(2)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryRoleScopeRowCount"))
            .and_then(serde_json::Value::as_u64),
        Some(1)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryHitBuckets"))
            .and_then(serde_json::Value::as_array)
            .map(|items| items.len()),
        Some(2)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memorySuppressedBuckets"))
            .and_then(serde_json::Value::as_array)
            .map(|items| items.len()),
        Some(1)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryHitBucketCounts"))
            .and_then(|item| item.get("表演"))
            .and_then(serde_json::Value::as_u64),
        Some(2)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memorySuppressedBucketCounts"))
            .and_then(|item| item.get("动作"))
            .and_then(serde_json::Value::as_u64),
        Some(3)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryTopCandidateScore"))
            .and_then(serde_json::Value::as_i64),
        Some(11)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memorySelectedPrimaryBucket"))
            .and_then(serde_json::Value::as_str),
        Some("表演")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryLowValueCandidateSkipped"))
            .and_then(serde_json::Value::as_bool),
        Some(false)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("promptChars"))
            .and_then(serde_json::Value::as_u64),
        Some(22)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("negativeConstraintCount"))
            .and_then(serde_json::Value::as_u64),
        Some(0)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("negativeBudgetTier"))
            .and_then(serde_json::Value::as_str),
        Some("lean")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("autoNegativeSource"))
            .and_then(serde_json::Value::as_str),
        Some("pending_observation_note")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryBudgetTier"))
            .and_then(serde_json::Value::as_str),
        Some("lean")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryDeliveryAnchorCount"))
            .and_then(serde_json::Value::as_u64),
        Some(0)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryDeliveryPriorityApplied"))
            .and_then(serde_json::Value::as_bool),
        Some(false)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryOptimizationApplied"))
            .and_then(serde_json::Value::as_bool),
        Some(true)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryOptimizationRemovedChars"))
            .and_then(serde_json::Value::as_u64),
        Some(88)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("directorManualYieldedToMemory"))
            .and_then(serde_json::Value::as_bool),
        Some(false)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("directorAnchorSavedChars"))
            .and_then(serde_json::Value::as_u64),
        Some(0)
    );
}

#[test]
fn observation_note_conflict_filter_keeps_non_conflicting_warnings() {
    assert!(!video_prompt_observation_conflicts_with_style(
        "avoid face drift or costume inconsistency",
        Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
        None,
    ));
    assert!(!video_prompt_observation_conflicts_with_style(
        "avoid flat cold lighting",
        None,
        None,
    ));
}

#[test]
fn observation_note_conflict_filter_can_fall_back_to_next_candidate() {
    let note = [
        "avoid flat cold lighting".to_string(),
        "avoid shaky handheld motion".to_string(),
    ]
    .into_iter()
    .find(|note| {
        !video_prompt_observation_conflicts_with_style(
            note,
            Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
            None,
        )
    });

    assert_eq!(note, Some("avoid shaky handheld motion".to_string()));
}

#[test]
fn prune_low_signal_observation_candidates_drops_single_generic_mood_note() {
    assert!(prune_low_signal_observation_candidates(vec![
        "avoid overly cold emotional tone".to_string()
    ])
    .is_empty());
}

#[test]
fn prune_low_signal_observation_candidates_keeps_specific_note_while_dropping_generic_retry() {
    assert_eq!(
        prune_low_signal_observation_candidates(vec![
            "avoid repeating stable follow camera".to_string(),
            "avoid extreme camera angle".to_string(),
        ]),
        vec!["avoid extreme camera angle".to_string()]
    );
}

#[test]
fn prune_storyboard_observation_candidates_drops_mood_only_note_for_low_risk_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（男主坐在木桌前、室内书房、男主、4秒、中景、静止、低头翻开信纸、平静、室内暖光、无台词、纸张摩擦声、A03）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert!(prune_storyboard_observation_candidates(
        vec!["avoid overly cold emotional tone".into()],
        Some(&storyboard_row)
    )
    .is_empty());
}
