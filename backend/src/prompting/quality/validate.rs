//! 质量审查请求校验。

use crate::error::ApiError;

use super::types::{CreateQualityReviewBody, ListQualityReviewsQuery};

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
/// 生成阶段合法值（需求 6.3）
const VALID_STAGES: &[&str] = &[
    "story_skeleton",
    "adaptation_strategy",
    "director_planning",
    "storyboard_table",
    "storyboard_panel",
    "video_prompt",
];
/// 评分等级合法值（需求 6.3）
const VALID_GRADES: &[&str] = &["A", "B", "C", "D"];
const SCORE_FIELD_RANGE: std::ops::RangeInclusive<i16> = 1..=10;

fn target_type_uses_storyboard_numeric_target(target_type: &str) -> bool {
    matches!(target_type, "storyboard" | "video" | "output")
}

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
    if let Some(stage) = query.stage.as_deref() {
        if !VALID_STAGES.contains(&stage) {
            return Err(ApiError::BadRequest(format!(
                "Invalid stage: {}, must be one of {:?}",
                stage, VALID_STAGES
            )));
        }
    }
    if let Some(grade) = query.grade.as_deref() {
        if !VALID_GRADES.contains(&grade) {
            return Err(ApiError::BadRequest(format!(
                "Invalid grade: {grade}, must be one of A, B, C, D"
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

    if body.script_id.is_some() && body.project_id.is_none() {
        return Err(ApiError::BadRequest(
            "projectId is required when scriptId is provided".into(),
        ));
    }

    let uses_storyboard_numeric_target =
        target_type_uses_storyboard_numeric_target(body.target_type.as_str());
    if uses_storyboard_numeric_target {
        let storyboard_id = body
            .target_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .and_then(|value| value.parse::<i32>().ok())
            .filter(|value| *value > 0);
        if matches!(body.target_type.as_str(), "storyboard" | "video" | "output")
            && body.project_id.is_none()
        {
            return Err(ApiError::BadRequest(format!(
                "projectId is required when targetType is {}",
                body.target_type
            )));
        }
        if matches!(body.target_type.as_str(), "storyboard" | "video" | "output")
            && storyboard_id.is_none()
        {
            return Err(ApiError::BadRequest(format!(
                "targetId must be a positive storyboard id when targetType is {}",
                body.target_type
            )));
        }
        if (body.project_id.is_some() || body.script_id.is_some()) && storyboard_id.is_none() {
            return Err(ApiError::BadRequest(format!(
                "targetId must be a positive storyboard id when targetType is {} within project/script scope",
                body.target_type
            )));
        }
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

    // 验证新增字段（需求 6.3）
    if let Some(stage) = body.stage.as_deref() {
        if !VALID_STAGES.contains(&stage) {
            return Err(ApiError::BadRequest(format!(
                "Invalid stage: {}, must be one of {:?}",
                stage, VALID_STAGES
            )));
        }
    }

    if let Some(grade) = body.grade.as_deref() {
        if !VALID_GRADES.contains(&grade) {
            return Err(ApiError::BadRequest(format!(
                "Invalid grade: {grade}, must be one of A, B, C, D"
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

#[cfg(test)]
mod tests {
    use super::target_type_uses_storyboard_numeric_target;

    #[test]
    fn storyboard_numeric_target_types_are_explicit() {
        assert!(target_type_uses_storyboard_numeric_target("storyboard"));
        assert!(target_type_uses_storyboard_numeric_target("video"));
        assert!(target_type_uses_storyboard_numeric_target("output"));
        assert!(!target_type_uses_storyboard_numeric_target("script"));
        assert!(!target_type_uses_storyboard_numeric_target("asset"));
    }
}
