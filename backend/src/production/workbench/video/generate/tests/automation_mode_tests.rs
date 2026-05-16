use super::super::{merge_negative_selection_constraint_pressure, AutoNegativePromptSelection};

#[test]
fn merge_negative_selection_constraint_pressure_marks_standard_risk_for_expanded_dialogue_guard() {
    let pressure = merge_negative_selection_constraint_pressure(
        vec![AutoNegativePromptSelection {
            prompt: Some("avoid lip-sync mismatch".into()),
            fragment_count: 2,
            candidate_fragment_count: 2,
            saved_fragment_count: 1,
            saved_chars: 12,
            budget_tier: "expanded",
            review_fragment_count: 1,
            rejected_memory_fragment_count: 1,
            used_pending_observation_fallback: false,
        }]
        .into_iter(),
    )
    .expect("pressure");

    assert!(pressure.has_dialogue_guardrail);
    assert!(pressure.forces_compact_memory);
}

#[test]
fn merge_negative_selection_constraint_pressure_ignores_empty_selection_prompts() {
    let pressure = merge_negative_selection_constraint_pressure(
        vec![AutoNegativePromptSelection {
            prompt: None,
            fragment_count: 0,
            candidate_fragment_count: 0,
            saved_fragment_count: 0,
            saved_chars: 0,
            budget_tier: "lean",
            review_fragment_count: 0,
            rejected_memory_fragment_count: 0,
            used_pending_observation_fallback: false,
        }]
        .into_iter(),
    );

    assert!(pressure.is_none());
}
