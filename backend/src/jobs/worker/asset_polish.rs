//! LLM 优化任务（`asset.polish.*`）。

use serde_json::json;
use sqlx::PgPool;

use crate::llm::{chat_completion_with_usage, LlmConfig, TokenUsage};
use crate::metering::llm_usage::record_llm_usage;
use crate::state::AppState;

use crate::jobs::payload_project::{
    payload_project_uuid, resolve_project_numeric_from_job_payload,
};
use crate::jobs::JobRow;

use super::common::{generation_job_is_cancelled, JobRunError};

/// Cap polished text stored on the job row (aligned with HTTP **`prompt`** max on enqueue).
const MAX_POLISHED_PROMPT_CHARS: usize = 48_000;

struct PolishedPromptLlmResult {
    text: String,
    usage: Option<TokenUsage>,
    model_name: String,
    prompt_chars: i64,
    duration_ms: i64,
}

async fn polish_asset_description_llm(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    asset_type: &str,
    name: &str,
    describe: &str,
) -> Result<PolishedPromptLlmResult, JobRunError> {
    let user_msg = format!(
        "Polish the following asset description into a single concise image-generation prompt (keep the user's language).\n\nType: {asset_type}\nName: {name}\nDescription:\n{describe}\n\nReply with only the polished prompt text, no quotes or preamble."
    );

    let messages = vec![
        json!({"role": "system", "content": "You help users refine prompts for creative asset generation."}),
        json!({"role": "user", "content": user_msg}),
    ];
    let prompt_chars = serde_json::to_string(&messages)
        .map(|raw| raw.chars().count() as i64)
        .unwrap_or(0);
    let started_at = std::time::Instant::now();

    let response = chat_completion_with_usage(cfg, client, messages)
        .await
        .map_err(JobRunError::Failed)?;
    let mut text = response.content;

    if text.len() > MAX_POLISHED_PROMPT_CHARS {
        text.truncate(MAX_POLISHED_PROMPT_CHARS);
    }

    Ok(PolishedPromptLlmResult {
        text,
        usage: response.usage,
        model_name: response.model.unwrap_or_else(|| cfg.model.clone()),
        prompt_chars,
        duration_ms: started_at.elapsed().as_millis() as i64,
    })
}

pub(super) async fn run_asset_polish_prompt(
    state: &AppState,
    pool: &PgPool,
    job_id: uuid::Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let Some(ref cfg) = state.llm else {
        return Err(JobRunError::Failed(
            "LLM not configured (set OPENAI_API_KEY or LLM_API_KEY)".into(),
        ));
    };

    let p = &row.payload;
    let project_numeric_id =
        resolve_project_numeric_from_job_payload(pool, row.owner_user_id, p).await?;
    let asset_numeric_id = p
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

    let effective_cfg = effective_polish_llm_config(
        state,
        pool,
        cfg,
        row.owner_user_id,
        project_numeric_id,
        &row.payload,
        None,
    )
    .await?;

    let result = polish_asset_description_llm(
        &effective_cfg,
        &state.http_client,
        asset_type,
        name,
        describe,
    )
    .await?;
    record_llm_usage(
        pool,
        row.owner_user_id,
        Some(project_numeric_id),
        None,
        Some(job_id),
        "jobs.asset_polish_prompt",
        &result.model_name,
        Some("openai"),
        result.usage.as_ref(),
        Some(result.prompt_chars),
        true,
        None,
        Some(result.duration_ms),
        json!({
            "assetNumericId": asset_numeric_id,
            "assetType": asset_type,
            "jobKind": row.kind,
        }),
    )
    .await;

    let mut result = json!({
        "source": "assets-generate.polish-prompt",
        "project_numeric_id": project_numeric_id as i64,
        "asset_numeric_id": asset_numeric_id,
        "polished_prompt": result.text,
    });
    if let Some(project_uuid) = payload_project_uuid(p) {
        result["project_uuid"] = json!(project_uuid);
    }
    Ok(result)
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
    let project_numeric_id =
        resolve_project_numeric_from_job_payload(pool, row.owner_user_id, p).await?;
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

    let effective_cfg = effective_polish_llm_config(
        state,
        pool,
        cfg,
        row.owner_user_id,
        project_numeric_id,
        &row.payload,
        None,
    )
    .await?;

    let mut out = Vec::with_capacity(items.len());
    for item in items {
        if generation_job_is_cancelled(pool, job_id).await? {
            return Err(JobRunError::Cancelled);
        }

        let asset_numeric_id = item
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

        let result = polish_asset_description_llm(
            &effective_cfg,
            &state.http_client,
            asset_type,
            name,
            describe,
        )
        .await?;
        record_llm_usage(
            pool,
            row.owner_user_id,
            Some(project_numeric_id),
            None,
            Some(job_id),
            "jobs.asset_polish_batch_item",
            &result.model_name,
            Some("openai"),
            result.usage.as_ref(),
            Some(result.prompt_chars),
            true,
            None,
            Some(result.duration_ms),
            json!({
                "assetNumericId": asset_numeric_id,
                "assetType": asset_type,
                "jobKind": row.kind,
            }),
        )
        .await;

        out.push(json!({
            "asset_numeric_id": asset_numeric_id,
            "polished_prompt": result.text,
        }));
    }

    let mut result = json!({
        "source": "assets-generate.batch-polish",
        "project_numeric_id": project_numeric_id as i64,
        "items": out,
    });
    if let Some(project_uuid) = payload_project_uuid(p) {
        result["project_uuid"] = json!(project_uuid);
    }
    Ok(result)
}

async fn effective_polish_llm_config(
    state: &AppState,
    pool: &PgPool,
    fallback: &LlmConfig,
    owner_user_id: uuid::Uuid,
    project_numeric_id: i32,
    payload: &serde_json::Value,
    model_override: Option<&str>,
) -> Result<LlmConfig, JobRunError> {
    use crate::projects::model_routing::jobs::{
        load_project_uuid_for_actor, try_build_routed_llm_config,
    };
    use crate::projects::model_routing::{ModelSlot, StudioStepSlug};

    if let Some(project_uuid) = payload_project_uuid(payload).or(load_project_uuid_for_actor(
        pool,
        owner_user_id,
        project_numeric_id,
    )
    .await?)
    {
        if let Some(cfg) = try_build_routed_llm_config(
            state,
            pool,
            owner_user_id,
            project_uuid,
            StudioStepSlug::Assets,
            ModelSlot::Text,
            model_override,
        )
        .await?
        {
            return Ok(cfg);
        }
    }

    let mut effective_cfg = fallback.clone();
    if let Some(project_model) =
        load_project_text_model(pool, owner_user_id, project_numeric_id).await?
    {
        effective_cfg.model = project_model;
    }
    Ok(effective_cfg)
}

async fn load_project_text_model(
    pool: &PgPool,
    actor_user_id: uuid::Uuid,
    project_numeric_id: i32,
) -> Result<Option<String>, JobRunError> {
    let row = sqlx::query_scalar::<_, Option<String>>(
        r#"
        SELECT text_model
        FROM app_project
        WHERE numeric_id = $2
          AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = app_project.workspace_id
                  AND wm.user_id = $1
          )
        "#,
    )
    .bind(actor_user_id)
    .bind(project_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;

    Ok(row
        .flatten()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty()))
}
