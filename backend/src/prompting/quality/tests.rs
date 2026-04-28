//! prompting/quality 单元测试。

use crate::error::ApiError;
use serde_json::json;

use super::types::{
    CreateQualityReviewBody, ListQualityReviewsQuery, ListQualityTokenEfficiencySamplesQuery,
};
use super::validate::{
    validate_create_review_body, validate_list_reviews_query,
    validate_token_efficiency_samples_query,
};

#[test]
fn create_quality_review_body_accepts_valid() {
    let json = json!({
        "targetType": "storyboard",
        "plotCoherence": 8,
        "characterConsistency": 9,
        "dialogueNaturalness": 7,
        "pacing": 8,
        "faithfulness": 9,
        "overallScore": 8,
        "passed": true,
        "comments": "整体质量良好",
        "isBadCase": false
    });
    let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
    assert_eq!(body.target_type, "storyboard");
    assert_eq!(body.plot_coherence, Some(8));
    assert_eq!(body.passed, Some(true));
}

#[test]
fn create_quality_review_body_rejects_unknown_fields() {
    let json = json!({
        "targetType": "storyboard",
        "unknownField": "value"
    });
    let result: Result<CreateQualityReviewBody, _> = serde_json::from_value(json);
    assert!(result.is_err());
}

#[test]
fn create_quality_review_body_accepts_bad_case() {
    let json = json!({
        "targetType": "script",
        "isBadCase": true,
        "badCaseCategory": "plot_hole",
        "comments": "剧情跑题严重",
        "overallScore": 3,
        "passed": false
    });
    let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
    assert_eq!(body.is_bad_case, Some(true));
    assert_eq!(body.bad_case_category, Some("plot_hole".to_string()));
}

#[test]
fn create_quality_review_body_accepts_minimal() {
    let json = json!({
        "targetType": "output"
    });
    let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
    assert_eq!(body.target_type, "output");
    assert_eq!(body.source, None);
}

#[test]
fn validate_create_review_body_rejects_invalid_source() {
    let body = CreateQualityReviewBody {
        target_type: "script".to_string(),
        source: Some("robot".to_string()),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("invalid source");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_rejects_invalid_target_type() {
    let body = CreateQualityReviewBody {
        target_type: "chapter".to_string(),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("invalid target_type");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_rejects_out_of_range_scores() {
    let body = CreateQualityReviewBody {
        target_type: "script".to_string(),
        overall_score: Some(11),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("out of range score");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_list_reviews_query_rejects_invalid_target_type() {
    let query = ListQualityReviewsQuery {
        target_type: Some("chapter".to_string()),
        target_id: None,
        job_id: None,
        source: None,
        is_bad_case: None,
        memory_delivery_priority_applied: None,
        limit: None,
        offset: None,
    };
    let err = validate_list_reviews_query(&query).expect_err("invalid target type");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn token_efficiency_samples_query_accepts_target_type() {
    let query = ListQualityTokenEfficiencySamplesQuery {
        target_type: Some("storyboard".to_string()),
        limit: Some(10),
    };
    validate_token_efficiency_samples_query(&query).expect("valid target_type");
}

#[test]
fn token_efficiency_samples_query_rejects_invalid_target_type() {
    let query = ListQualityTokenEfficiencySamplesQuery {
        target_type: Some("chapter".to_string()),
        limit: Some(10),
    };
    let err = validate_token_efficiency_samples_query(&query).expect_err("invalid target type");
    assert!(matches!(err, ApiError::BadRequest(_)));
}
