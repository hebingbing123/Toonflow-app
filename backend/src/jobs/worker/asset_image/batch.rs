use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::common::{generation_job_is_cancelled, JobRunError};
use crate::jobs::JobRow;
use crate::llm::{resolve_openai_image_model, resolve_openai_image_size};
use crate::state::AppState;

use super::common::{
    ensure_script_scoped_asset_exists, generate_and_store_asset_image, AssetImageGenCtx,
};
use super::production::{
    run_production_assets_batch_generate, run_production_edit_image_generate_flow,
    run_production_storyboard_batch_generate_image,
};

async fn run_asset_generate_batch_items(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
    cfg: &crate::llm::LlmConfig,
    p: &Value,
    items: &[Value],
) -> Result<serde_json::Value, JobRunError> {
    let project_numeric_id = p
        .get("project_numeric_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed("payload missing project_numeric_id".into()))?;
    let model_in = p
        .get("model")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing model".into()))?;
    let resolution = p
        .get("resolution")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing resolution".into()))?;

    let optional_script_numeric_id = p
        .get("script_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .filter(|&n| n > 0);

    let image_model = resolve_openai_image_model(model_in);
    let size = resolve_openai_image_size(&image_model, resolution);

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        item_count = items.len(),
        image_model = %image_model,
        size = %size,
        script_id = ?optional_script_numeric_id,
        "asset batch-generate: images API per item"
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

    let mut out = Vec::with_capacity(items.len());
    for item in items {
        if generation_job_is_cancelled(pool, job_id).await? {
            return Err(JobRunError::Cancelled);
        }

        let asset_numeric_id = item
            .get("asset_numeric_id")
            .and_then(|x| x.as_i64())
            .and_then(|n| i32::try_from(n).ok())
            .ok_or_else(|| JobRunError::Failed("item missing asset_numeric_id".into()))?;

        if let Some(sid) = optional_script_numeric_id {
            ensure_script_scoped_asset_exists(
                pool,
                row.owner_user_id,
                project_numeric_id,
                sid,
                asset_numeric_id,
            )
            .await?;
        }

        let name = item.get("name").and_then(|x| x.as_str()).unwrap_or("");
        let prompt = item
            .get("prompt")
            .and_then(|x| x.as_str())
            .ok_or_else(|| JobRunError::Failed("item missing prompt".into()))?;
        let image_base64 = item.get("image_base64").and_then(|x| x.as_str());

        let one = generate_and_store_asset_image(
            &ctx,
            project_numeric_id,
            asset_numeric_id,
            name,
            prompt,
            image_base64,
        )
        .await?;
        out.push(one);
    }

    Ok(json!({
        "source": "assets-generate.batch-generate",
        "project_numeric_id": project_numeric_id,
        "image_model": image_model,
        "size": size,
        "items": out,
    }))
}

pub(crate) async fn run_asset_generate_batch(
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

    let p = &row.payload;
    if let Some(items) = p.get("items").and_then(|x| x.as_array()) {
        if !items.is_empty() {
            return run_asset_generate_batch_items(state, pool, job_id, row, cfg, p, items).await;
        }
    }

    let source = p.get("source").and_then(|s| s.as_str()).unwrap_or("");
    match source {
        "production.assets.batch-generate" => {
            run_production_assets_batch_generate(state, pool, job_id, row, cfg, p).await
        }
        "production.storyboard.batch-generate-image" => {
            run_production_storyboard_batch_generate_image(state, pool, job_id, row, cfg, p).await
        }
        "production.edit-image.generate-flow" => {
            run_production_edit_image_generate_flow(state, pool, job_id, cfg, p).await
        }
        other => Err(JobRunError::Failed(format!(
            "asset.generate.batch: unsupported payload (source={other:?})"
        ))),
    }
}
