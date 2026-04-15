use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::common::{generation_job_is_cancelled, JobRunError};
use crate::jobs::JobRow;
use crate::llm::{
    images_generation_or_edit_url, resolve_openai_image_model, resolve_openai_image_size, LlmConfig,
};
use crate::state::AppState;

use super::common::{generate_and_store_asset_image_for_row, payload_json_i32, AssetImageGenCtx};

pub(super) async fn run_production_assets_batch_generate(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
    cfg: &LlmConfig,
    p: &Value,
) -> Result<serde_json::Value, JobRunError> {
    if generation_job_is_cancelled(pool, job_id).await? {
        return Err(JobRunError::Cancelled);
    }

    let project_numeric_id = payload_json_i32(p, "project_numeric_id")?;
    let script_numeric_id = payload_json_i32(p, "script_id")?;
    let asset_numeric_id = payload_json_i32(p, "asset_id")?;
    let model_in = p
        .get("model")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing model".into()))?;
    let resolution = p
        .get("resolution")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing resolution".into()))?;

    let asset_row = crate::assets::resolve_owned_script_linked_asset_row_for_job(
        pool,
        row.owner_user_id,
        project_numeric_id,
        script_numeric_id,
        asset_numeric_id,
    )
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?
    .ok_or_else(|| JobRunError::Failed("asset not linked to script for owner".into()))?;

    let body_text = asset_row.describe.as_deref().unwrap_or("");
    let image_model = resolve_openai_image_model(model_in);
    let size = resolve_openai_image_size(&image_model, resolution);

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        image_model = %image_model,
        size = %size,
        "production.assets.batch-generate: script-scoped asset image"
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

    let one = generate_and_store_asset_image_for_row(
        &ctx,
        asset_row.id,
        asset_numeric_id,
        &asset_row.name,
        body_text,
        None,
    )
    .await?;

    Ok(json!({
        "source": "production.assets.batch-generate",
        "project_numeric_id": project_numeric_id,
        "script_id": script_numeric_id,
        "image_model": image_model,
        "size": size,
        "items": [one],
    }))
}

pub(super) async fn run_production_storyboard_batch_generate_image(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
    cfg: &LlmConfig,
    p: &Value,
) -> Result<serde_json::Value, JobRunError> {
    if generation_job_is_cancelled(pool, job_id).await? {
        return Err(JobRunError::Cancelled);
    }

    let project_numeric_id = payload_json_i32(p, "project_numeric_id")?;
    let script_numeric_id = payload_json_i32(p, "script_id")?;
    let storyboard_numeric_id = payload_json_i32(p, "storyboard_numeric_id")?;
    let model_in = p
        .get("model")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing model".into()))?;
    let resolution = p
        .get("resolution")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing resolution".into()))?;

    let mut prompt = p
        .get("prompt")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .trim()
        .to_string();
    if prompt.is_empty() {
        return Err(JobRunError::Failed("payload prompt is empty".into()));
    }
    if let Some(neg) = p.get("negative_prompt").and_then(|x| x.as_str()) {
        let n = neg.trim();
        if !n.is_empty() {
            prompt.push_str("\nNegative: ");
            prompt.push_str(n);
        }
    }

    let sb_id: Uuid = sqlx::query_scalar(
        r#"
        SELECT sb.id
        FROM app_storyboard sb
        INNER JOIN app_script s ON s.id = sb.script_id
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND s.numeric_id = $3
          AND sb.numeric_id = $4
        "#,
    )
    .bind(row.owner_user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(storyboard_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?
    .ok_or_else(|| JobRunError::Failed("storyboard not in scope".into()))?;

    let image_model = resolve_openai_image_model(model_in);
    let size = resolve_openai_image_size(&image_model, resolution);
    let (url, revised) = images_generation_or_edit_url(
        cfg,
        &state.http_client,
        image_model.as_str(),
        prompt.as_str(),
        size,
        None,
    )
    .await
    .map_err(JobRunError::Failed)?;

    sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $2, state = '已完成', updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(sb_id)
    .bind(&url)
    .execute(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;

    Ok(json!({
        "source": "production.storyboard.batch-generate-image",
        "project_numeric_id": project_numeric_id,
        "storyboard_numeric_id": storyboard_numeric_id,
        "image_model": image_model,
        "size": size,
        "image_url": url,
        "revised_prompt": revised,
    }))
}

pub(super) async fn run_production_edit_image_generate_flow(
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
