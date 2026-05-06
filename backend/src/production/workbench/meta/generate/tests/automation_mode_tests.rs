use super::super::{
    infer_adaptive_automation_memory_mode, recent_quality_row_requires_standard_memory_mode,
};
use super::test_helpers::sample_recent_quality_signal_row;
use crate::production::workbench::meta::generate::constraints::VideoPromptConstraintPressure;
use crate::settings::agent_memory::AutomationMemoryMode;

#[test]
fn adaptive_memory_mode_uses_lean_for_clean_recent_quality_rows() {
    let rows = vec![sample_recent_quality_signal_row()];

    assert_eq!(
        infer_adaptive_automation_memory_mode(&rows, None),
        AutomationMemoryMode::Lean
    );
}

#[test]
fn adaptive_memory_mode_uses_standard_for_dialogue_failures() {
    let mut row = sample_recent_quality_signal_row();
    row.dialogue_naturalness = Some(6);
    row.comments = Some("人物像读文章，口型也有点僵".into());

    assert!(recent_quality_row_requires_standard_memory_mode(&row));
    assert_eq!(
        infer_adaptive_automation_memory_mode(&[row], None),
        AutomationMemoryMode::Standard
    );
}

#[test]
fn adaptive_memory_mode_uses_standard_for_identity_or_emotion_runtime_pressure() {
    let pressure = VideoPromptConstraintPressure {
        has_identity_guardrail: true,
        ..VideoPromptConstraintPressure::default()
    };

    assert_eq!(
        infer_adaptive_automation_memory_mode(&[], Some(pressure)),
        AutomationMemoryMode::Standard
    );
}

#[test]
fn adaptive_memory_mode_keeps_lean_for_positive_delivery_bias_without_failures() {
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
