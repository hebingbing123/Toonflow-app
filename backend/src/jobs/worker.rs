//! Polls `queued` jobs and runs a minimal in-process worker (MVP). Scales with `FOR UPDATE SKIP LOCKED`.
//! Running jobs can be cancelled via REST; finish updates use `WHERE status = 'running'` so they never
//! overwrite `cancelled`.

use std::path::Path;
use std::time::Duration;

use futures_util::StreamExt;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::{next_asset_image_sort_index, resolve_asset_id_for_job};
use crate::harness::observe;
use crate::llm::{
    chat_completion_assistant_text, images_generation_url, resolve_openai_image_model,
    resolve_openai_image_size, LlmConfig,
};
use crate::state::AppState;
use crate::usage;

use super::{
    envelope_generation_job_updated, JobRow, JOB_KIND_ASSET_GENERATE_BATCH,
    JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_BATCH, JOB_KIND_ASSET_POLISH_PROMPT,
    JOB_KIND_FLUTTER_PROBE, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST, JOB_KIND_VIDEO_EXPORT,
    JOB_KIND_VIDEO_GENERATE,
};

fn worker_id_label() -> String {
    std::env::var("WORKER_ID")
        .ok()
        .map(|s| s.trim().chars().take(128).collect::<String>())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "default".to_string())
}

pub async fn run(state: AppState) {
    let Some(pool) = state.pool.clone() else {
        tracing::info!("job worker: DATABASE_URL unset; worker not started");
        return;
    };

    let wid = worker_id_label();
    tracing::info!(worker_id = %wid, "job worker: started (poll interval 500ms)");
    let mut interval = tokio::time::interval(Duration::from_millis(500));
    loop {
        interval.tick().await;
        if let Err(e) = process_one_job(&state, &pool, &wid).await {
            tracing::warn!(error = %e, "job worker tick failed");
        }
    }
}

enum JobRunError {
    Failed(String),
    Cancelled,
}

async fn process_one_job(
    state: &AppState,
    pool: &PgPool,
    worker_id: &str,
) -> Result<(), sqlx::Error> {
    let Some(row) = claim_next_job(pool, worker_id).await? else {
        return Ok(());
    };

    observe::generation_job(row.owner_user_id, row.id, "claimed");

    let text = envelope_generation_job_updated(&row);
    state
        .notify
        .broadcast_to_user(row.owner_user_id, text)
        .await;

    let owner = row.owner_user_id;
    let id = row.id;

    let outcome = execute_kind(state, pool, id, &row).await;

    match outcome {
        Ok(result) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'succeeded', result = $1, error_message = NULL, updated_at = NOW()
                WHERE id = $2 AND status = 'running'
                RETURNING id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(result)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(final_row) = updated {
                observe::generation_job(owner, id, "succeeded");
                if let Err(e) =
                    usage::record_generation_job_succeeded(pool, owner, id, &final_row.kind).await
                {
                    tracing::warn!(
                        error = %e,
                        job_id = %id,
                        "app_usage_event insert failed (job still succeeded)"
                    );
                }
                let text = envelope_generation_job_updated(&final_row);
                state.notify.broadcast_to_user(owner, text).await;
            }
            // If None: row was cancelled; cancel_job already sent WS.
        }
        Err(JobRunError::Cancelled) => {
            observe::generation_job(owner, id, "cancelled");
            // Status is already `cancelled`; client was notified by cancel endpoint.
        }
        Err(JobRunError::Failed(msg)) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'failed', error_message = $1, updated_at = NOW()
                WHERE id = $2 AND status = 'running'
                RETURNING id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(msg)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(final_row) = updated {
                observe::generation_job(owner, id, "failed");
                let text = envelope_generation_job_updated(&final_row);
                state.notify.broadcast_to_user(owner, text).await;
            }
        }
    }

    Ok(())
}

async fn claim_next_job(pool: &PgPool, worker_id: &str) -> Result<Option<JobRow>, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let row = sqlx::query_as::<_, JobRow>(
        r#"
        WITH cte AS (
            SELECT id FROM app_generation_job
            WHERE status = 'queued'
            ORDER BY created_at ASC
            FOR UPDATE SKIP LOCKED
            LIMIT 1
        )
        UPDATE app_generation_job AS j
        SET status = 'running', claimed_by = $1, updated_at = NOW()
        FROM cte
        WHERE j.id = cte.id
        RETURNING j.id, j.owner_user_id, j.kind, j.status, j.payload, j.result, j.error_message, j.idempotency_key, j.claimed_by, j.created_at, j.updated_at
        "#,
    )
    .bind(worker_id)
    .fetch_optional(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(row)
}

async fn execute_kind(
    state: &AppState,
    pool: &PgPool,
    id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    match row.kind.as_str() {
        k if k == JOB_KIND_FLUTTER_PROBE => {
            // ~1s total; poll so running cancel can land cooperatively.
            for _ in 0..20 {
                tokio::time::sleep(Duration::from_millis(50)).await;
                let st: String =
                    sqlx::query_scalar("SELECT status::text FROM app_generation_job WHERE id = $1")
                        .bind(id)
                        .fetch_one(pool)
                        .await
                        .map_err(|e| JobRunError::Failed(e.to_string()))?;
                if st == "cancelled" {
                    return Err(JobRunError::Cancelled);
                }
            }
            Ok(json!({ "ok": true, "probe": true }))
        }
        k if k == JOB_KIND_ASSET_GENERATE_IMAGE => {
            run_asset_generate_image(state, pool, id, row).await
        }
        k if k == JOB_KIND_ASSET_POLISH_PROMPT => run_asset_polish_prompt(state, row).await,
        k if k == JOB_KIND_ASSET_GENERATE_BATCH => {
            run_asset_generate_batch(state, pool, id, row).await
        }
        k if k == JOB_KIND_ASSET_POLISH_BATCH => run_asset_polish_batch(state, pool, id, row).await,
        k if k == JOB_KIND_SETTINGS_VENDOR_MODEL_TEST => Err(JobRunError::Failed(
            "vendor modelTest live probe is not implemented yet".into(),
        )),
        k if k == JOB_KIND_VIDEO_GENERATE => Err(JobRunError::Failed(
            "video generation is not implemented yet; video pipeline pending".into(),
        )),
        k if k == JOB_KIND_VIDEO_EXPORT => Err(JobRunError::Failed(
            "video export is not implemented yet; video pipeline pending".into(),
        )),
        other => Err(JobRunError::Failed(format!(
            "unsupported job kind for worker: {other}"
        ))),
    }
}

