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
    chat_completion_assistant_text, images_generation_or_edit_url, images_generation_url,
    resolve_openai_image_model, resolve_openai_image_size, LlmConfig,
};
use crate::models_catalog::lookup_vendor_catalog;
use crate::state::AppState;
use crate::usage;
use crate::vendor_credential::decrypt;
use crate::video_providers::{
    VideoGenerationRequest, VideoGenerationStatus, VideoProvider, VideoProviderClient,
};

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
                RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
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
                RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
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
        RETURNING j.legacy_task_id, j.id, j.owner_user_id, j.kind, j.status, j.payload, j.result, j.error_message, j.idempotency_key, j.claimed_by, j.created_at, j.updated_at
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
        k if k == JOB_KIND_SETTINGS_VENDOR_MODEL_TEST => {
            run_vendor_model_test(state, pool, row).await
        }
        k if k == JOB_KIND_VIDEO_GENERATE => run_video_generate(state, pool, id, row).await,
        k if k == JOB_KIND_VIDEO_EXPORT => run_video_export(state, pool, id, row).await,
        other => Err(JobRunError::Failed(format!(
            "unsupported job kind for worker: {other}"
        ))),
    }
}

/// Cap polished text stored on the job row (aligned with HTTP **`prompt`** max on enqueue).
const MAX_POLISHED_PROMPT_CHARS: usize = 48_000;
const VENDOR_MODEL_TEST_PREVIEW_CHARS: usize = 160;

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

fn clip_preview(text: &str, max_chars: usize) -> String {
    let trimmed = text.trim();
    if trimmed.chars().count() <= max_chars {
        return trimmed.to_string();
    }
    let mut clipped = trimmed.chars().take(max_chars).collect::<String>();
    clipped.push_str("...");
    clipped
}

#[derive(sqlx::FromRow)]
struct VendorCredentialProbeRow {
    api_key_encrypted: Option<Vec<u8>>,
    api_secret_encrypted: Option<Vec<u8>>,
    api_token_encrypted: Option<Vec<u8>>,
}

