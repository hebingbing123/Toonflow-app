//! LLM token usage logging (`app_llm_usage_log`).
//!
//! Records per-call prompt/completion/total tokens for cost tracking
//! and correlation with quality scores.

use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::llm::openai::TokenUsage;

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
    quality_review_id: Uuid,
    overall_score: Option<i16>,
) -> u64 {
    let Some(job_id) = job_id else {
        return 0;
    };

    match sqlx::query(
        r#"
        UPDATE app_llm_usage_log
        SET quality_review_id = $1,
            overall_score = COALESCE($2, overall_score)
        WHERE user_id = $3
          AND job_id = $4
          AND quality_review_id IS NULL
        "#,
    )
    .bind(quality_review_id)
    .bind(overall_score)
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
                quality_review_id = %quality_review_id,
                "link quality review to llm usage failed"
            );
            0
        }
    }
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
