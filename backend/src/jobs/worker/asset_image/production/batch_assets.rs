use serde_json::{json, Value, Value as JsonValue};
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::payload_project::{
    payload_project_uuid, resolve_project_numeric_from_job_payload,
};
use crate::jobs::worker::common::{generation_job_is_cancelled, JobRunError};
use crate::jobs::JobRow;
use crate::llm::{resolve_openai_image_model, resolve_openai_image_size, LlmConfig};
use crate::projects::model_routing::jobs::resolve_job_image_model_id;
use crate::projects::model_routing::StudioStepSlug;
use crate::state::AppState;

use super::super::common::{
    generate_and_store_asset_image_for_row, payload_json_i32, AssetImageGenCtx,
};

pub(crate) async fn run_production_assets_batch_generate(
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

    let project_numeric_id =
        resolve_project_numeric_from_job_payload(pool, row.owner_user_id, p).await?;
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
    .ok_or_else(|| JobRunError::Failed("asset not linked to script or not accessible".into()))?;

    let body_text = asset_row.describe.as_deref().unwrap_or("");
    let routed_model = resolve_job_image_model_id(
        state,
        pool,
        row.owner_user_id,
        project_numeric_id,
        StudioStepSlug::Assets,
        model_in,
    )
    .await?;
    let image_model = resolve_openai_image_model(routed_model.as_str());
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

    let one: JsonValue = generate_and_store_asset_image_for_row(
        &ctx,
        asset_row.id,
        asset_numeric_id,
        &asset_row.name,
        body_text,
        None,
    )
    .await?;

    let mut result = json!({
        "source": "production.assets.batch-generate",
        "project_numeric_id": project_numeric_id,
        "script_id": script_numeric_id,
        "image_model": image_model,
        "size": size,
        "items": [one],
    });
    if let Some(project_uuid) = payload_project_uuid(p) {
        result["project_uuid"] = json!(project_uuid);
    }
    Ok(result)
}
