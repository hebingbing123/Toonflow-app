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

    pub(super) fn merge(self, other: Option<Self>) -> Self {
        match other {
            Some(other) => Self {
                has_identity_guardrail: self.has_identity_guardrail || other.has_identity_guardrail,
                has_dialogue_guardrail: self.has_dialogue_guardrail || other.has_dialogue_guardrail,
                has_blocking_guardrail: self.has_blocking_guardrail || other.has_blocking_guardrail,
                has_lighting_guardrail: self.has_lighting_guardrail || other.has_lighting_guardrail,
                has_motion_guardrail: self.has_motion_guardrail || other.has_motion_guardrail,
                has_emotion_guardrail: self.has_emotion_guardrail || other.has_emotion_guardrail,
                forces_compact_memory: self.forces_compact_memory || other.forces_compact_memory,
            },
            None => self,
        }
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

#[derive(Debug, Clone)]
pub(super) struct RecentQualitySignalRow {
    pub(super) passed: Option<bool>,
    pub(super) overall_score: Option<i16>,
    pub(super) dialogue_naturalness: Option<i16>,
    pub(super) character_consistency: Option<i16>,
    pub(super) visual_quality: Option<i16>,
    pub(super) memory_delivery_priority_applied: Option<bool>,
    pub(super) is_bad_case: bool,
    pub(super) bad_case_category: Option<String>,
    pub(super) comments: Option<String>,
}

pub(super) fn derive_recent_quality_constraint_pressure(
    rows: &[RecentQualitySignalRow],
) -> Option<VideoPromptConstraintPressure> {
    let mut pressure = VideoPromptConstraintPressure::default();
    let mut saw_delivery_success = false;

    for row in rows {
        let comment = row
            .comments
            .as_deref()
            .map(normalize_prompt_text)
            .unwrap_or_default()
            .to_lowercase();
        let category = row
            .bad_case_category
            .as_deref()
            .map(normalize_prompt_text)
            .unwrap_or_default()
            .to_lowercase();
        let severe = row.is_bad_case
            || row.passed == Some(false)
            || row.overall_score.is_some_and(|score| score <= 6);

        if row.memory_delivery_priority_applied == Some(true)
            && row.passed.unwrap_or(true)
            && !row.is_bad_case
        {
            saw_delivery_success = true;
        }

        if severe
            || row.character_consistency.is_some_and(|score| score <= 6)
            || contains_any(
                &comment,
                &[
                    "穿帮",
                    "串脸",
                    "脸崩",
                    "角色不一致",
                    "人设不一致",
                    "服装不一致",
                    "五官不一致",
                    "identity",
                    "face drift",
                ],
            )
            || contains_any(&category, &["identity", "character", "consistency"])
        {
            pressure.has_identity_guardrail = true;
        }

        if severe
            || row.dialogue_naturalness.is_some_and(|score| score <= 7)
            || contains_any(
                &comment,
                &[
                    "读文章",
                    "生硬",
                    "口型",
                    "台词",
                    "对白",
                    "没情绪",
                    "单一状态",
                    "平平淡淡",
                    "干念",
                    "monotone",
                    "stiff delivery",
                    "lip sync",
                    "lip-sync",
                ],
            )
            || contains_any(&category, &["dialogue", "delivery", "lip"])
        {
            pressure.has_dialogue_guardrail = true;
        }

        if severe
            || row.visual_quality.is_some_and(|score| score <= 6)
            || contains_any(
                &comment,
                &[
                    "没情绪",
                    "情绪平",
                    "情绪不对",
                    "木",
                    "僵",
                    "没层次",
                    "没有起伏",
                    "blank expression",
                    "emotionless",
                    "flat emotion",
                ],
            )
            || contains_any(&category, &["emotion", "performance"])
        {
            pressure.has_emotion_guardrail = true;
        }
    }

    if saw_delivery_success {
        pressure.has_dialogue_guardrail = true;
        pressure.forces_compact_memory = true;
    }
    if pressure.has_active_guardrail() {
        pressure.forces_compact_memory = true;
        return Some(pressure);
    }
    None
}

fn contains_any(value: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| value.contains(needle))
}

#[cfg(test)]
mod tests {
    use super::{
        derive_recent_quality_constraint_pressure, RecentQualitySignalRow,
        VideoPromptConstraintPressure,
    };

    #[test]
    fn derive_recent_quality_constraint_pressure_marks_dialogue_emotion_and_identity_risks() {
        let pressure = derive_recent_quality_constraint_pressure(&[RecentQualitySignalRow {
            passed: Some(false),
            overall_score: Some(4),
            dialogue_naturalness: Some(5),
            character_consistency: Some(5),
            visual_quality: Some(6),
            memory_delivery_priority_applied: Some(false),
            is_bad_case: true,
            bad_case_category: Some("identity".into()),
            comments: Some("人物穿帮，口型生硬，没情绪像读文章".into()),
        }])
        .expect("pressure");

        assert!(pressure.has_identity_guardrail);
        assert!(pressure.has_dialogue_guardrail);
        assert!(pressure.has_emotion_guardrail);
        assert!(pressure.forces_compact_memory);
    }

    #[test]
    fn derive_recent_quality_constraint_pressure_uses_delivery_success_as_positive_signal() {
        let pressure = derive_recent_quality_constraint_pressure(&[RecentQualitySignalRow {
            passed: Some(true),
            overall_score: Some(8),
            dialogue_naturalness: Some(9),
            character_consistency: Some(8),
            visual_quality: Some(8),
            memory_delivery_priority_applied: Some(true),
            is_bad_case: false,
            bad_case_category: None,
            comments: Some("情绪递进自然".into()),
        }])
        .expect("pressure");

        assert!(pressure.has_dialogue_guardrail);
        assert!(pressure.forces_compact_memory);
    }

    #[test]
    fn merge_combines_pressure_flags() {
        let base = VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            ..VideoPromptConstraintPressure::default()
        };
        let merged = base.merge(Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }));

        assert!(merged.has_dialogue_guardrail);
        assert!(merged.has_identity_guardrail);
        assert!(merged.forces_compact_memory);
    }
}
