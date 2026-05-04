//! Shared test helper functions for video prompt generation tests.

use crate::production::workbench::meta::generate::GenerateVideoPromptDiagnostics;
use crate::production::workbench::video_prompt_memory::StructuredStoryboardDescription;

/// Creates a grounded low-risk storyboard description for testing.
pub(super) fn grounded_low_risk_fields(
    subject: String,
    setting: String,
) -> StructuredStoryboardDescription {
    StructuredStoryboardDescription {
        subject,
        setting,
        subject_refs: String::new(),
        duration_seconds: Some(4),
        shot: "中景".into(),
        camera_move: "缓推".into(),
        action: "看向窗外".into(),
        mood: "平静".into(),
        lighting: "夜间暖光".into(),
        dialogue: "无台词".into(),
        sound: "轻微环境声".into(),
    }
}

/// Creates an elevated risk storyboard description for testing.
pub(super) fn elevated_risk_fields(
    subject: String,
    setting: String,
) -> StructuredStoryboardDescription {
    StructuredStoryboardDescription {
        subject,
        setting,
        subject_refs: String::new(),
        duration_seconds: Some(5),
        shot: "近景".into(),
        camera_move: "手持跟拍".into(),
        action: "喉头滚动后强忍泪意".into(),
        mood: "隐忍压抑".into(),
        lighting: "冷蓝逆光".into(),
        dialogue: "你终于来了".into(),
        sound: "雨声".into(),
    }
}

/// Creates sample diagnostics for testing.
pub(super) fn sample_generate_video_prompt_diagnostics(
    auto_negative_source: Option<String>,
) -> GenerateVideoPromptDiagnostics {
    GenerateVideoPromptDiagnostics {
        prompt_chars: 22,
        negative_prompt_chars: 0,
        negative_constraint_count: 0,
        negative_candidate_fragment_count: 2,
        negative_saved_fragment_count: 2,
        negative_saved_chars: 34,
        negative_budget_tier: "lean".into(),
        auto_negative_source,
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
        memory_optimization_removed_low_value_rows: 1,
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
    }
}
