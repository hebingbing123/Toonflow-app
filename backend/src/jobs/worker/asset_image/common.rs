use std::path::Path;

use futures_util::StreamExt;
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::{
    next_asset_image_sort_index, resolve_asset_id_for_job,
    resolve_owned_script_linked_asset_row_for_job,
};
use crate::jobs::worker::common::JobRunError;
use crate::llm::{images_generation_or_edit_url, LlmConfig};

/// Cap for `images/generations` URL download when persisting under local asset dir.
const MAX_DOWNLOADED_ASSET_IMAGE_BYTES: u64 = 32 * 1024 * 1024;

pub(super) async fn download_image_bytes_capped(
    client: &reqwest::Client,
    url: &str,
) -> Result<Vec<u8>, JobRunError> {
    let resp = client
        .get(url)
        .send()
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?;
    if !resp.status().is_success() {
        return Err(JobRunError::Failed(format!(
            "image download HTTP {}",
            resp.status()
        )));
    }
    let max = MAX_DOWNLOADED_ASSET_IMAGE_BYTES as usize;
    if let Some(cl) = resp.content_length() {
        if cl > max as u64 {
            return Err(JobRunError::Failed("image Content-Length too large".into()));
        }
    }
    let mut stream = resp.bytes_stream();
    let mut out = Vec::new();
    while let Some(item) = stream.next().await {
        let chunk = item.map_err(|e| JobRunError::Failed(e.to_string()))?;
        if out.len().saturating_add(chunk.len()) > max {
            return Err(JobRunError::Failed("image body too large".into()));
        }
        out.extend_from_slice(&chunk);
    }
    Ok(out)
}

pub(super) fn combine_image_prompt(name: &str, body: &str) -> String {
    let n = name.trim();
    let b = body.trim();
    match (n.is_empty(), b.is_empty()) {
        (true, true) => String::new(),
        (true, false) => b.to_string(),
        (false, true) => n.to_string(),
        (false, false) => format!("{n}\n{b}"),
    }
}

pub(super) fn payload_json_i32(value: &Value, field: &'static str) -> Result<i32, JobRunError> {
    value
        .get(field)
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed(format!("payload missing or invalid {field}")))
}

pub(super) struct AssetImageGenCtx<'a> {
    pub(super) cfg: &'a LlmConfig,
    pub(super) http_client: &'a reqwest::Client,
    pub(super) pool: &'a PgPool,
    pub(super) job_id: Uuid,
    pub(super) owner: Uuid,
    pub(super) request_model: &'a str,
    pub(super) image_model: &'a str,
    pub(super) size: &'a str,
    /// When set, worker downloads the provider URL and writes `{dir}/{owner}/{id}.png`.
    pub(super) local_asset_image_dir: Option<&'a Path>,
}

/// Persist a generated image for a resolved `app_asset.id` (must belong to `ctx.owner`).
pub(super) async fn generate_and_store_asset_image_for_row(
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
        WHERE a.id = $1 AND p.owner_user_id = $2
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

pub(super) async fn generate_and_store_asset_image(
    ctx: &AssetImageGenCtx<'_>,
    project_numeric_id: i32,
    asset_numeric_id: i32,
    name: &str,
    prompt: &str,
    image_base64: Option<&str>,
) -> Result<serde_json::Value, JobRunError> {
    let asset_id =
        resolve_asset_id_for_job(ctx.pool, ctx.owner, project_numeric_id, asset_numeric_id)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?
            .ok_or_else(|| {
                JobRunError::Failed("asset not found for project or not owned".into())
            })?;

    generate_and_store_asset_image_for_row(
        ctx,
        asset_id,
        asset_numeric_id,
        name,
        prompt,
        image_base64,
    )
    .await
}

pub(super) async fn ensure_script_scoped_asset_exists(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    asset_numeric_id: i32,
) -> Result<(), JobRunError> {
    resolve_owned_script_linked_asset_row_for_job(
        pool,
        owner_user_id,
        project_numeric_id,
        script_numeric_id,
        asset_numeric_id,
    )
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?
    .ok_or_else(|| {
        JobRunError::Failed(
            "asset.generate.batch items: asset not linked to script (script_id in payload)".into(),
        )
    })?;
    Ok(())
}
