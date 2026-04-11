//! 图片生成任务（`asset.generate.*`）— OpenAI 图片 API + `app_asset_image` 行。

use std::path::Path;

use futures_util::StreamExt;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::{next_asset_image_sort_index, resolve_asset_id_for_job};
use crate::jobs::JobRow;
use crate::llm::{
    images_generation_or_edit_url, resolve_openai_image_model, resolve_openai_image_size, LlmConfig,
};
use crate::state::AppState;

use super::common::{generation_job_is_cancelled, JobRunError};

/// Cap for **`images/generations`** URL download when persisting under **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`**.
const MAX_DOWNLOADED_ASSET_IMAGE_BYTES: u64 = 32 * 1024 * 1024;

async fn download_image_bytes_capped(
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

fn combine_image_prompt(name: &str, body: &str) -> String {
    let n = name.trim();
    let b = body.trim();
    match (n.is_empty(), b.is_empty()) {
        (true, true) => String::new(),
        (true, false) => b.to_string(),
        (false, true) => n.to_string(),
        (false, false) => format!("{n}\n{b}"),
    }
}

struct AssetImageGenCtx<'a> {
    cfg: &'a LlmConfig,
    http_client: &'a reqwest::Client,
    pool: &'a PgPool,
    job_id: Uuid,
    owner: Uuid,
    request_model: &'a str,
    image_model: &'a str,
    size: &'a str,
    /// When set, worker downloads the provider URL and writes **`{dir}/{owner}/{id}.png`** (see env).
    local_asset_image_dir: Option<&'a Path>,
}

async fn generate_and_store_asset_image(
    ctx: &AssetImageGenCtx<'_>,
    project_legacy_id: i32,
    asset_legacy_id: i32,
    name: &str,
    prompt: &str,
    image_base64: Option<&str>,
) -> Result<serde_json::Value, JobRunError> {
    let full_prompt = combine_image_prompt(name, prompt);
    if full_prompt.is_empty() {
        return Err(JobRunError::Failed("empty image prompt".into()));
    }

    let asset_id =
        resolve_asset_id_for_job(ctx.pool, ctx.owner, project_legacy_id, asset_legacy_id)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?
            .ok_or_else(|| {
                JobRunError::Failed("asset not found for project or not owned".into())
            })?;

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
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_row_id}/file"
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
        "asset_legacy_id": asset_legacy_id,
        "asset_image_id": image_row_id,
        "image_url": image_url,
        "revised_prompt": revised,
        "has_reference_image": image_base64.is_some(),
    }))
}

pub(super) async fn run_asset_generate_image(
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
    let project_legacy_id = p
        .get("project_legacy_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed("payload missing project_legacy_id".into()))?;
    let asset_legacy_id = p
        .get("asset_legacy_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed("payload missing asset_legacy_id".into()))?;
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
    let image_base64 = p.get("image_base64").and_then(|x| x.as_str());

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
        project_legacy_id,
        asset_legacy_id,
        name,
        prompt,
        image_base64,
    )
    .await?;

    Ok(json!({
        "source": "assets-generate.generate",
        "project_legacy_id": project_legacy_id,
        "image_model": image_model,
        "size": size,
        "asset_legacy_id": asset_legacy_id,
        "asset_image_id": body["asset_image_id"],
        "image_url": body["image_url"],
        "revised_prompt": body["revised_prompt"],
        "has_reference_image": body["has_reference_image"],
    }))
}

pub(super) async fn run_asset_generate_batch(
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
    let project_legacy_id = p
        .get("project_legacy_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed("payload missing project_legacy_id".into()))?;
    let model_in = p
        .get("model")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing model".into()))?;
    let resolution = p
        .get("resolution")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing resolution".into()))?;
    let items = p
        .get("items")
        .and_then(|x| x.as_array())
        .ok_or_else(|| JobRunError::Failed("payload missing items".into()))?;
    if items.is_empty() {
        return Err(JobRunError::Failed(
            "payload items is empty (invalid enqueue)".into(),
        ));
    }

    let image_model = resolve_openai_image_model(model_in);
    let size = resolve_openai_image_size(&image_model, resolution);

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        item_count = items.len(),
        image_model = %image_model,
        size = %size,
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

        let asset_legacy_id = item
            .get("asset_legacy_id")
            .and_then(|x| x.as_i64())
            .and_then(|n| i32::try_from(n).ok())
            .ok_or_else(|| JobRunError::Failed("item missing asset_legacy_id".into()))?;
        let name = item.get("name").and_then(|x| x.as_str()).unwrap_or("");
        let prompt = item
            .get("prompt")
            .and_then(|x| x.as_str())
            .ok_or_else(|| JobRunError::Failed("item missing prompt".into()))?;
        let image_base64 = item.get("image_base64").and_then(|x| x.as_str());

        let one = generate_and_store_asset_image(
            &ctx,
            project_legacy_id,
            asset_legacy_id,
            name,
            prompt,
            image_base64,
        )
        .await?;
        out.push(one);
    }

    Ok(json!({
        "source": "assets-generate.batch-generate",
        "project_legacy_id": project_legacy_id,
        "image_model": image_model,
        "size": size,
        "items": out,
    }))
}
