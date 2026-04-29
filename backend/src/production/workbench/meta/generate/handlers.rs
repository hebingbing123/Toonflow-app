//! HTTP handlers for workbench meta generation.

use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GenerateVideoPromptBody {
    pub(super) project_id: i32,
    pub(super) script_id: i32,
    #[serde(default)]
    pub(super) storyboard_id: Option<i32>,
    #[serde(default)]
    pub(super) auto_quality_review: bool,
    #[serde(default)]
    pub(super) image_url: Option<String>,
    #[serde(default)]
    pub(super) description: Option<String>,
    #[serde(default)]
    pub(super) duration_hint: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GenerateVideoPromptResponse {
    pub(super) prompt: String,
    pub(super) negative_prompt: Option<String>,
    pub(super) observation_note: Option<String>,
    pub(super) diagnostics: GenerateVideoPromptDiagnostics,
    pub(super) model: String,
    pub(super) duration: i32,
}

#[derive(Debug, Serialize, Clone, Default)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GenerateVideoPromptDiagnostics {
    pub(super) prompt_chars: usize,
    pub(super) negative_prompt_chars: usize,
    pub(super) negative_constraint_count: usize,
    pub(super) negative_budget_tier: String,
    pub(super) auto_negative_source: Option<String>,
    pub(super) auto_negative_review_fragment_count: usize,
    pub(super) auto_negative_memory_fragment_count: usize,
    pub(super) observation_note_chars: usize,
    pub(super) role_anchor_count: usize,
    pub(super) scene_anchor_count: usize,
    pub(super) tool_anchor_count: usize,
    pub(super) style_anchor_count: usize,
    pub(super) memory_style_anchor_count: usize,
    pub(super) memory_delivery_anchor_count: usize,
    pub(super) memory_delivery_priority_applied: bool,
    pub(super) recent_quality_memory_biases: Vec<String>,
    pub(super) memory_top_candidate_score: i32,
    pub(super) memory_selected_primary_bucket: Option<String>,
    pub(super) memory_low_value_candidate_skipped: bool,
    pub(super) memory_style_chars: usize,
    pub(super) memory_visual_chars: usize,
    pub(super) memory_delivery_chars: usize,
    pub(super) memory_hit_buckets: Vec<String>,
    pub(super) memory_suppressed_buckets: Vec<String>,
    pub(super) memory_hit_bucket_counts: std::collections::BTreeMap<String, usize>,
    pub(super) memory_suppressed_bucket_counts: std::collections::BTreeMap<String, usize>,
    pub(super) memory_optimization_applied: bool,
    pub(super) memory_optimization_removed_rows: usize,
    pub(super) memory_optimization_removed_chars: usize,
    pub(super) memory_optimization_removed_visual_rows: usize,
    pub(super) memory_optimization_removed_duplicate_rows: usize,
    pub(super) director_manual_yielded_to_memory: bool,
    pub(super) director_manual_yielded_chars: usize,
    pub(super) director_performance_trimmed_chars: usize,
    pub(super) director_anchor_saved_chars: usize,
    pub(super) continuity_note_count: usize,
    pub(super) continuity_note_chars: usize,
    pub(super) uses_reference_frame: bool,
    pub(super) memory_budget_tier: String,
}
