use crate::jobs::worker::common::{generation_job_is_cancelled, JobRunError};
use crate::llm::{
    images_generation_or_edit_url, resolve_openai_image_model, resolve_openai_image_size, LlmConfig,
};
use crate::state::AppState;
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

pub(crate) async fn run_production_edit_image_generate_flow(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    cfg: &LlmConfig,
    p: &Value,
) -> Result<serde_json::Value, JobRunError> {
    if generation_job_is_cancelled(pool, job_id).await? {
        return Err(JobRunError::Cancelled);
    }

    let flow_id = p
        .get("flow_id")
        .and_then(|x| x.as_str())
        .filter(|s| !s.trim().is_empty())
        .ok_or_else(|| JobRunError::Failed("payload missing flow_id".into()))?;
    let prompt = p
        .get("prompt")
        .and_then(|x| x.as_str())
        .filter(|s| !s.trim().is_empty())
        .ok_or_else(|| JobRunError::Failed("payload missing prompt".into()))?;
    let model_in = p
        .get("model")
        .and_then(|x| x.as_str())
        .filter(|s| !s.is_empty())
        .unwrap_or("dall-e-3");
    let resolution = "1024x1024";
    let image_model = resolve_openai_image_model(model_in);
    let size = resolve_openai_image_size(&image_model, resolution);
    let (url, revised) = images_generation_or_edit_url(
        cfg,
        &state.http_client,
        image_model.as_str(),
        prompt,
        size,
        None,
    )
    .await
    .map_err(JobRunError::Failed)?;

    Ok(json!({
        "source": "production.edit-image.generate-flow",
        "flow_id": flow_id,
        "image_model": image_model,
        "size": size,
        "image_url": url,
        "revised_prompt": revised,
    }))
}
