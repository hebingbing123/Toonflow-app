use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::common::{generation_job_is_cancelled, JobRunError};
use crate::jobs::JobRow;
use crate::llm::{resolve_openai_image_model, resolve_openai_image_size};
use crate::state::AppState;

use super::common::{generate_and_store_asset_image, AssetImageGenCtx};

pub(crate) async fn run_asset_generate_image(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let Some(ref cfg) = state.llm else {
        return Err(JobRunError::Failed(
            "LLM not configured (set OPENAI_API_KEY or LLM_API_KEY)".into(),
        ));
    };

    if generation_job_is_cancelled(pool, job_id).await? {
        return Err(JobRunError::Cancelled);
    }

    let p = &row.payload;
    let project_numeric_id = p
        .get("project_numeric_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed("payload missing project_numeric_id".into()))?;
    let asset_numeric_id = p
        .get("asset_numeric_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed("payload missing asset_numeric_id".into()))?;
    let model_in = p
        .get("model")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing model".into()))?;
    let resolution = p
        .get("resolution")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing resolution".into()))?;
    let name = p.get("name").and_then(|x| x.as_str()).unwrap_or("");
    let prompt = p
        .get("prompt")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing prompt".into()))?;
    let prompt = prompt.trim();
    if prompt.is_empty() {
        return Err(JobRunError::Failed("payload prompt cannot be empty".into()));
    }
    let image_base64 = p
        .get("image_base64")
        .and_then(|x| x.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let image_model = resolve_openai_image_model(model_in);
    let size = resolve_openai_image_size(&image_model, resolution);

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        image_model = %image_model,
        size = %size,
        "asset generate image: calling images API"
    );

    let ctx = AssetImageGenCtx {
        cfg,
        http_client: &state.http_client,
        pool,
        job_id,
        owner: row.owner_user_id,
        request_model: model_in,
        image_model: image_model.as_str(),
        size,
        local_asset_image_dir: state.local_asset_image_dir.as_deref(),
    };

    let body = generate_and_store_asset_image(
        &ctx,
        project_numeric_id,
        asset_numeric_id,
        name,
        prompt,
        image_base64,
    )
    .await?;

    Ok(json!({
        "source": "assets-generate.generate",
        "project_numeric_id": project_numeric_id,
        "image_model": image_model,
        "size": size,
        "asset_numeric_id": asset_numeric_id,
        "asset_image_id": body["asset_image_id"],
        "image_url": body["image_url"],
        "revised_prompt": body["revised_prompt"],
        "has_reference_image": body["has_reference_image"],
    }))
}
