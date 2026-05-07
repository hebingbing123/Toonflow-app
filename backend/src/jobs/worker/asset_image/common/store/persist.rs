//! 生成图并写入 `app_asset_image`（及脚本侧校验）。

use serde_json::json;
use uuid::Uuid;

use crate::assets::next_asset_image_sort_index;
use crate::jobs::worker::common::JobRunError;
use crate::llm::images_generation_or_edit_url;

use super::super::download::download_image_bytes_capped;
use super::super::payload::{combine_image_prompt, AssetImageGenCtx};

/// Persist a generated image for a resolved `app_asset.id` (must belong to `ctx.owner`).
pub(crate) async fn generate_and_store_asset_image_for_row(
    ctx: &AssetImageGenCtx<'_>,
    asset_id: Uuid,
    asset_numeric_id: i32,
    name: &str,
    prompt: &str,
    image_base64: Option<&str>,
) -> Result<serde_json::Value, JobRunError> {
    let full_prompt = combine_image_prompt(name, prompt);
    if full_prompt.is_empty() {
        return Err(JobRunError::Failed("empty image prompt".into()));
    }

    let project_id: Uuid = sqlx::query_scalar(
        r#"
        SELECT a.project_id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE a.id = $1
          AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $2
          )
        "#,
    )
    .bind(asset_id)
    .bind(ctx.owner)
    .fetch_optional(ctx.pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?
    .ok_or_else(|| JobRunError::Failed("asset not found for owner".into()))?;

    let (url, revised) = images_generation_or_edit_url(
        ctx.cfg,
        ctx.http_client,
        ctx.image_model,
        &full_prompt,
        ctx.size,
        image_base64,
    )
    .await
    .map_err(JobRunError::Failed)?;

    let sort_index = next_asset_image_sort_index(ctx.pool, asset_id)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?;
    let image_row_id = Uuid::new_v4();

    let (file_path, metadata, image_url) = if let Some(root) = ctx.local_asset_image_dir {
        let bytes = download_image_bytes_capped(ctx.http_client, &url).await?;
        let user_dir = root.join(ctx.owner.to_string());
        tokio::fs::create_dir_all(&user_dir)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
        let disk_path = user_dir.join(format!("{image_row_id}.png"));
        tokio::fs::write(&disk_path, &bytes)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
        let api_path = format!(
            "/api/v1/projects/{}/assets/{}/images/{}/file",
            project_id, asset_numeric_id, image_row_id
        );
        let metadata = json!({
            "source": "jobs.worker.asset_image",
            "generation_job_id": ctx.job_id,
            "request_model": ctx.request_model,
            "image_model": ctx.image_model,
            "size": ctx.size,
            "revised_prompt": revised,
            "has_reference_image": image_base64.is_some(),
            "storage": "local",
            "provider_url": url,
        });
        (api_path.clone(), metadata, api_path)
    } else {
        let metadata = json!({
            "source": "jobs.worker.asset_image",
            "generation_job_id": ctx.job_id,
            "request_model": ctx.request_model,
            "image_model": ctx.image_model,
            "size": ctx.size,
            "revised_prompt": revised,
            "has_reference_image": image_base64.is_some(),
        });
        (url.clone(), metadata, url)
    };

    sqlx::query_scalar::<_, Uuid>(
        r#"
        INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id
        "#,
    )
    .bind(image_row_id)
    .bind(asset_id)
    .bind(sort_index)
    .bind(&file_path)
    .bind(Some("已完成".to_string()))
    .bind(metadata)
    .fetch_one(ctx.pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;

    Ok(json!({
        "asset_numeric_id": asset_numeric_id,
        "asset_image_id": image_row_id,
        "image_url": image_url,
        "revised_prompt": revised,
        "has_reference_image": image_base64.is_some(),
    }))
}
