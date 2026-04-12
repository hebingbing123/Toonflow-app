//! 图片生成任务（`asset.generate.*`）— OpenAI 图片 API + `app_asset_image` 行。

use std::path::Path;

use futures_util::StreamExt;
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::{
    next_asset_image_sort_index, resolve_asset_id_for_job,
    resolve_owned_script_linked_asset_row_for_job,
};
use crate::jobs::JobRow;
use crate::llm::{
    images_generation_or_edit_url, resolve_openai_image_model, resolve_openai_image_size, LlmConfig,
};
use crate::state::AppState;

use super::common::{generation_job_is_cancelled, JobRunError};

/// Cap for **`images/generations`** URL download when persisting under **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`**。
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

fn payload_json_i32(value: &Value, field: &'static str) -> Result<i32, JobRunError> {
    value
        .get(field)
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed(format!("payload missing or invalid {field}")))
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

/// Persist a generated image for a resolved **`app_asset.id`** (must belong to **`ctx.owner`**).
async fn generate_and_store_asset_image_for_row(
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

async fn generate_and_store_asset_image(
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

async fn run_asset_generate_batch_items(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
    cfg: &LlmConfig,
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

        let asset_numeric_id = item
            .get("asset_numeric_id")
            .and_then(|x| x.as_i64())
            .and_then(|n| i32::try_from(n).ok())
            .ok_or_else(|| JobRunError::Failed("item missing asset_numeric_id".into()))?;
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

async fn run_production_assets_batch_generate(
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

    let asset_row = resolve_owned_script_linked_asset_row_for_job(
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

async fn run_production_storyboard_batch_generate_image(
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

async fn run_production_edit_image_generate_flow(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    _row: &JobRow,
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

    if let Some(items) = p.get("items").and_then(|x| x.as_array()) {
        if !items.is_empty() {
            return run_asset_generate_batch_items(
                state,
                pool,
                job_id,
                row,
                cfg,
                p,
                items.as_slice(),
            )
            .await;
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
            run_production_edit_image_generate_flow(state, pool, job_id, row, cfg, p).await
        }
        other => Err(JobRunError::Failed(format!(
            "asset.generate.batch: unsupported payload (source={other:?})"
        ))),
    }
}
