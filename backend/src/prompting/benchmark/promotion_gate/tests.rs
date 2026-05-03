#[cfg(test)]
mod tests {
    use super::super::handlers::{
        classify_auto_decision, validate_decision_value, validate_promotion_request, VariantMetrics,
    };
    use super::super::types::BenchmarkTrendPoint;
    use proptest::prelude::*;

    #[test]
    fn valid_gate_decisions_are_accepted() {
        for decision in ["blocked", "needs_review", "approved", "approved_limited"] {
            assert!(validate_decision_value(decision).is_ok());
        }
    }

    #[test]
    fn invalid_gate_decisions_are_rejected() {
        assert!(validate_decision_value("ship_it").is_err());
        assert!(validate_decision_value("").is_err());
    }

    #[test]
    fn promotion_requires_approved_decision() {
        assert!(validate_promotion_request("approved", true).is_ok());
        assert!(validate_promotion_request("approved_limited", true).is_ok());
        assert!(validate_promotion_request("blocked", true).is_err());
        assert!(validate_promotion_request("needs_review", true).is_err());
    }

    #[test]
    fn severe_guard_failure_is_observable() {
        let metrics = VariantMetrics {
            total_tokens: 1000,
            avg_quality_score: 8.2,
            bad_case_recurrence_count: 0,
            severe_guard_failures: 1,
            requires_human_review_count: 0,
        };
        assert_eq!(metrics.severe_guard_failures, 1);
    }

    proptest! {
        #[test]
        fn prop_guard_regression_is_blocked(
            severe_guard_failures in 1i32..=8,
            quality_score_delta in -2.0f64..2.0f64,
            token_delta_percent in -50.0f64..120.0f64,
            bad_case_recurrence_delta in -5i32..=5
        ) {
            let metrics = VariantMetrics {
                total_tokens: 1000,
                avg_quality_score: 7.5,
                bad_case_recurrence_count: 0,
                severe_guard_failures,
                requires_human_review_count: 0,
            };
            let decision = classify_auto_decision(
                &metrics,
                quality_score_delta,
                token_delta_percent,
                bad_case_recurrence_delta,
                false,
            );
            prop_assert_eq!(decision, "blocked");
        }
    }

    #[test]
    fn trend_point_carries_quality_and_gate_counts() {
        let point = BenchmarkTrendPoint {
            week_start: "2026-04-27".to_string(),
            completed_results: 6,
            avg_quality_score: 8.4,
            total_tokens: 12000,
            bad_case_failures: 1,
            approved_count: 2,
            blocked_count: 1,
        };
        assert_eq!(point.completed_results, 6);
        assert!(point.avg_quality_score > 8.0);
        assert_eq!(point.approved_count, 2);
        assert_eq!(point.blocked_count, 1);
    }
}
