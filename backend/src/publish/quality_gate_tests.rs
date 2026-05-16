//! Tests for quality gate integration in publish workflow.

#[cfg(test)]
mod tests {
    use crate::error::ApiError;
    use crate::production::{
        enforce_quality_gate, QualityGateDecision, QualityGateIssue, QualityGateSeverity,
        QualityGateStage, QualityGateStrategy,
    };

    fn make_issue(severity: QualityGateSeverity, issue_type: &str) -> QualityGateIssue {
        QualityGateIssue {
            severity,
            issue_type: issue_type.to_string(),
            suggestion: "Test suggestion".to_string(),
            scope: "test_scope".to_string(),
        }
    }

    #[test]
    fn test_publish_quality_gate_blocks_severe_issues_with_block_strategy() {
        let decision = QualityGateDecision {
            blocked: true,
            issues: vec![make_issue(QualityGateSeverity::Severe, "character_missing")],
        };

        let result = enforce_quality_gate(
            QualityGateStage::VideoGenerate,
            &decision,
            QualityGateStrategy::Block,
        );

        assert!(result.is_err());
        match result {
            Err(ApiError::Conflict(msg)) => {
                assert!(msg.contains("video_generate"));
            }
            _ => panic!("Expected Conflict error"),
        }
    }

    #[test]
    fn test_publish_quality_gate_allows_with_warn_strategy() {
        let decision = QualityGateDecision {
            blocked: true,
            issues: vec![make_issue(QualityGateSeverity::Severe, "character_missing")],
        };

        let result = enforce_quality_gate(
            QualityGateStage::VideoGenerate,
            &decision,
            QualityGateStrategy::Warn,
        );

        assert!(result.is_ok());
    }

    #[test]
    fn test_publish_quality_gate_allows_with_off_strategy() {
        let decision = QualityGateDecision {
            blocked: true,
            issues: vec![make_issue(QualityGateSeverity::Severe, "character_missing")],
        };

        let result = enforce_quality_gate(
            QualityGateStage::VideoGenerate,
            &decision,
            QualityGateStrategy::Off,
        );

        assert!(result.is_ok());
    }

    #[test]
    fn test_publish_quality_gate_allows_minor_issues_with_block_strategy() {
        let decision = QualityGateDecision {
            blocked: false,
            issues: vec![make_issue(QualityGateSeverity::Minor, "pacing_flat")],
        };

        let result = enforce_quality_gate(
            QualityGateStage::VideoGenerate,
            &decision,
            QualityGateStrategy::Block,
        );

        assert!(result.is_ok());
    }

    #[test]
    fn test_publish_quality_gate_allows_no_issues() {
        let decision = QualityGateDecision {
            blocked: false,
            issues: vec![],
        };

        let result = enforce_quality_gate(
            QualityGateStage::VideoGenerate,
            &decision,
            QualityGateStrategy::Block,
        );

        assert!(result.is_ok());
    }
}
