//! 人工复核队列单元测试。

#[cfg(test)]
mod unit_tests {
    use crate::prompting::benchmark::review_queue::handlers::{
        validate_review_type, validate_status, validate_submit_body,
    };
    use crate::prompting::benchmark::review_queue::types::SubmitReviewBody;

    #[test]
    fn test_review_type_validation() {
        assert!(validate_review_type("quality").is_ok());
        assert!(validate_review_type("roi").is_ok());
        assert!(validate_review_type("invalid_type").is_err());
        assert!(validate_review_type("").is_err());
    }

    #[test]
    fn test_status_validation() {
        assert!(validate_status("pending").is_ok());
        assert!(validate_status("submitted").is_ok());
        assert!(validate_status("skipped").is_ok());
        assert!(validate_status("completed").is_err());
        assert!(validate_status("").is_err());
    }

    #[test]
    fn test_submit_body_validation() {
        // Valid: JSON object
        let valid = SubmitReviewBody {
            submitted_score: serde_json::json!({
                "overallScore": 85,
                "dimensions": {
                    "characterConsistency": 90,
                    "emotionalExpression": 80
                },
                "issues": ["minor_ai_artifact"],
                "recommendation": "approved"
            }),
        };
        assert!(validate_submit_body(&valid).is_ok());

        // Invalid: not an object
        let invalid_string = SubmitReviewBody {
            submitted_score: serde_json::json!("just a string"),
        };
        assert!(validate_submit_body(&invalid_string).is_err());

        let invalid_array = SubmitReviewBody {
            submitted_score: serde_json::json!([1, 2, 3]),
        };
        assert!(validate_submit_body(&invalid_array).is_err());

        let invalid_null = SubmitReviewBody {
            submitted_score: serde_json::json!(null),
        };
        assert!(validate_submit_body(&invalid_null).is_err());
    }
}

#[cfg(test)]
mod integration_tests {
    // 集成测试需要数据库连接，这里预留测试框架
    // 实际测试在 CI 环境中通过契约测试覆盖
}
