//! LLM 优化任务（`asset.polish.*`）。

use serde_json::json;

use crate::llm::{chat_completion_assistant_text, LlmConfig};
use crate::state::AppState;

use crate::jobs::JobRow;

use super::common::{generation_job_is_cancelled, JobRunError};

/// Cap polished text stored on the job row (aligned with HTTP **`prompt`** max on enqueue).
const MAX_POLISHED_PROMPT_CHARS: usize = 48_000;

async fn polish_asset_description_llm(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    asset_type: &str,
    name: &str,
    describe: &str,
) -> Result<String, JobRunError> {
    let user_msg = format!(
        "Polish the following asset description into a single concise image-generation prompt (keep the user's language).\n\nType: {asset_type}\nName: {name}\nDescription:\n{describe}\n\nReply with only the polished prompt text, no quotes or preamble."
    );

    let messages = vec![
        json!({"role": "system", "content": "You help users refine prompts for creative asset generation."}),
        json!({"role": "user", "content": user_msg}),
    ];

    let mut text = chat_completion_assistant_text(cfg, client, messages)
        .await
        .map_err(JobRunError::Failed)?;

    if text.len() > MAX_POLISHED_PROMPT_CHARS {
        text.truncate(MAX_POLISHED_PROMPT_CHARS);
    }

    Ok(text)
}

pub(super) async fn run_asset_polish_prompt(
    state: &AppState,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let Some(ref cfg) = state.llm else {
        return Err(JobRunError::Failed(
            "LLM not configured (set OPENAI_API_KEY or LLM_API_KEY)".into(),
        ));
    };

    let p = &row.payload;
    let project_legacy_id = p
        .get("project_numeric_id")
        .and_then(|x| x.as_i64())
        .ok_or_else(|| JobRunError::Failed("payload missing project_numeric_id".into()))?;
    let asset_legacy_id = p
        .get("asset_numeric_id")
        .and_then(|x| x.as_i64())
        .ok_or_else(|| JobRunError::Failed("payload missing asset_numeric_id".into()))?;
    let asset_type = p
        .get("asset_type")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing asset_type".into()))?;
    let name = p
        .get("name")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing name".into()))?;
    let describe = p
        .get("describe")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing describe".into()))?;

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        "asset polish-prompt: calling LLM"
    );

    let text =
        polish_asset_description_llm(cfg, &state.http_client, asset_type, name, describe).await?;

    Ok(json!({
        "source": "assets-generate.polish-prompt",
        "project_numeric_id": project_legacy_id,
        "asset_numeric_id": asset_legacy_id,
        "polished_prompt": text,
    }))
}

pub(super) async fn run_asset_polish_batch(
    state: &AppState,
    pool: &sqlx::PgPool,
    job_id: uuid::Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let Some(ref cfg) = state.llm else {
        return Err(JobRunError::Failed(
            "LLM not configured (set OPENAI_API_KEY or LLM_API_KEY)".into(),
        ));
    };

    let p = &row.payload;
    let project_legacy_id = p
        .get("project_numeric_id")
        .and_then(|x| x.as_i64())
        .ok_or_else(|| JobRunError::Failed("payload missing project_numeric_id".into()))?;
    let items = p
        .get("items")
        .and_then(|x| x.as_array())
        .ok_or_else(|| JobRunError::Failed("payload missing items".into()))?;
    if items.is_empty() {
        return Err(JobRunError::Failed(
            "payload items is empty (invalid enqueue)".into(),
        ));
    }

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        item_count = items.len(),
        "asset batch-polish: calling LLM per item"
    );

    let mut out = Vec::with_capacity(items.len());
    for item in items {
        if generation_job_is_cancelled(pool, job_id).await? {
            return Err(JobRunError::Cancelled);
        }

        let asset_legacy_id = item
            .get("asset_numeric_id")
            .and_then(|x| x.as_i64())
            .ok_or_else(|| JobRunError::Failed("item missing asset_numeric_id".into()))?;
        let asset_type = item
            .get("asset_type")
            .and_then(|x| x.as_str())
            .ok_or_else(|| JobRunError::Failed("item missing asset_type".into()))?;
        let name = item
            .get("name")
            .and_then(|x| x.as_str())
            .ok_or_else(|| JobRunError::Failed("item missing name".into()))?;
        let describe = item
            .get("describe")
            .and_then(|x| x.as_str())
            .ok_or_else(|| JobRunError::Failed("item missing describe".into()))?;

        let text =
            polish_asset_description_llm(cfg, &state.http_client, asset_type, name, describe)
                .await?;

        out.push(json!({
            "asset_numeric_id": asset_legacy_id,
            "polished_prompt": text,
        }));
    }

    Ok(json!({
        "source": "assets-generate.batch-polish",
        "project_numeric_id": project_legacy_id,
        "items": out,
    }))
}
