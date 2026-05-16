//! Type definitions for video prompt memory module.

use serde::Deserialize;

/// Storyboard prompt seed row from database
#[derive(Debug, Clone, Deserialize, sqlx::FromRow)]
pub(crate) struct StoryboardPromptSeedRow {
    pub(crate) prompt: Option<String>,
    pub(crate) video_desc: Option<String>,
    pub(crate) duration: Option<String>,
}

/// Agent memory row from database
#[derive(Debug, Clone, sqlx::FromRow)]
pub(crate) struct AgentMemoryRow {
    pub(crate) name: String,
    pub(crate) content: String,
}

/// Scoped agent memory row with episode association
#[derive(Debug, Clone, sqlx::FromRow)]
pub(super) struct ScopedAgentMemoryRow {
    pub(super) name: String,
    pub(super) content: String,
    pub(super) episodes_id: Option<i32>,
}

/// Optimizable agent memory row with timestamp
#[derive(Debug, Clone, sqlx::FromRow)]
pub(super) struct OptimizableAgentMemoryRow {
    pub(super) id: i64,
    pub(super) content: String,
    pub(super) create_time_ms: i64,
}

/// Optimization quality focus from database
#[derive(Debug, Clone, sqlx::FromRow)]
pub(super) struct OptimizationQualityFocusDbRow {
    pub(super) feedback_memory_focus_tags: Option<serde_json::Value>,
}

/// Result of video memory optimization operation
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct VideoMemoryOptimizationResult {
    pub(crate) removed_rows: usize,
    pub(crate) removed_chars: usize,
    pub(crate) removed_visual_rows: usize,
    pub(crate) removed_duplicate_rows: usize,
    pub(crate) refreshed_script_summary: bool,
    pub(crate) refreshed_project_summary: bool,
}

/// Candidate for selected video memory optimization
#[derive(Debug, Clone)]
pub(super) struct SelectedVideoMemoryOptimizationCandidate {
    pub(super) id: i64,
    pub(super) content: String,
    pub(super) create_time_ms: i64,
}

/// Effective optimization candidate with processed content
#[derive(Debug, Clone)]
pub(super) struct EffectiveSelectedVideoMemoryOptimizationCandidate<'a> {
    pub(super) row: &'a SelectedVideoMemoryOptimizationCandidate,
    pub(super) content: String,
}

/// Optimization bias preferences
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(super) struct SelectedVideoMemoryOptimizationBias {
    pub(super) prefer_delivery: bool,
    pub(super) prefer_emotion: bool,
    pub(super) prefer_identity: bool,
    pub(super) prefer_lighting: bool,
}

/// Plan for selected video memory optimization
#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub(super) struct SelectedVideoMemoryOptimizationPlan {
    pub(super) delete_ids: Vec<i64>,
    pub(super) removed_chars: usize,
    pub(super) removed_visual_rows: usize,
    pub(super) removed_duplicate_rows: usize,
}

/// Focus flags for selected video memory
pub(super) const SELECTED_VIDEO_MEMORY_FOCUS_DELIVERY: u8 = 1 << 0;
pub(super) const SELECTED_VIDEO_MEMORY_FOCUS_EMOTION: u8 = 1 << 1;
pub(super) const SELECTED_VIDEO_MEMORY_FOCUS_IDENTITY: u8 = 1 << 2;
pub(super) const SELECTED_VIDEO_MEMORY_FOCUS_LIGHTING: u8 = 1 << 3;

/// Structured storyboard description with parsed fields
#[derive(Debug, Clone)]
pub(crate) struct StructuredStoryboardDescription {
    pub(crate) subject: String,
    pub(crate) setting: String,
    pub(crate) subject_refs: String,
    pub(crate) duration_seconds: Option<i32>,
    pub(crate) shot: String,
    pub(crate) camera_move: String,
    pub(crate) action: String,
    pub(crate) mood: String,
    pub(crate) lighting: String,
    pub(crate) dialogue: String,
    pub(crate) sound: String,
}

/// Scope of selected video memory
#[derive(Debug, Clone, PartialEq, Eq)]
pub(super) struct SelectedVideoMemoryScope {
    pub(super) storyboard_ids: String,
    pub(super) prompt_seed: Option<String>,
}

/// Context for style note selection
#[derive(Debug, Clone)]
pub(super) struct StyleNoteSelectionContext {
    pub(super) description: String,
    pub(super) subject: String,
    pub(super) action: String,
    pub(super) shot: String,
    pub(super) camera_move: String,
    pub(super) mood: String,
    pub(super) lighting: String,
    pub(super) dialogue: String,
    pub(super) sound: String,
}

/// Ranked style note with scoring metadata
#[derive(Debug, Clone)]
pub(super) struct RankedStyleNote {
    pub(super) note: String,
    pub(super) context_note: String,
    pub(super) score: i32,
    pub(super) recency_idx: usize,
    pub(super) source_name: String,
    pub(super) storyboard_distance: Option<i32>,
    pub(super) storyboard_focus: usize,
    pub(super) subject_priority: usize,
}

/// Signals from rejected style patterns
#[derive(Debug, Default)]
pub(super) struct RejectedStyleSignals {
    pub(super) monotone_delivery: usize,
    pub(super) cold_lighting: usize,
    pub(super) harsh_backlight: usize,
    pub(super) stable_follow_camera: usize,
    pub(super) shaky_handheld: usize,
    pub(super) oppressive_mood: usize,
    pub(super) cold_emotional_tone: usize,
    pub(super) tragic_mood: usize,
}
