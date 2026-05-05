//! LLM token usage logging (`app_llm_usage_log`).
//!
//! Records per-call prompt/completion/total tokens for cost tracking
//! and correlation with quality scores.

use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::llm::openai::TokenUsage;
use crate::prompting::quality::QualityReview;

/// Best-effort insert into `app_llm_usage_log`. Errors are logged only.
#[allow(clippy::too_many_arguments)]
pub async fn record_llm_usage(
    pool: &PgPool,
    user_id: Uuid,
    project_id: Option<i32>,
    script_id: Option<i32>,
    job_id: Option<Uuid>,
    call_type: &str,
    model_name: &str,
    provider: Option<&str>,
    usage: Option<&TokenUsage>,
    prompt_chars: Option<i64>,
    success: bool,
    error_message: Option<&str>,
    duration_ms: Option<i64>,
    meta: serde_json::Value,
) {
    let usage = usage.cloned().unwrap_or_default();

    if let Err(e) = sqlx::query(
        r#"
        INSERT INTO app_llm_usage_log (
          user_id, project_id, script_id, job_id,
          call_type, model_name, provider,
          prompt_tokens, completion_tokens, total_tokens,
          prompt_chars,
          success, error_message, duration_ms,
          meta
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(job_id)
    .bind(call_type)
    .bind(model_name)
    .bind(provider)
    .bind(usage.prompt_tokens)
    .bind(usage.completion_tokens)
    .bind(usage.total_tokens)
    .bind(prompt_chars)
    .bind(success)
    .bind(error_message)
    .bind(duration_ms)
    .bind(meta)
    .execute(pool)
    .await
    {
        tracing::warn!(error = %e, "app_llm_usage_log insert failed");
    }
}

/// Attach a completed quality review to usage rows from the same generation job.
///
/// We intentionally avoid fuzzy project/script time matching here because this is a
/// multi-user platform and memory must stay isolated. Job-bound linkage is explicit
/// and keeps later token-vs-quality analysis trustworthy.
pub async fn link_quality_review_to_job_usage(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Option<Uuid>,
    review: &QualityReview,
) -> u64 {
    let Some(job_id) = job_id else {
        return 0;
    };
    let quality_meta = build_quality_review_usage_meta(review);

    match sqlx::query(
        r#"
        UPDATE app_llm_usage_log
        SET quality_review_id = $1,
            overall_score = COALESCE($2, overall_score),
            meta = jsonb_set(
              COALESCE(meta, '{}'::jsonb),
              '{qualityReview}',
              $3::jsonb,
              true
            )
        WHERE user_id = $4
          AND job_id = $5
          AND quality_review_id IS NULL
        "#,
    )
    .bind(review.id)
    .bind(review.overall_score)
    .bind(quality_meta)
    .bind(user_id)
    .bind(job_id)
    .execute(pool)
    .await
    {
        Ok(result) => result.rows_affected(),
        Err(e) => {
            tracing::warn!(
                error = %e,
                user_id = %user_id,
                job_id = %job_id,
                quality_review_id = %review.id,
                "link quality review to llm usage failed"
            );
            0
        }
    }
}

fn build_quality_review_usage_meta(review: &QualityReview) -> serde_json::Value {
    let diagnostics = review
        .model_params
        .as_ref()
        .and_then(|value: &serde_json::Value| value.get("diagnostics"));

    json!({
        "id": review.id,
        "source": review.source,
        "targetType": review.target_type,
        "targetId": review.target_id,
        "stage": review.stage,
        "grade": review.grade,
        "overallScore": review.overall_score,
        "passed": review.passed,
        "isBadCase": review.is_bad_case,
        "badCaseCategory": review.bad_case_category,
        "memoryDeliveryPriorityApplied": review.memory_delivery_priority_applied,
        "memoryBudgetTier": diagnostics.and_then(|value: &serde_json::Value| value.get("memoryBudgetTier")),
        "negativeBudgetTier": diagnostics.and_then(|value: &serde_json::Value| value.get("negativeBudgetTier")),
        "autoNegativeSource": diagnostics.and_then(|value: &serde_json::Value| value.get("autoNegativeSource")),
        "observationNoteChars": diagnostics.and_then(|value: &serde_json::Value| value.get("observationNoteChars")),
        "memoryBudgetRiskScore": diagnostics.and_then(|value: &serde_json::Value| value.get("memoryBudgetRiskScore")),
        "memoryBudgetReasons": diagnostics.and_then(|value: &serde_json::Value| value.get("memoryBudgetReasons")),
        "memoryOptimizationRemovedChars": diagnostics.and_then(|value: &serde_json::Value| value.get("memoryOptimizationRemovedChars")),
        "feedbackMemoryAction": diagnostics
            .and_then(|value: &serde_json::Value| value.get("feedbackMemory"))
            .and_then(|value: &serde_json::Value| value.get("action")),
        "contextCharsInjected": diagnostics.and_then(|value: &serde_json::Value| value.get("contextCharsInjected")),
        "reworkMode": diagnostics.and_then(|value: &serde_json::Value| value.get("reworkMode")),
    })
}

/// Lightweight helper: record usage from a successful call with minimal params.
pub async fn record_llm_usage_simple(
    pool: &PgPool,
    user_id: Uuid,
    call_type: &str,
    model_name: &str,
    usage: Option<&TokenUsage>,
) {
    record_llm_usage(
        pool,
        user_id,
        None,
        None,
        None,
        call_type,
        model_name,
        None,
        usage,
        None,
        true,
        None,
        None,
        json!({}),
    )
    .await;
}

#[cfg(test)]
mod tests {
    use serde_json::json;
    use uuid::Uuid;

    use super::build_quality_review_usage_meta;
    use crate::prompting::quality::QualityReview;

    #[test]
    fn build_quality_review_usage_meta_captures_roi_fields() {
        let review = QualityReview {
            id: Uuid::nil(),
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            user_id: Uuid::nil(),
            project_id: Some(12),
            script_id: Some(34),
            job_id: None,
            target_type: "storyboard".into(),
            target_id: Some("56".into()),
            source: "auto".into(),
            plot_coherence: None,
            character_consistency: None,
            dialogue_naturalness: Some(72),
            pacing: None,
            faithfulness: None,
            visual_quality: Some(68),
            overall_score: Some(71),
            passed: Some(false),
            comments: Some("表演生硬，穿帮".into()),
            skill_version: None,
            model_name: Some("runway-gen-2".into()),
            model_params: Some(json!({
                "diagnostics": {
                    "memoryBudgetTier": "expanded",
                    "negativeBudgetTier": "lean",
                    "autoNegativeSource": "patch_attribution",
                    "observationNoteChars": 24,
                    "memoryBudgetRiskScore": 3,
                    "memoryBudgetReasons": ["missing_reference_frame", "emotional_risk"],
                    "memoryOptimizationRemovedChars": 18,
                    "feedbackMemory": {
                        "action": "persisted_rejected_memory"
                    }
                }
            })),
            memory_delivery_priority_applied: Some(true),
            reviewer_id: None,
            is_bad_case: true,
            bad_case_category: Some("dialogue_issue".into()),
            stage: Some("video_prompt".into()),
            grade: Some("C".into()),
            skill_file_path: None,
            skill_version_hash: None,
            next_action: None,
        };

        let meta = build_quality_review_usage_meta(&review);

        assert_eq!(meta["source"], "auto");
        assert_eq!(meta["stage"], "video_prompt");
        assert_eq!(meta["memoryBudgetTier"], "expanded");
        assert_eq!(meta["autoNegativeSource"], "patch_attribution");
        assert_eq!(meta["feedbackMemoryAction"], "persisted_rejected_memory");
        assert_eq!(meta["memoryOptimizationRemovedChars"], 18);
    }
}
