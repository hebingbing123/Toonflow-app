//! Constraint pressure parsing and scoring helpers.

use crate::production::workbench::meta::common::normalize_prompt_text;
use crate::production::workbench::video::generate::AutoNegativePromptSelection;
use crate::settings::agent_memory::AutomationMemoryMode;

use super::{observation_note_budget_family, VideoPromptObservationFamily};

#[derive(Debug, Clone, Copy, Default)]
pub(crate) struct VideoPromptConstraintPressure {
    pub(crate) has_identity_guardrail: bool,
    pub(crate) has_dialogue_guardrail: bool,
    pub(crate) has_blocking_guardrail: bool,
    pub(crate) has_lighting_guardrail: bool,
    pub(crate) has_motion_guardrail: bool,
    pub(crate) has_emotion_guardrail: bool,
    pub(crate) forces_compact_memory: bool,
    pub(crate) prefer_delivery_memory_recall: bool,
    pub(crate) prefer_visual_continuity_memory_recall: bool,
}

impl VideoPromptConstraintPressure {
    pub(crate) fn from_runtime_constraints(
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

    pub(crate) fn has_active_guardrail(self) -> bool {
        self.has_identity_guardrail
            || self.has_dialogue_guardrail
            || self.has_blocking_guardrail
            || self.has_lighting_guardrail
            || self.has_motion_guardrail
            || self.has_emotion_guardrail
    }

    pub(crate) fn merge(self, other: Option<Self>) -> Self {
        match other {
            Some(other) => Self {
                has_identity_guardrail: self.has_identity_guardrail || other.has_identity_guardrail,
                has_dialogue_guardrail: self.has_dialogue_guardrail || other.has_dialogue_guardrail,
                has_blocking_guardrail: self.has_blocking_guardrail || other.has_blocking_guardrail,
                has_lighting_guardrail: self.has_lighting_guardrail || other.has_lighting_guardrail,
                has_motion_guardrail: self.has_motion_guardrail || other.has_motion_guardrail,
                has_emotion_guardrail: self.has_emotion_guardrail || other.has_emotion_guardrail,
                forces_compact_memory: self.forces_compact_memory || other.forces_compact_memory,
                prefer_delivery_memory_recall: self.prefer_delivery_memory_recall
                    || other.prefer_delivery_memory_recall,
                prefer_visual_continuity_memory_recall: self.prefer_visual_continuity_memory_recall
                    || other.prefer_visual_continuity_memory_recall,
            },
            None => self,
        }
    }

    pub(crate) fn memory_recall_biases(self) -> Vec<String> {
        let mut biases = Vec::new();
        if self.prefer_delivery_memory_recall {
            biases.push("delivery".to_string());
        }
        if self.prefer_visual_continuity_memory_recall {
            biases.push("visual_continuity".to_string());
        }
        biases
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

pub(crate) fn split_runtime_negative_constraint_fragments(value: Option<&str>) -> Vec<String> {
    value
        .into_iter()
        .flat_map(|text| text.split([',', ';', '，', '；', '\n']))
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .collect()
}

#[derive(Debug, Clone)]
pub(crate) struct RecentQualitySignalRow {
    pub(crate) passed: Option<bool>,
    pub(crate) overall_score: Option<i16>,
    pub(crate) dialogue_naturalness: Option<i16>,
    pub(crate) character_consistency: Option<i16>,
    pub(crate) visual_quality: Option<i16>,
    pub(crate) memory_delivery_priority_applied: Option<bool>,
    pub(crate) is_bad_case: bool,
    pub(crate) bad_case_category: Option<String>,
    pub(crate) comments: Option<String>,
    pub(crate) feedback_memory_focus_tags: Vec<String>,
}

pub(crate) fn derive_recent_quality_constraint_pressure(
    rows: &[RecentQualitySignalRow],
) -> Option<VideoPromptConstraintPressure> {
    let mut pressure = VideoPromptConstraintPressure::default();
    let mut saw_delivery_success = false;
    let mut dialogue_like_failures = 0usize;
    let mut emotion_like_failures = 0usize;
    let mut identity_like_failures = 0usize;
    let mut visual_like_failures = 0usize;

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

        for tag in &row.feedback_memory_focus_tags {
            match tag.as_str() {
                "delivery_realism" => {
                    pressure.has_dialogue_guardrail = true;
                    pressure.prefer_delivery_memory_recall = true;
                }
                "emotion_arc" => {
                    pressure.has_emotion_guardrail = true;
                    pressure.prefer_delivery_memory_recall = true;
                }
                "identity_continuity" => {
                    pressure.has_identity_guardrail = true;
                    pressure.prefer_visual_continuity_memory_recall = true;
                }
                "lighting_realism" => {
                    pressure.has_lighting_guardrail = true;
                    pressure.prefer_visual_continuity_memory_recall = true;
                }
                _ => {}
            }
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
            identity_like_failures += 1;
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
            dialogue_like_failures += 1;
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
            emotion_like_failures += 1;
        }

        if severe
            || row.visual_quality.is_some_and(|score| score <= 7)
            || contains_any(
                &comment,
                &[
                    "穿帮",
                    "不自然",
                    "很假",
                    "假脸",
                    "ai感",
                    "像ai",
                    "出戏",
                    "闪烁",
                    "模糊",
                    "flicker",
                    "fake",
                    "unnatural",
                    "plastic",
                ],
            )
            || contains_any(
                &category,
                &["visual", "lighting", "motion", "continuity", "face"],
            )
        {
            visual_like_failures += 1;
        }
    }

    if saw_delivery_success {
        pressure.has_dialogue_guardrail = true;
        pressure.forces_compact_memory = true;
    }
    if saw_delivery_success || dialogue_like_failures + emotion_like_failures > 0 {
        pressure.prefer_delivery_memory_recall = true;
    }
    if identity_like_failures + visual_like_failures > 0 {
        pressure.prefer_visual_continuity_memory_recall = true;
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

fn text_contains_any(text: &str, keywords: &[&str]) -> bool {
    keywords.iter().any(|keyword| text.contains(keyword))
}

pub(crate) fn recent_quality_row_requires_standard_memory_mode(
    row: &RecentQualitySignalRow,
) -> bool {
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

    row.is_bad_case
        || row.passed == Some(false)
        || row.overall_score.is_some_and(|score| score <= 7)
        || row.dialogue_naturalness.is_some_and(|score| score <= 7)
        || row.character_consistency.is_some_and(|score| score <= 7)
        || row.visual_quality.is_some_and(|score| score <= 7)
        || text_contains_any(
            &comment,
            &[
                "读文章",
                "生硬",
                "口型",
                "台词",
                "没情绪",
                "单一状态",
                "平平淡淡",
                "穿帮",
                "串脸",
                "不自然",
                "很假",
                "monotone",
                "stiff",
                "lip sync",
                "identity",
                "face drift",
            ],
        )
        || text_contains_any(
            &category,
            &[
                "dialogue",
                "delivery",
                "lip",
                "identity",
                "character",
                "consistency",
                "emotion",
                "performance",
                "lighting",
                "motion",
            ],
        )
}

pub(crate) fn pressure_requires_standard_memory_mode(
    pressure: VideoPromptConstraintPressure,
) -> bool {
    pressure.forces_compact_memory
        || pressure.has_identity_guardrail
        || pressure.has_dialogue_guardrail
        || pressure.has_blocking_guardrail
        || pressure.has_emotion_guardrail
        || (pressure.has_lighting_guardrail && pressure.has_motion_guardrail)
}

pub(crate) fn infer_adaptive_automation_memory_mode(
    recent_rows: &[RecentQualitySignalRow],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> AutomationMemoryMode {
    if constraint_pressure.is_some_and(pressure_requires_standard_memory_mode)
        || recent_rows
            .iter()
            .any(recent_quality_row_requires_standard_memory_mode)
    {
        AutomationMemoryMode::Standard
    } else {
        AutomationMemoryMode::Lean
    }
}

#[cfg(test)]
mod tests {
    use super::{
        derive_recent_quality_constraint_pressure, infer_adaptive_automation_memory_mode,
        recent_quality_row_requires_standard_memory_mode, RecentQualitySignalRow,
        VideoPromptConstraintPressure,
    };
    use crate::settings::agent_memory::AutomationMemoryMode;

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
            feedback_memory_focus_tags: Vec::new(),
        }])
        .expect("pressure");

        assert!(pressure.has_identity_guardrail);
        assert!(pressure.has_dialogue_guardrail);
        assert!(pressure.has_emotion_guardrail);
        assert!(pressure.forces_compact_memory);
        assert!(pressure.prefer_delivery_memory_recall);
        assert!(pressure.prefer_visual_continuity_memory_recall);
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
            feedback_memory_focus_tags: Vec::new(),
        }])
        .expect("pressure");

        assert!(pressure.has_dialogue_guardrail);
        assert!(pressure.forces_compact_memory);
        assert!(pressure.prefer_delivery_memory_recall);
    }

    #[test]
    fn derive_recent_quality_constraint_pressure_marks_visual_continuity_bias_for_fake_visual_failures(
    ) {
        let pressure = derive_recent_quality_constraint_pressure(&[RecentQualitySignalRow {
            passed: Some(false),
            overall_score: Some(5),
            dialogue_naturalness: Some(8),
            character_consistency: Some(6),
            visual_quality: Some(5),
            memory_delivery_priority_applied: Some(false),
            is_bad_case: true,
            bad_case_category: Some("visual".into()),
            comments: Some("画面不自然而且有穿帮，像 AI 假脸".into()),
            feedback_memory_focus_tags: Vec::new(),
        }])
        .expect("pressure");

        assert!(pressure.prefer_visual_continuity_memory_recall);
    }

    #[test]
    fn derive_recent_quality_constraint_pressure_uses_feedback_memory_focus_tags() {
        let pressure = derive_recent_quality_constraint_pressure(&[RecentQualitySignalRow {
            passed: Some(true),
            overall_score: Some(8),
            dialogue_naturalness: Some(8),
            character_consistency: Some(8),
            visual_quality: Some(8),
            memory_delivery_priority_applied: Some(false),
            is_bad_case: false,
            bad_case_category: None,
            comments: None,
            feedback_memory_focus_tags: vec![
                "delivery_realism".into(),
                "identity_continuity".into(),
                "lighting_realism".into(),
            ],
        }])
        .expect("pressure");

        assert!(pressure.has_dialogue_guardrail);
        assert!(pressure.has_identity_guardrail);
        assert!(pressure.has_lighting_guardrail);
        assert!(pressure.prefer_delivery_memory_recall);
        assert!(pressure.prefer_visual_continuity_memory_recall);
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
        assert!(!merged.prefer_delivery_memory_recall);
        assert!(!merged.prefer_visual_continuity_memory_recall);
    }

    #[test]
    fn adaptive_memory_mode_uses_standard_for_dialogue_failure_rows() {
        let row = RecentQualitySignalRow {
            passed: Some(false),
            overall_score: Some(6),
            dialogue_naturalness: Some(6),
            character_consistency: Some(8),
            visual_quality: Some(8),
            memory_delivery_priority_applied: Some(false),
            is_bad_case: false,
            bad_case_category: Some("dialogue".into()),
            comments: Some("像读文章，口型也僵".into()),
            feedback_memory_focus_tags: Vec::new(),
        };

        assert!(recent_quality_row_requires_standard_memory_mode(&row));
        assert_eq!(
            infer_adaptive_automation_memory_mode(&[row], None),
            AutomationMemoryMode::Standard
        );
    }

    #[test]
    fn adaptive_memory_mode_keeps_lean_for_positive_bias_without_failures() {
        let pressure = VideoPromptConstraintPressure {
            prefer_delivery_memory_recall: true,
            prefer_visual_continuity_memory_recall: true,
            ..VideoPromptConstraintPressure::default()
        };

        assert_eq!(
            infer_adaptive_automation_memory_mode(&[], Some(pressure)),
            AutomationMemoryMode::Lean
        );
    }
}