/// Cap polished text stored on the job row (aligned with HTTP **`prompt`** max on enqueue).
const MAX_POLISHED_PROMPT_CHARS: usize = 48_000;

async fn generation_job_is_cancelled(pool: &PgPool, job_id: Uuid) -> Result<bool, JobRunError> {
    let st: String =
        sqlx::query_scalar("SELECT status::text FROM app_generation_job WHERE id = $1")
            .bind(job_id)
            .fetch_one(pool)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
    Ok(st == "cancelled")
}

async fn polish_asset_description_llm(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    asset_type: &str,
    name: &str,
    describe: &str,
) -> Result<String, JobRunError> {
    let user_msg = format!(
        "Polish the following asset description into a single concise image-generation prompt (keep the user's language).\n\nType: {asset_type}\nName: {name}\nDescription:\n{describe}\n\nReply with only the polished prompt text, no quotes or preamble."
    );

    let messages = vec![
        json!({"role": "system", "content": "You help users refine prompts for creative asset generation."}),
        json!({"role": "user", "content": user_msg}),
    ];

    let mut text = chat_completion_assistant_text(cfg, client, messages)
        .await
        .map_err(JobRunError::Failed)?;

    if text.len() > MAX_POLISHED_PROMPT_CHARS {
        text.truncate(MAX_POLISHED_PROMPT_CHARS);
    }

    Ok(text)
}

async fn run_asset_polish_prompt(
    state: &AppState,
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
        .ok_or_else(|| JobRunError::Failed("payload missing project_legacy_id".into()))?;
    let asset_legacy_id = p
        .get("asset_legacy_id")
        .and_then(|x| x.as_i64())
        .ok_or_else(|| JobRunError::Failed("payload missing asset_legacy_id".into()))?;
    let asset_type = p
        .get("asset_type")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing asset_type".into()))?;
    let name = p
        .get("name")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing name".into()))?;
    let describe = p
        .get("describe")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing describe".into()))?;

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        "asset polish-prompt: calling LLM"
    );

    let text =
        polish_asset_description_llm(cfg, &state.http_client, asset_type, name, describe).await?;

    Ok(json!({
        "source": "assets-generate.polish-prompt",
        "project_legacy_id": project_legacy_id,
        "asset_legacy_id": asset_legacy_id,
        "polished_prompt": text,
    }))
}

async fn run_asset_polish_batch(
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
        .ok_or_else(|| JobRunError::Failed("payload missing project_legacy_id".into()))?;
    let items = p
        .get("items")
        .and_then(|x| x.as_array())
        .ok_or_else(|| JobRunError::Failed("payload missing items".into()))?;
    if items.is_empty() {
        return Err(JobRunError::Failed(
            "payload items is empty (invalid enqueue)".into(),
        ));
    }

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        item_count = items.len(),
        "asset batch-polish: calling LLM per item"
    );

    let mut out = Vec::with_capacity(items.len());
    for item in items {
        if generation_job_is_cancelled(pool, job_id).await? {
            return Err(JobRunError::Cancelled);
        }

        let asset_legacy_id = item
            .get("asset_legacy_id")
            .and_then(|x| x.as_i64())
            .ok_or_else(|| JobRunError::Failed("item missing asset_legacy_id".into()))?;
        let asset_type = item
            .get("asset_type")
            .and_then(|x| x.as_str())
            .ok_or_else(|| JobRunError::Failed("item missing asset_type".into()))?;
        let name = item
            .get("name")
            .and_then(|x| x.as_str())
            .ok_or_else(|| JobRunError::Failed("item missing name".into()))?;
        let describe = item
            .get("describe")
            .and_then(|x| x.as_str())
            .ok_or_else(|| JobRunError::Failed("item missing describe".into()))?;

        let text =
            polish_asset_description_llm(cfg, &state.http_client, asset_type, name, describe)
                .await?;

        out.push(json!({
            "asset_legacy_id": asset_legacy_id,
            "polished_prompt": text,
        }));
    }

    Ok(json!({
        "source": "assets-generate.batch-polish",
        "project_legacy_id": project_legacy_id,
        "items": out,
    }))
}

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

    let (url, revised) = images_generation_url(
        ctx.cfg,
        ctx.http_client,
        ctx.image_model,
        &full_prompt,
        ctx.size,
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
    }))
}

async fn run_asset_generate_image(
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

    let body =
        generate_and_store_asset_image(&ctx, project_legacy_id, asset_legacy_id, name, prompt)
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
    }))
}

async fn run_asset_generate_batch(
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

        let one =
            generate_and_store_asset_image(&ctx, project_legacy_id, asset_legacy_id, name, prompt)
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
