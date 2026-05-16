//! Prompt builder and diagnostics logic.

mod structure;
mod text;

// Re-export all public functions
pub use structure::{
    collect_lean_memory_pair_focuses, collect_reserved_art_style_anchors,
    collect_suppressed_memory_style_bucket_counts, resolve_video_prompt_memory_budget_tier,
    score_compacted_style_note_against_constraint_pressure,
    score_memory_fragment_against_constraint_pressure,
    score_memory_fragment_human_performance_detail, score_memory_style_fragment_for_lean_tier,
    score_memory_style_note_for_expanded_tier, select_best_expressive_memory_pair_for_lean_tier,
    LeanMemoryPairFocus,
};
pub use text::{
    compact_expanded_visual_memory_fragment,
    director_performance_fragment_is_generic_face_carryover,
    director_performance_fragment_is_generic_proactive_hint, generic_motion_style_fragment,
    lighting_fragment_retains_specific_detail, memory_fragment_has_high_signal_voice_detail,
    performance_fragment_has_unique_micro_detail, preserve_high_signal_performance_fragment,
    resolve_video_prompt_description, resolve_video_prompt_duration,
    restore_reference_guardrail_style_detail,
};
