//! 质量审查请求校验。

use crate::error::ApiError;

use super::types::{
    CreateQualityReviewBody, ListQualityReviewsQuery, ListQualityTokenEfficiencySamplesQuery,
};

const VALID_TARGET_TYPES: &[&str] = &["storyboard", "script", "video", "asset", "output"];
const VALID_SOURCES: &[&str] = &["manual", "auto"];
const VALID_BAD_CASE_CATEGORIES: &[&str] = &[
    "plot_hole",
    "character_break",
    "storyboard_mismatch",
    "dialogue_issue",
    "visual_error",
    "pacing_issue",
    "other",
];
const SCORE_FIELD_RANGE: std::ops::RangeInclusive<i16> = 1..=10;

pub(super) fn validate_list_reviews_query(query: &ListQualityReviewsQuery) -> Result<(), ApiError> {
    if let Some(target_type) = query.target_type.as_deref() {
        if !VALID_TARGET_TYPES.contains(&target_type) {
            return Err(ApiError::BadRequest(format!(
                "Invalid target_type: {}, must be one of {:?}",
                target_type, VALID_TARGET_TYPES
            )));
        }
    }
    if let Some(source) = query.source.as_deref() {
        if !VALID_SOURCES.contains(&source) {
            return Err(ApiError::BadRequest(format!(
                "Invalid source: {}, must be one of {:?}",
                source, VALID_SOURCES
            )));
        }
    }

    Ok(())
}

pub(super) fn validate_token_efficiency_samples_query(
    query: &ListQualityTokenEfficiencySamplesQuery,
) -> Result<(), ApiError> {
    if let Some(target_type) = query.target_type.as_deref() {
        if !VALID_TARGET_TYPES.contains(&target_type) {
            return Err(ApiError::BadRequest(format!(
                "Invalid target_type: {}, must be one of {:?}",
                target_type, VALID_TARGET_TYPES
            )));
        }
    }

    Ok(())
}

pub(super) fn validate_create_review_body(body: &CreateQualityReviewBody) -> Result<(), ApiError> {
    if !VALID_TARGET_TYPES.contains(&body.target_type.as_str()) {
        return Err(ApiError::BadRequest(format!(
            "Invalid target_type: {}, must be one of {:?}",
            body.target_type, VALID_TARGET_TYPES
        )));
    }

    if let Some(source) = body.source.as_deref() {
        if !VALID_SOURCES.contains(&source) {
            return Err(ApiError::BadRequest(format!(
                "Invalid source: {}, must be one of {:?}",
                source, VALID_SOURCES
            )));
        }
    }

    if let Some(cat) = body.bad_case_category.as_deref() {
        if !VALID_BAD_CASE_CATEGORIES.contains(&cat) {
            return Err(ApiError::BadRequest(format!(
                "Invalid bad_case_category: {}, must be one of {:?}",
                cat, VALID_BAD_CASE_CATEGORIES
            )));
        }
    }

    for (field, score) in [
        ("plot_coherence", body.plot_coherence),
        ("character_consistency", body.character_consistency),
        ("dialogue_naturalness", body.dialogue_naturalness),
        ("pacing", body.pacing),
        ("faithfulness", body.faithfulness),
        ("visual_quality", body.visual_quality),
        ("overall_score", body.overall_score),
    ] {
        if let Some(score) = score {
            if !SCORE_FIELD_RANGE.contains(&score) {
                return Err(ApiError::BadRequest(format!(
                    "Invalid {field}: {score}, must be between {} and {}",
                    SCORE_FIELD_RANGE.start(),
                    SCORE_FIELD_RANGE.end()
                )));
            }
        }
    }

    Ok(())
}