async fn load_vendor_probe_secret(
    pool: &PgPool,
    owner_user_id: Uuid,
    candidates: &[String],
) -> Result<Option<String>, JobRunError> {
    for vendor_id in candidates {
        let row = sqlx::query_as::<_, VendorCredentialProbeRow>(
            r#"
            SELECT api_key_encrypted, api_secret_encrypted, api_token_encrypted
            FROM app_vendor_credential
            WHERE owner_user_id = $1 AND vendor_id = $2
            "#,
        )
        .bind(owner_user_id)
        .bind(vendor_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?;

        let Some(row) = row else {
            continue;
        };

        for encrypted in [
            row.api_key_encrypted.as_deref(),
            row.api_token_encrypted.as_deref(),
            row.api_secret_encrypted.as_deref(),
        ]
        .into_iter()
        .flatten()
        {
            if let Some(value) = decrypt(encrypted) {
                let trimmed = value.trim();
                if !trimmed.is_empty() {
                    return Ok(Some(trimmed.to_string()));
                }
            }
        }
    }

    Ok(None)
}

fn vendor_probe_llm_config(
    state: &AppState,
    api_key_override: Option<String>,
    model_name: &str,
) -> Result<LlmConfig, JobRunError> {
    if let Some(api_key) = api_key_override {
        let base_url = std::env::var("OPENAI_BASE_URL")
            .unwrap_or_else(|_| "https://api.openai.com/v1".to_string())
            .trim_end_matches('/')
            .to_string();
        return Ok(LlmConfig {
            api_key,
            base_url,
            model: model_name.to_string(),
        });
    }

    let Some(cfg) = state.llm.as_ref() else {
        return Err(JobRunError::Failed(
            "vendor probe requires stored credential or OPENAI_API_KEY / LLM_API_KEY".into(),
        ));
    };

    Ok(LlmConfig {
        api_key: cfg.api_key.clone(),
        base_url: cfg.base_url.clone(),
        model: model_name.to_string(),
    })
}

async fn run_vendor_model_test(
    state: &AppState,
    pool: &PgPool,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let payload = &row.payload;
    let model_name = payload
        .get("model_name")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing model_name".into()))?;
    let kind = payload
        .get("kind")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing kind".into()))?;
    let raw_vendor_id = payload
        .get("id")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing id".into()))?;

    let (vendor, resolved_vendor_id, vendor_candidates) =
        resolve_vendor_probe_targets(raw_vendor_id);

    let stored_secret =
        load_vendor_probe_secret(pool, row.owner_user_id, &vendor_candidates).await?;
    let credential_source = vendor_probe_credential_source(kind, stored_secret.is_some());

    match kind {
        "text" => {
            let cfg = vendor_probe_llm_config(state, stored_secret, model_name)?;
            let text = chat_completion_assistant_text(
                &cfg,
                &state.http_client,
                vec![
                    json!({"role": "system", "content": "Reply with exactly: pong"}),
                    json!({"role": "user", "content": "ping"}),
                ],
            )
            .await
            .map_err(JobRunError::Failed)?;

            Ok(json!({
                "source": "settings.vendors.model-test",
                "vendor_id": raw_vendor_id,
                "resolved_vendor_id": resolved_vendor_id,
                "resolved_vendor_name": vendor.as_ref().map(|v| v.name.clone()),
                "model_name": model_name,
                "kind": kind,
                "probe_status": "ok",
                "credential_source": credential_source,
                "response_preview": clip_preview(&text, VENDOR_MODEL_TEST_PREVIEW_CHARS),
            }))
        }
        "image" => {
            let cfg = vendor_probe_llm_config(state, stored_secret, model_name)?;
            let resolved_model = resolve_openai_image_model(model_name);
            let size = resolve_openai_image_size(&resolved_model, "1024x1024");
            let (image_url, revised_prompt) = images_generation_url(
                &cfg,
                &state.http_client,
                &resolved_model,
                "Toonflow vendor smoke test image: a simple gray card with the word OK centered.",
                size,
            )
            .await
            .map_err(JobRunError::Failed)?;

            Ok(json!({
                "source": "settings.vendors.model-test",
                "vendor_id": raw_vendor_id,
                "resolved_vendor_id": resolved_vendor_id,
                "resolved_vendor_name": vendor.as_ref().map(|v| v.name.clone()),
                "model_name": resolved_model,
                "kind": kind,
                "probe_status": "ok",
                "credential_source": credential_source,
                "image_url": image_url,
                "revised_prompt": revised_prompt,
            }))
        }
        "video" => {
            let provider = vendor
                .as_ref()
                .and_then(|v| VideoProvider::from_str(&v.slug))
                .or_else(|| VideoProvider::from_str(raw_vendor_id))
                .ok_or_else(|| {
                    JobRunError::Failed(format!(
                        "video vendor '{raw_vendor_id}' is not supported; expected Runway, Pika, or Kling"
                    ))
                })?;

            let response = VideoProviderClient::new()
                .generate_video_with_api_key(
                    &VideoGenerationRequest {
                        provider,
                        model: model_name.to_string(),
                        prompt: "Toonflow vendor smoke test video: a minimal monochrome title card with the word OK.".to_string(),
                        negative_prompt: None,
                        duration: 5,
                        resolution: "720p".to_string(),
                        aspect_ratio: "16:9".to_string(),
                        image_url: None,
                        seed: None,
                    },
                    stored_secret.as_deref(),
                )
                .await
                .map_err(|e| JobRunError::Failed(e.to_string()))?;

            Ok(json!({
                "source": "settings.vendors.model-test",
                "vendor_id": raw_vendor_id,
                "resolved_vendor_id": resolved_vendor_id,
                "resolved_vendor_name": vendor.as_ref().map(|v| v.name.clone()),
                "model_name": response.model,
                "kind": kind,
                "probe_status": match response.status {
                    VideoGenerationStatus::Failed => "failed",
                    _ => "queued",
                },
                "credential_source": credential_source,
                "provider": response.provider,
                "task_id": response.task_id,
                "status": response.status.as_str(),
                "preview_url": response.preview_url,
                "video_url": response.video_url,
                "error_message": response.error_message,
            }))
        }
        other => Err(JobRunError::Failed(format!(
            "unsupported vendor model test kind: {other}"
        ))),
    }
}

fn resolve_vendor_probe_targets(
    raw_vendor_id: &str,
) -> (
    Option<crate::models_catalog::VendorCatalogLookup>,
    String,
    Vec<String>,
) {
    let vendor = lookup_vendor_catalog(raw_vendor_id);
    let resolved_vendor_id = vendor
        .as_ref()
        .map(|v| v.slug.clone())
        .unwrap_or_else(|| raw_vendor_id.trim().to_ascii_lowercase());
    let mut vendor_candidates = vec![raw_vendor_id.trim().to_string()];
    if vendor_candidates.iter().all(|v| v != &resolved_vendor_id) {
        vendor_candidates.push(resolved_vendor_id.clone());
    }
    if let Some(vendor) = vendor.as_ref() {
        let legacy_id = vendor.legacy_id.to_string();
        if vendor_candidates.iter().all(|v| v != &legacy_id) {
            vendor_candidates.push(legacy_id);
        }
    }
    (vendor, resolved_vendor_id, vendor_candidates)
}

fn vendor_probe_credential_source(kind: &str, has_stored_secret: bool) -> &'static str {
    if has_stored_secret {
        "stored_vendor_credential"
    } else if kind == "video" {
        "provider_env"
    } else {
        "server_llm_env"
    }
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

// =============================================================================
// Video Generation
// =============================================================================

async fn run_video_generate(
    _state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let p = &row.payload;

    // Extract provider
    let provider_str = p
        .get("provider")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing provider".into()))?;
    let provider = VideoProvider::from_str(provider_str)
        .ok_or_else(|| JobRunError::Failed(format!("unknown video provider: {}", provider_str)))?;

    // Extract model
    let model = p
        .get("model")
        .and_then(|x| x.as_str())
        .unwrap_or("default")
        .to_string();

    // Extract prompt
    let prompt = p
        .get("prompt")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing prompt".into()))?;

    // Optional parameters
    let negative_prompt = p
        .get("negative_prompt")
        .and_then(|x| x.as_str())
        .map(String::from);
    let duration = p
        .get("duration")
        .and_then(|x| x.as_u64())
        .map(|d| d as u32)
        .unwrap_or(5);
    let resolution = p
        .get("resolution")
        .and_then(|x| x.as_str())
        .map(String::from)
        .unwrap_or_else(|| "720p".to_string());
    let aspect_ratio = p
        .get("aspect_ratio")
        .and_then(|x| x.as_str())
        .map(String::from)
        .unwrap_or_else(|| "16:9".to_string());
    let image_url = p
        .get("image_url")
        .and_then(|x| x.as_str())
        .map(String::from);
    let seed = p.get("seed").and_then(|x| x.as_u64());

    // Project and storyboard IDs for result storage
    let project_legacy_id = p
        .get("project_legacy_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok());
    let storyboard_id = p
        .get("storyboard_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok());

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        provider = %provider.name(),
        model = %model,
        "video generation: submitting to provider"
    );

    let client = VideoProviderClient::new();

    let req = VideoGenerationRequest {
        provider,
        model,
        prompt: prompt.to_string(),
        negative_prompt,
        duration,
        resolution,
        aspect_ratio,
        image_url,
        seed,
    };

    // Submit generation request
    let mut gen_resp = client
        .generate_video(&req)
        .await
        .map_err(|e| JobRunError::Failed(format!("video generation submission failed: {}", e)))?;

    // Poll for completion
    let max_polls = 120; // ~2 minutes at 1 second intervals
    for _poll_count in 0..max_polls {
        if generation_job_is_cancelled(pool, job_id).await? {
            return Err(JobRunError::Cancelled);
        }

        match gen_resp.status {
            VideoGenerationStatus::Completed => {
                break;
            }
            VideoGenerationStatus::Failed => {
                return Err(JobRunError::Failed(
                    gen_resp
                        .error_message
                        .unwrap_or_else(|| "Video generation failed".to_string()),
                ));
            }
            _ => {
                tokio::time::sleep(Duration::from_secs(1)).await;
                gen_resp = client
                    .poll_generation(provider, &gen_resp.task_id)
                    .await
                    .map_err(|e| JobRunError::Failed(format!("poll failed: {}", e)))?;
            }
        }
    }

    if gen_resp.status != VideoGenerationStatus::Completed {
        return Err(JobRunError::Failed("video generation timeout".to_string()));
    }

    let video_url = gen_resp
        .video_url
        .clone()
        .ok_or_else(|| JobRunError::Failed("no video URL in completed response".to_string()))?;

    // Store video reference in database if project/storyboard IDs provided
    if let (Some(pid), Some(sid)) = (project_legacy_id, storyboard_id) {
        if let Err(e) =
            store_video_reference(pool, row.owner_user_id, pid, sid, &video_url, &gen_resp).await
        {
            tracing::warn!(error = %e, "failed to store video reference");
        }
    }

    Ok(json!({
        "source": "video.generate",
        "provider": provider_str,
        "model": gen_resp.model,
        "task_id": gen_resp.task_id,
        "video_url": video_url,
        "preview_url": gen_resp.preview_url,
        "project_legacy_id": project_legacy_id,
        "storyboard_id": storyboard_id,
    }))
}

async fn store_video_reference(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_legacy_id: i32,
    storyboard_legacy_id: i32,
    video_url: &str,
    _resp: &crate::video_providers::VideoGenerationResponse,
) -> Result<(), sqlx::Error> {
    // Update storyboard with video URL
    sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $1, state = '已完成', updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $2
          AND app_project.legacy_id = $3
          AND app_storyboard.legacy_id = $4
        "#,
    )
    .bind(video_url)
    .bind(owner_user_id)
    .bind(project_legacy_id)
    .bind(storyboard_legacy_id)
    .execute(pool)
    .await?;

    Ok(())
}

async fn run_video_export(
    _state: &AppState,
    _pool: &PgPool,
    _job_id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let p = &row.payload;

    // Extract source video URL
    let source_url = p
        .get("source_url")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing source_url".into()))?;

    let format = p.get("format").and_then(|x| x.as_str()).unwrap_or("mp4");

    let target_resolution = p.get("target_resolution").and_then(|x| x.as_str());
    let include_audio = p
        .get("include_audio")
        .and_then(|x| x.as_bool())
        .unwrap_or(true);

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        source_url = %source_url,
        format = %format,
        "video export: processing"
    );

    // For now, video export is a pass-through with metadata
    // In production, this would:
    // 1. Download source video
    // 2. Re-encode if resolution/format differs
    // 3. Handle audio track
    // 4. Upload to storage
    // 5. Return new URL

    let client = VideoProviderClient::new();
    let export_req = crate::video_providers::VideoExportRequest {
        source_url: source_url.to_string(),
        format: format.to_string(),
        target_resolution: target_resolution.map(String::from),
        include_audio,
    };

    let export_resp = client
        .export_video(&export_req)
        .await
        .map_err(|e| JobRunError::Failed(format!("export failed: {}", e)))?;

    let export_url = export_resp
        .export_url
        .ok_or_else(|| JobRunError::Failed("no export URL in response".to_string()))?;

    Ok(json!({
        "source": "video.export",
        "task_id": export_resp.task_id,
        "status": export_resp.status.as_str(),
        "export_url": export_url,
        "format": format,
        "include_audio": include_audio,
    }))
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use tokio::sync::RwLock;

    use super::*;
    use crate::notify_hub::WsNotifyHub;
    use crate::state::MemoryConfig;

    fn test_state_without_llm() -> AppState {
        AppState {
            pool: None,
            jwt_secret: None,
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
            memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
            switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
            local_asset_image_dir: None,
            local_art_style_cover_dir: None,
        }
    }

    #[test]
    fn clip_preview_trims_and_ellipsizes() {
        assert_eq!(clip_preview("  ok  ", 8), "ok");
        assert_eq!(clip_preview("abcdef", 4), "abcd...");
    }

    #[test]
    fn resolve_vendor_probe_targets_expands_catalog_aliases() {
        let (vendor, resolved_vendor_id, candidates) = resolve_vendor_probe_targets("1");
        assert!(
            vendor.is_some(),
            "legacy id should resolve into vendor catalog"
        );
        assert_eq!(resolved_vendor_id, "openai");
        assert_eq!(candidates, vec!["1", "openai"]);
    }

    #[test]
    fn resolve_vendor_probe_targets_normalizes_unknown_vendor_ids() {
        let (vendor, resolved_vendor_id, candidates) =
            resolve_vendor_probe_targets("  CUSTOM-ENDPOINT  ");
        assert!(vendor.is_none());
        assert_eq!(resolved_vendor_id, "custom-endpoint");
        assert_eq!(candidates, vec!["CUSTOM-ENDPOINT", "custom-endpoint"]);
    }

    #[test]
    fn vendor_probe_credential_source_prefers_stored_credentials() {
        assert_eq!(
            vendor_probe_credential_source("text", true),
            "stored_vendor_credential"
        );
        assert_eq!(
            vendor_probe_credential_source("image", false),
            "server_llm_env"
        );
        assert_eq!(
            vendor_probe_credential_source("video", false),
            "provider_env"
        );
    }

    #[test]
    fn vendor_probe_llm_config_without_state_llm_returns_clear_error() {
        let state = test_state_without_llm();
        let err = match vendor_probe_llm_config(&state, None, "gpt-4o-mini") {
            Ok(_) => panic!("text/image probe should require llm config or stored secret"),
            Err(err) => err,
        };

        match err {
            JobRunError::Failed(message) => {
                assert!(
                    message.contains("OPENAI_API_KEY") || message.contains("LLM_API_KEY"),
                    "unexpected message: {message}"
                );
            }
            JobRunError::Cancelled => panic!("unexpected cancellation"),
        }
    }
}
