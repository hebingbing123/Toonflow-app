use super::*;

mod compact;
mod load;
mod select;

// Re-export public functions from load module
pub(in crate::production::workbench::meta::generate) use load::{
    build_video_prompt_memory_notes_with_pressure, load_video_prompt_memory_notes,
    rejected_video_memory_selection_bias,
};

#[cfg(test)]
pub(in crate::production::workbench::meta::generate) use load::build_video_prompt_memory_notes;

// Re-export public functions from select module
#[cfg(test)]
pub(in crate::production::workbench::meta::generate) use select::{
    select_pressure_prioritized_style_note_candidate, select_runtime_action_continuity_fallback,
    select_video_prompt_style_notes, PressureStyleCandidateSource,
};

// Re-export public functions from compact module
pub(in crate::production::workbench::meta::generate) use compact::{
    compact_guardrail_sensitive_style_note, exact_style_note_is_low_signal_template,
    summary_style_note_only_repeats_storyboard_fields,
};

#[cfg(test)]
pub(in crate::production::workbench::meta::generate) use compact::{
    compact_generation_brief_style_note_for_storyboard, compact_guardrail_sensitive_style_notes,
    exact_style_notes_should_yield_to_role_memory, low_signal_local_camera_style_fragment,
    low_signal_template_style_fragment, preserve_delivery_pair_if_compaction_overtrims,
    preserve_runtime_exact_camera_fragment, restore_runtime_exact_style_note_fragments,
    supplement_compacted_voice_note,
};
