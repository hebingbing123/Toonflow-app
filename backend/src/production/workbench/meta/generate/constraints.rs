//! Constraint pressure parsing and scoring helpers.

use crate::production::workbench::meta::common::normalize_prompt_text;
use crate::production::workbench::video::generate::AutoNegativePromptSelection;

use super::{observation_note_budget_family, VideoPromptObservationFamily};

#[derive(Debug, Clone, Copy, Default)]
pub(super) struct VideoPromptConstraintPressure {
    pub(super) has_identity_guardrail: bool,
    pub(super) has_dialogue_guardrail: bool,
    pub(super) has_blocking_guardrail: bool,
    pub(super) has_lighting_guardrail: bool,
    pub(super) has_motion_guardrail: bool,
    pub(super) has_emotion_guardrail: bool,
    pub(super) forces_compact_memory: bool,
}

impl VideoPromptConstraintPressure {
    pub(super) fn from_runtime_constraints(
        selection: Option<&AutoNegativePromptSelection>,
        observation_note: Option<&str>,
    ) -> Option<Self> {
        let mut pressure = Self::default();

        if let Some(selection) = selection {
            pressure.forces_compact_memory = selection.used_pending_observation_fallback
                || selection.fragment_count >= 2
                || selection.budget_tier == "expanded";
            for fragment in split_runtime_negative_constraint_fragments(selection.prompt.as_deref())
            {
                pressure.absorb_fragment(&fragment);
            }
        }

        if let Some(note) = observation_note {
            let trimmed =
                normalize_prompt_text(note.strip_prefix("待观察失败倾向：").unwrap_or(note).trim());
            if !trimmed.is_empty() {
                pressure.forces_compact_memory = true;
                pressure.absorb_fragment(&trimmed);
            }
        }

        pressure.has_active_guardrail().then_some(pressure)
    }

    pub(super) fn has_active_guardrail(self) -> bool {
        self.has_identity_guardrail
            || self.has_dialogue_guardrail
            || self.has_blocking_guardrail
            || self.has_lighting_guardrail
            || self.has_motion_guardrail
            || self.has_emotion_guardrail
    }

    fn absorb_fragment(&mut self, fragment: &str) {
        match observation_note_budget_family(fragment) {
            VideoPromptObservationFamily::Identity => self.has_identity_guardrail = true,
            VideoPromptObservationFamily::Dialogue => self.has_dialogue_guardrail = true,
            VideoPromptObservationFamily::Blocking => self.has_blocking_guardrail = true,
            VideoPromptObservationFamily::Lighting => self.has_lighting_guardrail = true,
            VideoPromptObservationFamily::Motion => self.has_motion_guardrail = true,
            VideoPromptObservationFamily::Emotion => self.has_emotion_guardrail = true,
            VideoPromptObservationFamily::Generic => {}
        }
    }
}

pub(super) fn split_runtime_negative_constraint_fragments(value: Option<&str>) -> Vec<String> {
    value
        .into_iter()
        .flat_map(|text| text.split([',', ';', '，', '；', '\n']))
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .collect()
}
