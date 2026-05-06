use crate::production::workbench::meta::generate::constraints::VideoPromptConstraintPressure;
use crate::production::workbench::video_prompt_memory::{
    AgentMemoryRow, StoryboardPromptSeedRow,
};

mod detection;
mod suggestion;

// Re-export public functions
pub(in crate::production::workbench::video::generate) use detection::{
    filter_conflicting_negative_fragments, filter_conflicting_review_fragments,
    review_fragment_is_irrelevant_to_storyboard, storyboard_dialogue_is_empty,
};

pub(in crate::production::workbench::video::generate) use suggestion::{
    compact_rejected_fragments_against_review_focus, compact_review_fragments_against_rejected_memory,
    resolve_negative_conflict_style_note, resolve_negative_filter_style_note,
};

// Re-export for testing
#[cfg(test)]
pub(in crate::production::workbench::video::generate) use detection::{
    compact_negative_constraint_against_storyboard_style,
    review_fragment_conflicts_with_selected_style,
};
