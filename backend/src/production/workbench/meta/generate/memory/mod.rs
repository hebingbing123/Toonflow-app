//! Memory selection, trimming, and observation handling for prompt generation.

use super::*;
use crate::production::workbench::video_prompt_memory::{
    select_pending_rejected_video_observation_candidates_for_subject_with_bias,
    VideoPromptMemorySelectionBias,
};

mod dialogue_risk;
mod observation_notes;
mod observation_selection;
mod observation_style;
mod project_style;
mod style_merge;
mod style_selection;
mod trim;

pub(in crate::production::workbench::meta::generate) use dialogue_risk::*;
pub(in crate::production::workbench::meta::generate) use observation_notes::*;
pub(in crate::production::workbench::meta::generate) use observation_selection::*;
pub(in crate::production::workbench::meta::generate) use observation_style::*;
pub(in crate::production::workbench::meta::generate) use project_style::*;
pub(in crate::production::workbench::meta::generate) use style_merge::*;
pub(in crate::production::workbench::meta::generate) use style_selection::*;
pub(in crate::production::workbench::meta::generate) use trim::*;
