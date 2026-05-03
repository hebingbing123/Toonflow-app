//! Attribution helpers: patch scope preference and attribution mode detection.

use super::{QualityGateDecision, QualityGateSeverity};

pub(super) fn decision_prefers_patch_scope(decision: &QualityGateDecision) -> &'static str {
    if decision
        .issues
        .iter()
        .any(|issue| issue.issue_type == "character_missing")
    {
        "scene"
    } else {
        "storyboard_item"
    }
}

pub(super) fn decision_suggests_attribution(decision: &QualityGateDecision) -> bool {
    decision.issues.iter().any(|issue| {
        issue.severity == QualityGateSeverity::Severe
            && matches!(
                issue.issue_type.as_str(),
                "face_identity_drift"
                    | "costume_drift"
                    | "gaze_direction_error"
                    | "limb_incoherence"
                    | "physical_relation_error"
                    | "dialogue_emotion_mismatch"
                    | "emotion_progression_flat"
                    | "performance_state_repeat"
            )
    })
}
