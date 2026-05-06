mod compact;
mod filter;
mod r#match;
mod rank;

// Re-export public functions from filter module
pub(in crate::production::workbench::meta::generate) use filter::resolve_observation_filter_style_note;

// Re-export functions used in tests
#[cfg(test)]
pub(in crate::production::workbench::meta::generate) use filter::select_contextual_observation_summary_style_note;

// Re-export public functions from match module
pub(in crate::production::workbench::meta::generate) use r#match::{
    observation_style_note_context_evidence, style_note_matches_shared_keyword_family,
    video_prompt_observation_is_irrelevant_to_storyboard,
};

// Re-export functions used in tests
#[cfg(test)]
pub(in crate::production::workbench::meta::generate) use r#match::video_prompt_observation_conflicts_with_style;
