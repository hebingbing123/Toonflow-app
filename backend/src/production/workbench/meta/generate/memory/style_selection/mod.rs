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

// Re-export public functions from select module (tests import via `generate::…`).
#[cfg(test)]
pub(in crate::production::workbench::meta::generate) use select::{
    select_pressure_prioritized_style_note_candidate, select_video_prompt_style_notes,
};

// Re-export public functions from compact module
pub(in crate::production::workbench::meta::generate) use compact::{
    compact_guardrail_sensitive_style_note, exact_style_note_is_low_signal_template,
    summary_style_note_only_repeats_storyboard_fields,
};

#[cfg(test)]
pub(in crate::production::workbench::meta::generate) use compact::exact_style_notes_should_yield_to_role_memory;
