use axum::{extract::State, http::HeaderMap, Json};
use serde_json::{json, Map, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::metering::llm_usage::link_quality_review_to_job_usage;
use crate::state::AppState;

use super::super::feedback::{
    maybe_write_quality_feedback_to_memory, QualityFeedbackMemoryOutcome,
};
use super::super::issue_type::infer_issue_types;
use super::super::next_action::{infer_next_action, infer_suggested_action_from_bad_case_category};
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
    job_id: Option<Uuid>,
    target_type: &str,
    target_id: Option<&str>,
) -> Result<(), ApiError> {
    if let Some(job_id) = job_id {
        let ok: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
              SELECT 1
              FROM app_generation_job j
              WHERE j.id = $1
                AND (
                  j.owner_user_id = $2
                  OR (
                    (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
                    AND EXISTS (
                      SELECT 1
                      FROM app_project p
                      WHERE p.numeric_id = (j.payload->>'project_numeric_id')::int
                        AND EXISTS (
                          SELECT 1
                          FROM app_workspace_member wm
                          WHERE wm.workspace_id = p.workspace_id
                            AND wm.user_id = $2
                        )
                    )
                  )
                )
            )
            "#,
        )
        .bind(job_id)
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if !ok {
            return Err(ApiError::NotFound);
        }
    }

    match (project_id, script_id) {
        (Some(project_id), Some(script_id)) => {
            let ok: bool = sqlx::query_scalar(
                r#"
                SELECT EXISTS(
                  SELECT 1
                  FROM app_script sc
                  INNER JOIN app_project p ON p.id = sc.project_id
                  WHERE p.numeric_id = $2
                    AND sc.numeric_id = $3
                    AND EXISTS (
                      SELECT 1
                      FROM app_workspace_member wm
                      WHERE wm.workspace_id = p.workspace_id
                        AND wm.user_id = $1
                    )
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
                  FROM app_project p
                  WHERE p.numeric_id = $2
                    AND EXISTS (
                      SELECT 1
                      FROM app_workspace_member wm
                      WHERE wm.workspace_id = p.workspace_id
                        AND wm.user_id = $1
                    )
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
                  WHERE sc.numeric_id = $2
                    AND EXISTS (
                      SELECT 1
                      FROM app_workspace_member wm
                      WHERE wm.workspace_id = p.workspace_id
                        AND wm.user_id = $1
                    )
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

    if matches!(target_type, "storyboard" | "video" | "output") {
        let Some(storyboard_id) = target_id
            .map(str::trim)
            .and_then(|value| value.parse::<i32>().ok())
            .filter(|value| *value > 0)
        else {
            return Ok(());
        };
        if let Some(project_id) = project_id {
            let ok: bool = if let Some(script_id) = script_id {
                sqlx::query_scalar(
                    r#"
                    SELECT EXISTS(
                      SELECT 1
                      FROM app_storyboard sb
                      INNER JOIN app_script sc ON sc.id = sb.script_id
                      INNER JOIN app_project p ON p.id = sc.project_id
                      WHERE p.numeric_id = $2
                        AND sc.numeric_id = $3
                        AND sb.numeric_id = $4
                        AND EXISTS (
                          SELECT 1
                          FROM app_workspace_member wm
                          WHERE wm.workspace_id = p.workspace_id
                            AND wm.user_id = $1
                        )
                    )
                    "#,
                )
                .bind(user_id)
                .bind(project_id)
                .bind(script_id)
                .bind(storyboard_id)
                .fetch_one(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            } else {
                sqlx::query_scalar(
                    r#"
                    SELECT EXISTS(
                      SELECT 1
                      FROM app_storyboard sb
                      INNER JOIN app_script sc ON sc.id = sb.script_id
                      INNER JOIN app_project p ON p.id = sc.project_id
                      WHERE p.numeric_id = $2
                        AND sb.numeric_id = $3
                        AND EXISTS (
                          SELECT 1
                          FROM app_workspace_member wm
                          WHERE wm.workspace_id = p.workspace_id
                            AND wm.user_id = $1
                        )
                    )
                    "#,
                )
                .bind(user_id)
                .bind(project_id)
                .bind(storyboard_id)
                .fetch_one(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            };
            if !ok {
                return Err(ApiError::NotFound);
            }
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
        body.job_id,
        &body.target_type,
        body.target_id.as_deref(),
    )
    .await?;

    let source = body.source.as_deref().unwrap_or("manual");
    let is_bad_case = body.is_bad_case.unwrap_or(false);

    // Infer next_action if not provided
    let next_action_str = body.next_action.as_deref();

    let suggested_action =
        infer_suggested_action_from_bad_case_category(body.bad_case_category.as_deref());

    let mut review = sqlx::query_as::<_, QualityReview>(
        r#"
        INSERT INTO app_quality_review (
            user_id, project_id, script_id, job_id, target_type, target_id,
            source, plot_coherence, character_consistency, dialogue_naturalness,
            pacing, faithfulness, visual_quality, overall_score, passed,
            comments, skill_version, model_name, model_params, memory_delivery_priority_applied,
            dimension_scores, is_bad_case, bad_case_category,
            stage, grade, skill_file_path, skill_version_hash, next_action, suggested_action
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29)
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
    .bind(&body.dimension_scores)
    .bind(is_bad_case)
    .bind(&body.bad_case_category)
    .bind(&body.stage)
    .bind(&body.grade)
    .bind(&body.skill_file_path)
    .bind(&body.skill_version_hash)
    .bind(next_action_str)
    .bind(suggested_action)
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
    // Also update the next_action field if it wasn't provided (需求 I.4)
    let issue_types = infer_issue_types(&review);
    let next_action = infer_next_action(&review, &issue_types);
    let merged = merge_issue_diagnostics_into_model_params(
        review.model_params.clone(),
        &issue_types,
        &next_action,
    );

    // Update both model_params and next_action field
    let next_action_to_store = if review.next_action.is_none() {
        Some(next_action.as_str())
    } else {
        review.next_action.as_deref()
    };

    review = sqlx::query_as::<_, QualityReview>(
        r#"UPDATE app_quality_review SET model_params = $2, next_action = $3, updated_at = NOW() WHERE id = $1 RETURNING *"#,
    )
    .bind(review.id)
    .bind(merged)
    .bind(next_action_to_store)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(review))
}

#[cfg(test)]
pub(crate) mod tests {
    use serde_json::json;

    use super::{
        merge_feedback_outcome_into_model_params, merge_issue_diagnostics_into_model_params,
        QualityFeedbackMemoryOutcome,
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
