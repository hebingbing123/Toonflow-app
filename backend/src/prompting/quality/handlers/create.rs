use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::feedback::maybe_write_quality_feedback_to_memory;
use super::super::types::{CreateQualityReviewBody, QualityReview};
use super::super::validate::validate_create_review_body;

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

    let review = sqlx::query_as::<_, QualityReview>(
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

    // Async feedback to memory (best-effort, don't block response)
    if let (Some(project_id), Some(script_id)) = (body.project_id, body.script_id) {
        let review_clone = review.clone();
        tokio::spawn(async move {
            let _ = maybe_write_quality_feedback_to_memory(
                pool,
                user_id,
                project_id,
                script_id,
                &review_clone,
            )
            .await;
        });
    }

    Ok(Json(review))
}
