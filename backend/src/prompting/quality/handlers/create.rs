use axum::{Json, extract::State, http::HeaderMap};
use serde_json::{Map, Value, json};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::metering::llm_usage::link_quality_review_to_job_usage;
use crate::state::AppState;

use super::super::feedback::{
    QualityFeedbackMemoryOutcome, maybe_write_quality_feedback_to_memory,
};
use super::super::issue_type::infer_issue_types;
use super::super::next_action::infer_next_action;
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

fn merge_issue_diagnostics_into_model_params(
    model_params: Option<serde_json::Value>,
    issue_types: &[super::super::issue_type::IssueType],
    next_action: &super::super::next_action::NextAction,
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
    let d = diagnostics.as_object_mut().expect("diagnostics is object");
    d.insert(
        "issueTypes".into(),
        json!(issue_types.iter().map(|t| t.as_str()).collect::<Vec<_>>()),
    );
    d.insert("nextAction".into(), json!(next_action.as_str()));
    Value::Object(root)
}

async fn validate_review_scope_ownership(
    pool: &PgPool,
    user_id: Uuid,
    project_id: Option<i32>,
    script_id: Option<i32>,
    target_type: &str,
    target_id: Option<&str>,
) -> Result<(), ApiError> {
    match (project_id, script_id) {
        (Some(project_id), Some(script_id)) => {
            let ok: bool = sqlx::query_scalar(
                r#"
                SELECT EXISTS(
                  SELECT 1
                  FROM app_script sc
                  INNER JOIN app_project p ON p.id = sc.project_id
                  WHERE p.owner_user_id = $1
                    AND p.numeric_id = $2
                    AND sc.numeric_id = $3
                )
                "#,
            )
            .bind(user_id)
            .bind(project_id)
            .bind(script_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            if !ok {
                return Err(ApiError::NotFound);
            }
        }
        (Some(project_id), None) => {
            let ok: bool = sqlx::query_scalar(
                r#"
                SELECT EXISTS(
                  SELECT 1
                  FROM app_project
                  WHERE owner_user_id = $1
                    AND numeric_id = $2
                )
                "#,
            )
            .bind(user_id)
            .bind(project_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            if !ok {
                return Err(ApiError::NotFound);
            }
        }
        (None, Some(script_id)) => {
            let ok: bool = sqlx::query_scalar(
                r#"
                SELECT EXISTS(
                  SELECT 1
                  FROM app_script sc
                  INNER JOIN app_project p ON p.id = sc.project_id
                  WHERE p.owner_user_id = $1
                    AND sc.numeric_id = $2
                )
                "#,
            )
            .bind(user_id)
            .bind(script_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            if !ok {
                return Err(ApiError::NotFound);
            }
        }
        (None, None) => {}
    }

    if target_type == "storyboard" {
        let Some(project_id) = project_id else {
            return Ok(());
        };
        let Some(script_id) = script_id else {
            return Ok(());
        };
        let Some(storyboard_id) = target_id
            .map(str::trim)
            .and_then(|value| value.parse::<i32>().ok())
            .filter(|value| *value > 0)
        else {
            return Ok(());
        };
        let ok: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
              SELECT 1
              FROM app_storyboard sb
              INNER JOIN app_script sc ON sc.id = sb.script_id
              INNER JOIN app_project p ON p.id = sc.project_id
              WHERE p.owner_user_id = $1
                AND p.numeric_id = $2
                AND sc.numeric_id = $3
                AND sb.numeric_id = $4
            )
            "#,
        )
        .bind(user_id)
        .bind(project_id)
        .bind(script_id)
        .bind(storyboard_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if !ok {
            return Err(ApiError::NotFound);
        }
    }

    Ok(())
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
    validate_review_scope_ownership(
        pool,
        user_id,
        body.project_id,
        body.script_id,
        &body.target_type,
        body.target_id.as_deref(),
    )
    .await?;

    let source = body.source.as_deref().unwrap_or("manual");
    let is_bad_case = body.is_bad_case.unwrap_or(false);

    let mut review = sqlx::query_as::<_, QualityReview>(
        r#"
        INSERT INTO app_quality_review (
            user_id, project_id, script_id, job_id, target_type, target_id,
            source, plot_coherence, character_consistency, dialogue_naturalness,
            pacing, faithfulness, visual_quality, overall_score, passed,
            comments, skill_version, model_name, model_params, memory_delivery_priority_applied,
            is_bad_case, bad_case_category,
            stage, grade, skill_file_path, skill_version_hash
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26)
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
    .bind(&body.stage)
    .bind(&body.grade)
    .bind(&body.skill_file_path)
    .bind(&body.skill_version_hash)
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

    let linked = link_quality_review_to_job_usage(pool, user_id, review.job_id, &review).await;
    if linked > 0 {
        tracing::info!(
            quality_review_id = %review.id,
            linked_usage_rows = linked,
            "linked llm usage rows to quality review"
        );
    }

    // 附加结构化问题类型和下一步动作建议到 diagnostics（需求 14.1, 14.2, 14.5）
    let issue_types = infer_issue_types(&review);
    let next_action = infer_next_action(&review, &issue_types);
    let merged = merge_issue_diagnostics_into_model_params(
        review.model_params.clone(),
        &issue_types,
        &next_action,
    );
    review = sqlx::query_as::<_, QualityReview>(
        r#"UPDATE app_quality_review SET model_params = $2, updated_at = NOW() WHERE id = $1 RETURNING *"#,
    )
    .bind(review.id)
    .bind(merged)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(review))
}

#[cfg(test)]
pub(crate) mod tests {
    use serde_json::json;

    use super::{
        QualityFeedbackMemoryOutcome, merge_feedback_outcome_into_model_params,
        merge_issue_diagnostics_into_model_params,
    };
    use crate::prompting::quality::issue_type::IssueType;
    use crate::prompting::quality::next_action::NextAction;

    /// Test helper: exposes merge_issue_diagnostics_into_model_params for cross-module tests.
    pub fn call_merge_issue_diagnostics(
        model_params: Option<serde_json::Value>,
        issue_types: &[IssueType],
        next_action: &NextAction,
    ) -> serde_json::Value {
        merge_issue_diagnostics_into_model_params(model_params, issue_types, next_action)
    }

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
                focus_tags: vec!["delivery_realism".into(), "emotion_arc".into()],
            },
        );

        assert_eq!(merged["surface"], "quality_reviews_workbench");
        assert_eq!(merged["diagnostics"]["promptChars"], 512);
        assert_eq!(
            merged["diagnostics"]["feedbackMemory"]["action"],
            "promoted_selected_memory"
        );
        assert_eq!(merged["diagnostics"]["feedbackMemory"]["removedChars"], 88);
        assert_eq!(
            merged["diagnostics"]["feedbackMemory"]["focusTags"],
            json!(["delivery_realism", "emotion_arc"])
        );
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
                focus_tags: vec!["identity_continuity".into()],
            },
        );

        assert_eq!(merged["legacyModelParams"], json!(["legacy"]));
        assert_eq!(
            merged["diagnostics"]["feedbackMemory"]["memoryName"],
            "rejected_video_negative_memory"
        );
    }
}
