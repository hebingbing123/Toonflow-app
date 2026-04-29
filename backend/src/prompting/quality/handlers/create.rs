use axum::{extract::State, http::HeaderMap, Json};
use serde_json::{json, Map, Value};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::metering::llm_usage::link_quality_review_to_job_usage;
use crate::state::AppState;

use super::super::feedback::{
    maybe_write_quality_feedback_to_memory, QualityFeedbackMemoryOutcome,
};
use super::super::types::{CreateQualityReviewBody, QualityReview};
use super::super::validate::validate_create_review_body;

fn merge_feedback_outcome_into_model_params(
    model_params: Option<serde_json::Value>,
    outcome: &QualityFeedbackMemoryOutcome,
) -> Value {
    let mut root = match model_params {
        Some(Value::Object(map)) => map,
        Some(other) => {
            let mut map = Map::new();
            map.insert("legacyModelParams".into(), other);
            map
        }
        None => Map::new(),
    };

    let diagnostics = root
        .entry("diagnostics".to_string())
        .or_insert_with(|| Value::Object(Map::new()));
    if !diagnostics.is_object() {
        *diagnostics = Value::Object(Map::new());
    }
    let diagnostics_obj = diagnostics
        .as_object_mut()
        .expect("diagnostics forced to object");
    diagnostics_obj.insert("feedbackMemory".into(), json!(outcome));
    Value::Object(root)
}

/// POST /api/v1/quality/reviews - 创建质量评估
#[utoipa::path(
    post,
    path = "/api/v1/quality/reviews",
    operation_id = "createQualityReviewV1",
    tag = "quality",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_review(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateQualityReviewBody>,
) -> Result<Json<QualityReview>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_create_review_body(&body)?;
    let pool = state.require_pool()?;

    let source = body.source.as_deref().unwrap_or("manual");
    let is_bad_case = body.is_bad_case.unwrap_or(false);

    let mut review = sqlx::query_as::<_, QualityReview>(
        r#"
        INSERT INTO app_quality_review (
            user_id, project_id, script_id, job_id, target_type, target_id,
            source, plot_coherence, character_consistency, dialogue_naturalness,
            pacing, faithfulness, visual_quality, overall_score, passed,
            comments, skill_version, model_name, model_params, memory_delivery_priority_applied,
            is_bad_case, bad_case_category
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22)
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(body.project_id)
    .bind(body.script_id)
    .bind(body.job_id)
    .bind(&body.target_type)
    .bind(&body.target_id)
    .bind(source)
    .bind(body.plot_coherence)
    .bind(body.character_consistency)
    .bind(body.dialogue_naturalness)
    .bind(body.pacing)
    .bind(body.faithfulness)
    .bind(body.visual_quality)
    .bind(body.overall_score)
    .bind(body.passed)
    .bind(&body.comments)
    .bind(&body.skill_version)
    .bind(&body.model_name)
    .bind(&body.model_params)
    .bind(body.memory_delivery_priority_applied)
    .bind(is_bad_case)
    .bind(&body.bad_case_category)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let (Some(project_id), Some(script_id)) = (review.project_id, review.script_id) {
        match maybe_write_quality_feedback_to_memory(pool, user_id, project_id, script_id, &review)
            .await
        {
            Ok(Some(outcome)) => {
                let merged_model_params =
                    merge_feedback_outcome_into_model_params(review.model_params.clone(), &outcome);
                review = sqlx::query_as::<_, QualityReview>(
                    r#"
                    UPDATE app_quality_review
                    SET model_params = $2, updated_at = NOW()
                    WHERE id = $1
                    RETURNING *
                    "#,
                )
                .bind(review.id)
                .bind(merged_model_params)
                .fetch_one(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            }
            Ok(None) => {}
            Err(error) => {
                tracing::warn!(
                    review_id = %review.id,
                    project_id,
                    script_id,
                    error,
                    "Failed to mirror quality feedback into isolated agent memory"
                );
            }
        }
    }

    let linked = link_quality_review_to_job_usage(
        pool,
        user_id,
        review.job_id,
        review.id,
        review.overall_score,
    )
    .await;
    if linked > 0 {
        tracing::info!(
            quality_review_id = %review.id,
            linked_usage_rows = linked,
            "linked llm usage rows to quality review"
        );
    }

    Ok(Json(review))
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::{merge_feedback_outcome_into_model_params, QualityFeedbackMemoryOutcome};

    #[test]
    fn merge_feedback_outcome_preserves_existing_diagnostics() {
        let merged = merge_feedback_outcome_into_model_params(
            Some(json!({
                "surface": "quality_reviews_workbench",
                "diagnostics": {
                    "promptChars": 512
                }
            })),
            &QualityFeedbackMemoryOutcome {
                action: "promoted_selected_memory".into(),
                agent_type: Some("productionAgent".into()),
                storyboard_id: Some(12),
                memory_name: Some("selected_video_memory".into()),
                cleared_memory_name: Some("rejected_video_negative_memory".into()),
                removed_rows: Some(2),
                removed_chars: Some(88),
                removed_visual_rows: Some(1),
                removed_duplicate_rows: Some(1),
            },
        );

        assert_eq!(merged["surface"], "quality_reviews_workbench");
        assert_eq!(merged["diagnostics"]["promptChars"], 512);
        assert_eq!(
            merged["diagnostics"]["feedbackMemory"]["action"],
            "promoted_selected_memory"
        );
        assert_eq!(merged["diagnostics"]["feedbackMemory"]["removedChars"], 88);
    }

    #[test]
    fn merge_feedback_outcome_wraps_legacy_non_object_model_params() {
        let merged = merge_feedback_outcome_into_model_params(
            Some(json!(["legacy"])),
            &QualityFeedbackMemoryOutcome {
                action: "persisted_rejected_memory".into(),
                agent_type: Some("productionAgent".into()),
                storyboard_id: Some(8),
                memory_name: Some("rejected_video_negative_memory".into()),
                cleared_memory_name: None,
                removed_rows: None,
                removed_chars: None,
                removed_visual_rows: None,
                removed_duplicate_rows: None,
            },
        );

        assert_eq!(merged["legacyModelParams"], json!(["legacy"]));
        assert_eq!(
            merged["diagnostics"]["feedbackMemory"]["memoryName"],
            "rejected_video_negative_memory"
        );
    }
}
