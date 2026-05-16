//! Attribution helpers: patch scope preference and attribution mode detection.

use super::{QualityGateDecision, QualityGateSeverity};

pub(super) fn decision_prefers_patch_scope(decision: &QualityGateDecision) -> &'static str {
    if decision.issues.iter().any(|issue| {
        matches!(
            issue.issue_type.as_str(),
            "character_missing" | "character_anchor_missing"
        )
    }) {
        "scene"
    } else {
        // 含 gaze / limb / physical / anchor drift 等：默认定点回到分镜条目粒度返工
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
                    | "visual_conflict"
                    | "dialogue_emotion_mismatch"
                    | "emotion_progression_flat"
                    | "performance_state_repeat"
            )
    })
}

#[cfg(test)]
mod tests {
    use super::super::QualityGateIssue;
    use super::*;

    fn severe_issue(issue_type: &str) -> QualityGateIssue {
        QualityGateIssue {
            severity: QualityGateSeverity::Severe,
            issue_type: issue_type.to_string(),
            suggestion: "fix".to_string(),
            scope: "storyboardId=1".to_string(),
        }
    }

    #[test]
    fn patch_scope_scene_for_character_anchor_missing() {
        let decision = QualityGateDecision {
            blocked: true,
            issues: vec![severe_issue("character_anchor_missing")],
        };
        assert_eq!(decision_prefers_patch_scope(&decision), "scene");
    }

    #[test]
    fn patch_scope_storyboard_for_gaze_error() {
        let decision = QualityGateDecision {
            blocked: true,
            issues: vec![severe_issue("gaze_direction_error")],
        };
        assert_eq!(decision_prefers_patch_scope(&decision), "storyboard_item");
    }

    #[test]
    fn attribution_suggested_for_visual_conflict_severe() {
        let decision = QualityGateDecision {
            blocked: true,
            issues: vec![severe_issue("visual_conflict")],
        };
        assert!(decision_suggests_attribution(&decision));
    }
}
