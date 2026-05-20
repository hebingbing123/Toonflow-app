use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::payload_project::{
    payload_project_uuid, resolve_project_numeric_from_job_payload,
};
use crate::jobs::worker::common::{generation_job_is_cancelled, JobRunError};
use crate::jobs::JobRow;
use crate::llm::{
    images_generation_or_edit_url, resolve_openai_image_model, resolve_openai_image_size, LlmConfig,
};
use crate::projects::model_routing::jobs::{
    resolve_asset_image_llm_config, resolve_job_image_model_id,
};
use crate::projects::model_routing::StudioStepSlug;
use crate::state::AppState;

use super::super::common::payload_json_i32;

pub(crate) async fn run_production_storyboard_batch_generate_image(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
    _fallback_cfg: &LlmConfig,
    p: &Value,
) -> Result<serde_json::Value, JobRunError> {
    if generation_job_is_cancelled(pool, job_id).await? {
        return Err(JobRunError::Cancelled);
    }

    let project_numeric_id =
        resolve_project_numeric_from_job_payload(pool, row.owner_user_id, p).await?;
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
        WHERE EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $1
          )
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

    let routed_model = resolve_job_image_model_id(
        state,
        pool,
        row.owner_user_id,
        project_numeric_id,
        StudioStepSlug::Storyboard,
        model_in,
    )
    .await?;
    let cfg = resolve_asset_image_llm_config(
        state,
        pool,
        row.owner_user_id,
        project_numeric_id,
        StudioStepSlug::Storyboard,
        routed_model.as_str(),
    )
    .await?;
    let image_model = resolve_openai_image_model(routed_model.as_str());
    let size = resolve_openai_image_size(&image_model, resolution);
    let (url, revised) = images_generation_or_edit_url(
        &cfg,
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

    let mut result = json!({
        "source": "production.storyboard.batch-generate-image",
        "project_numeric_id": project_numeric_id,
        "storyboard_numeric_id": storyboard_numeric_id,
        "image_model": image_model,
        "size": size,
        "image_url": url,
        "revised_prompt": revised,
    });
    if let Some(project_uuid) = payload_project_uuid(p) {
        result["project_uuid"] = json!(project_uuid);
    }
    Ok(result)
}
