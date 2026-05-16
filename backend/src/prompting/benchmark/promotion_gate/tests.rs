#[cfg(test)]
mod cases {
    use super::super::handlers::{
        classify_auto_decision, validate_decision_value, validate_promotion_request, ResultRow,
        VariantMetrics,
    };
    use super::super::types::BenchmarkTrendPoint;
    use proptest::prelude::*;
    use uuid::Uuid;

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

    #[test]
    fn incomplete_scores_do_not_count_as_failures_or_zero_out_quality() {
        let variant_id = Uuid::new_v4();
        let scored = ResultRow {
            variant_id,
            case_type: Some("golden".into()),
            weight: Some(1),
            score_summary: Some(serde_json::json!({
                "overallScore": 88.0,
                "passed": true
            })),
            roi_summary: Some(serde_json::json!({"tokensUsed": 1000})),
            requires_human_review: false,
        };
        let incomplete_bad_case = ResultRow {
            variant_id,
            case_type: Some("bad_case".into()),
            weight: Some(3),
            score_summary: None,
            roi_summary: Some(serde_json::json!({"tokensUsed": 200})),
            requires_human_review: true,
        };

        let metrics = VariantMetrics::from_rows(&[&scored, &incomplete_bad_case]);

        assert!((metrics.avg_quality_score - 88.0).abs() < f64::EPSILON);
        assert_eq!(metrics.bad_case_recurrence_count, 0);
        assert_eq!(metrics.severe_guard_failures, 0);
        assert_eq!(metrics.requires_human_review_count, 1);
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
