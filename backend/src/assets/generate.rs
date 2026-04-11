//! 遗留 `/api/assetsGenerate/*` 资产生成端点。
//!
//! 处理单图生成、提示词优化、批量生成和批量优化请求，
//! 将任务加入 `app_generation_job` 队列由后台 Worker 执行。
//!
//! 端点：
//! - `POST …/generate` — 单图生成
//! - `POST …/polish-prompt` — 单条提示词优化
//! - `POST …/batch-generate` — 批量图片生成
//! - `POST …/batch-polish` — 批量提示词优化
//! - `POST …/cancel-generate` — 取消生成任务

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Json as JsonResponse, Router,
};
use serde::Deserialize;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{
    enqueue_generation_job, JobRow, JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_GENERATE_IMAGE,
    JOB_KIND_ASSET_POLISH_BATCH, JOB_KIND_ASSET_POLISH_PROMPT,
};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
enum AssetGenKind {
    #[serde(rename = "role")]
    Role,
    #[serde(rename = "scene")]
    Scene,
    #[serde(rename = "tool")]
    Tool,
    #[serde(rename = "storyboard")]
    Storyboard,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GenerateAssetsBody {
    project_id: i32,
    model: String,
    resolution: String,
    id: i32,
    #[serde(rename = "type")]
    asset_type: AssetGenKind,
    name: String,
    prompt: String,
    #[serde(default)]
    base64: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PolishAssetsPromptBody {
    assets_id: i32,
    project_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    name: String,
    describe: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchGenItem {
    id: i32,
    #[serde(rename = "type")]
    asset_type: AssetGenKind,
    name: String,
    prompt: String,
    #[serde(default)]
    base64: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchGenerateImageAssetsBody {
    project_id: i32,
    model: String,
    resolution: String,
    #[serde(default)]
    concurrent_count: Option<i32>,
    items: Vec<BatchGenItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchPolishItem {
    assets_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    name: String,
    describe: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchPolishAssetsPromptBody {
    project_id: i32,
    #[serde(default)]
    concurrent_count: Option<i32>,
    items: Vec<BatchPolishItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct CancelGenerateBody {
    id: i32,
}

fn asset_type_str(k: &AssetGenKind) -> &'static str {
    match k {
        AssetGenKind::Role => "role",
        AssetGenKind::Scene => "scene",
        AssetGenKind::Tool => "tool",
        AssetGenKind::Storyboard => "storyboard",
    }
}

fn trim_non_empty_str(s: &str, field: &'static str) -> Result<String, ApiError> {
    let t = s.trim();
    if t.is_empty() {
        return Err(ApiError::BadRequest(format!("{field} must be non-empty")));
    }
    Ok(t.to_owned())
}

fn trim_non_empty(s: String, field: &'static str) -> Result<String, ApiError> {
    trim_non_empty_str(&s, field)
}

fn normalize_optional_base64(
    input: Option<&str>,
    field: &'static str,
) -> Result<Option<String>, ApiError> {
    let Some(raw) = input else {
        return Ok(None);
    };
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    if trimmed.len() > MAX_BASE64_HINT_LEN {
        return Err(ApiError::BadRequest(format!(
            "{field} must be at most {MAX_BASE64_HINT_LEN} chars"
        )));
    }
    if trimmed.starts_with("data:") {
        return Ok(Some(trimmed.to_owned()));
    }
    Ok(Some(format!("data:image/jpeg;base64,{trimmed}")))
}

const MAX_MODEL_LEN: usize = 512;
const MAX_RESOLUTION_LEN: usize = 128;
const MAX_NAME_LEN: usize = 512;
const MAX_PROMPT_LEN: usize = 48_000;
const MAX_BASE64_HINT_LEN: usize = 24_000_000;
const MAX_ASSET_TYPE_LEN: usize = 64;
const MAX_DESCRIBE_LEN: usize = 48_000;
/// Legacy batch calls can send many rows; cap payload size.
const MAX_BATCH_ITEMS: usize = 50;
const MAX_CONCURRENT_COUNT: i32 = 20;

async fn resolve_owned_project_uuid(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
) -> Result<Uuid, ApiError> {
    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    let id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    id.ok_or(ApiError::NotFound)
}

async fn post_generate_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateAssetsBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.id <= 0 {
        return Err(ApiError::BadRequest(
            "id (asset legacy id) must be positive".into(),
        ));
    }
    let model = trim_non_empty(body.model, "model")?;
    let resolution = trim_non_empty(body.resolution, "resolution")?;
    let name = trim_non_empty(body.name, "name")?;
    let prompt = trim_non_empty(body.prompt, "prompt")?;
    if model.len() > MAX_MODEL_LEN {
        return Err(ApiError::BadRequest(format!(
            "model must be at most {MAX_MODEL_LEN} chars"
        )));
    }
    if resolution.len() > MAX_RESOLUTION_LEN {
        return Err(ApiError::BadRequest(format!(
            "resolution must be at most {MAX_RESOLUTION_LEN} chars"
        )));
    }
    if name.len() > MAX_NAME_LEN {
        return Err(ApiError::BadRequest(format!(
            "name must be at most {MAX_NAME_LEN} chars"
        )));
    }
    if prompt.len() > MAX_PROMPT_LEN {
        return Err(ApiError::BadRequest(format!(
            "prompt must be at most {MAX_PROMPT_LEN} chars"
        )));
    }
    let image_base64 = normalize_optional_base64(body.base64.as_deref(), "base64")?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let _project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;

    let asset_type = asset_type_str(&body.asset_type);
    let payload = json!({
        "source": "assets-generate.generate",
        "project_numeric_id": body.project_id,
        "asset_numeric_id": body.id,
        "model": model,
        "resolution": resolution,
        "asset_type": asset_type,
        "name": name,
        "prompt": prompt,
        "has_base64": image_base64.is_some(),
        "image_base64": image_base64,
    });

    let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_IMAGE, payload).await?;
    Ok(JsonResponse(row))
}

async fn post_polish_assets_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PolishAssetsPromptBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.assets_id <= 0 {
        return Err(ApiError::BadRequest("assetsId must be positive".into()));
    }
    let asset_type = trim_non_empty(body.asset_type, "type")?;
    let name = trim_non_empty(body.name, "name")?;
    let describe = trim_non_empty(body.describe, "describe")?;
    if asset_type.len() > MAX_ASSET_TYPE_LEN {
        return Err(ApiError::BadRequest(format!(
            "type must be at most {MAX_ASSET_TYPE_LEN} chars"
        )));
    }
    if name.len() > MAX_NAME_LEN {
        return Err(ApiError::BadRequest(format!(
            "name must be at most {MAX_NAME_LEN} chars"
        )));
    }
    if describe.len() > MAX_DESCRIBE_LEN {
        return Err(ApiError::BadRequest(format!(
            "describe must be at most {MAX_DESCRIBE_LEN} chars"
        )));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let _project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;

    let payload = json!({
        "source": "assets-generate.polish-prompt",
        "project_numeric_id": body.project_id,
        "asset_numeric_id": body.assets_id,
        "asset_type": asset_type,
        "name": name,
        "describe": describe,
    });

    let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_POLISH_PROMPT, payload).await?;
    Ok(JsonResponse(row))
}

async fn post_batch_generate_image_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchGenerateImageAssetsBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.items.is_empty() {
        return Err(ApiError::BadRequest("items must be non-empty".into()));
    }
    if body.items.len() > MAX_BATCH_ITEMS {
        return Err(ApiError::BadRequest(format!(
            "items must have at most {MAX_BATCH_ITEMS} rows"
        )));
    }
    if let Some(n) = body.concurrent_count {
        if n <= 0 {
            return Err(ApiError::BadRequest(
                "concurrentCount must be at least 1".into(),
            ));
        }
        if n > MAX_CONCURRENT_COUNT {
            return Err(ApiError::BadRequest(format!(
                "concurrentCount must be at most {MAX_CONCURRENT_COUNT}"
            )));
        }
    }

    let model = trim_non_empty(body.model, "model")?;
    let resolution = trim_non_empty(body.resolution, "resolution")?;
    if model.len() > MAX_MODEL_LEN {
        return Err(ApiError::BadRequest(format!(
            "model must be at most {MAX_MODEL_LEN} chars"
        )));
    }
    if resolution.len() > MAX_RESOLUTION_LEN {
        return Err(ApiError::BadRequest(format!(
            "resolution must be at most {MAX_RESOLUTION_LEN} chars"
        )));
    }

    let mut items_json = Vec::with_capacity(body.items.len());
    for it in &body.items {
        if it.id <= 0 {
            return Err(ApiError::BadRequest(
                "each items[].id must be positive".into(),
            ));
        }
        let name = trim_non_empty_str(&it.name, "items[].name")?;
        let prompt = trim_non_empty_str(&it.prompt, "items[].prompt")?;
        if name.len() > MAX_NAME_LEN {
            return Err(ApiError::BadRequest(format!(
                "items[].name must be at most {MAX_NAME_LEN} chars"
            )));
        }
        if prompt.len() > MAX_PROMPT_LEN {
            return Err(ApiError::BadRequest(format!(
                "items[].prompt must be at most {MAX_PROMPT_LEN} chars"
            )));
        }
        let image_base64 = normalize_optional_base64(it.base64.as_deref(), "items[].base64")?;
        let asset_type = asset_type_str(&it.asset_type);
        items_json.push(json!({
            "asset_numeric_id": it.id,
            "asset_type": asset_type,
            "name": name,
            "prompt": prompt,
            "has_base64": image_base64.is_some(),
            "image_base64": image_base64,
        }));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let _project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;

    let payload = json!({
        "source": "assets-generate.batch-generate",
        "project_numeric_id": body.project_id,
        "model": model,
        "resolution": resolution,
        "concurrent_count": body.concurrent_count,
        "items": items_json,
    });

    let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_BATCH, payload).await?;
    Ok(JsonResponse(row))
}

async fn post_batch_polish_assets_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchPolishAssetsPromptBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.items.is_empty() {
        return Err(ApiError::BadRequest("items must be non-empty".into()));
    }
    if body.items.len() > MAX_BATCH_ITEMS {
        return Err(ApiError::BadRequest(format!(
            "items must have at most {MAX_BATCH_ITEMS} rows"
        )));
    }
    if let Some(n) = body.concurrent_count {
        if n <= 0 {
            return Err(ApiError::BadRequest(
                "concurrentCount must be at least 1".into(),
            ));
        }
        if n > MAX_CONCURRENT_COUNT {
            return Err(ApiError::BadRequest(format!(
                "concurrentCount must be at most {MAX_CONCURRENT_COUNT}"
            )));
        }
    }

    let mut items_json = Vec::with_capacity(body.items.len());
    for it in &body.items {
        if it.assets_id <= 0 {
            return Err(ApiError::BadRequest(
                "each items[].assetsId must be positive".into(),
            ));
        }
        let asset_type = trim_non_empty_str(&it.asset_type, "items[].type")?;
        let name = trim_non_empty_str(&it.name, "items[].name")?;
        let describe = trim_non_empty_str(&it.describe, "items[].describe")?;
        if asset_type.len() > MAX_ASSET_TYPE_LEN {
            return Err(ApiError::BadRequest(format!(
                "items[].type must be at most {MAX_ASSET_TYPE_LEN} chars"
            )));
        }
        if name.len() > MAX_NAME_LEN {
            return Err(ApiError::BadRequest(format!(
                "items[].name must be at most {MAX_NAME_LEN} chars"
            )));
        }
        if describe.len() > MAX_DESCRIBE_LEN {
            return Err(ApiError::BadRequest(format!(
                "items[].describe must be at most {MAX_DESCRIBE_LEN} chars"
            )));
        }
        items_json.push(json!({
            "asset_numeric_id": it.assets_id,
            "asset_type": asset_type,
            "name": name,
            "describe": describe,
        }));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let _project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;

    let payload = json!({
        "source": "assets-generate.batch-polish",
        "project_numeric_id": body.project_id,
        "concurrent_count": body.concurrent_count,
        "items": items_json,
    });

    let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_POLISH_BATCH, payload).await?;
    Ok(JsonResponse(row))
}

async fn post_cancel_generate(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CancelGenerateBody>,
) -> Result<JsonResponse<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let _ = sqlx::query(
        r#"
        UPDATE app_asset_image ai
        SET state = '生成失败',
            metadata = COALESCE(ai.metadata, '{}'::jsonb)
              || jsonb_build_object('cancelled', true, 'cancel_source', 'legacy.assets-generate.cancel-generate')
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE ai.asset_id = a.id
          AND p.owner_user_id = $1
          AND ai.legacy_image_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let cancelled_jobs = sqlx::query_as::<_, JobRow>(
        r#"
        WITH target_assets AS (
            SELECT a.legacy_id
            FROM app_asset_image ai
            INNER JOIN app_asset a ON a.id = ai.asset_id
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.owner_user_id = $1
              AND ai.legacy_image_id = $2
        ),
        cancelled AS (
            UPDATE app_generation_job j
            SET status = 'cancelled',
                result = COALESCE(j.result, '{}'::jsonb)
                  || jsonb_build_object(
                    'cancelled', true,
                    'cancel_source', 'legacy.assets-generate.cancel-generate',
                    'cancel_numeric_image_id', $2
                  ),
                updated_at = NOW()
            WHERE j.owner_user_id = $1
              AND j.status IN ('queued', 'running')
              AND j.kind IN ($3, $4, $5, $6)
              AND EXISTS (
                SELECT 1
                FROM target_assets t
                WHERE (
                  (j.payload ? 'asset_numeric_id')
                  AND (j.payload->>'asset_numeric_id') ~ '^[0-9]+$'
                  AND (j.payload->>'asset_numeric_id')::int = t.legacy_id
                ) OR EXISTS (
                  SELECT 1
                  FROM jsonb_array_elements(COALESCE(j.payload->'items', '[]'::jsonb)) it
                  WHERE (it ? 'asset_numeric_id')
                    AND (it->>'asset_numeric_id') ~ '^[0-9]+$'
                    AND (it->>'asset_numeric_id')::int = t.legacy_id
                )
              )
            RETURNING j.legacy_task_id, j.id, j.owner_user_id, j.kind, j.status, j.payload, j.result, j.error_message, j.idempotency_key, j.claimed_by, j.created_at, j.updated_at
        )
        SELECT * FROM cancelled
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .bind(JOB_KIND_ASSET_GENERATE_IMAGE)
    .bind(JOB_KIND_ASSET_POLISH_PROMPT)
    .bind(JOB_KIND_ASSET_GENERATE_BATCH)
    .bind(JOB_KIND_ASSET_POLISH_BATCH)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for row in cancelled_jobs {
        let text = crate::jobs::envelope_generation_job_updated(&row);
        state.notify.broadcast_to_user(uid, text).await;
    }

    Ok(JsonResponse(json!({ "message": "取消成功" })))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/assets-generate/generate",
            post(post_generate_assets),
        )
        .route(
            "/api/v1/assets-generate/polish-prompt",
            post(post_polish_assets_prompt),
        )
        .route(
            "/api/v1/assets-generate/batch-generate",
            post(post_batch_generate_image_assets),
        )
        .route(
            "/api/v1/assets-generate/batch-polish",
            post(post_batch_polish_assets_prompt),
        )
        .route(
            "/api/v1/assets-generate/cancel-generate",
            post(post_cancel_generate),
        )
}

#[cfg(test)]
mod tests {
    use super::{normalize_optional_base64, MAX_BASE64_HINT_LEN};
    use crate::error::ApiError;

    #[test]
    fn normalize_base64_none_or_blank_to_none() {
        assert_eq!(
            normalize_optional_base64(None, "base64").expect("none"),
            None
        );
        assert_eq!(
            normalize_optional_base64(Some("  "), "base64").expect("blank"),
            None
        );
    }

    #[test]
    fn normalize_base64_raw_to_data_uri() {
        let got = normalize_optional_base64(Some("  QUJDRA== "), "base64").expect("raw");
        assert_eq!(got.as_deref(), Some("data:image/jpeg;base64,QUJDRA=="));
    }

    #[test]
    fn normalize_base64_keeps_data_uri() {
        let src = "data:image/png;base64,AA==";
        let got = normalize_optional_base64(Some(src), "base64").expect("uri");
        assert_eq!(got.as_deref(), Some(src));
    }

    #[test]
    fn normalize_base64_rejects_over_limit() {
        let oversized = "A".repeat(MAX_BASE64_HINT_LEN + 1);
        let err = normalize_optional_base64(Some(&oversized), "base64").expect_err("oversized");
        match err {
            ApiError::BadRequest(msg) => assert!(
                msg.contains(&format!("at most {MAX_BASE64_HINT_LEN} chars")),
                "msg={msg}"
            ),
            other => panic!("expected bad_request, got {other:?}"),
        }
    }

    #[test]
    fn normalize_base64_accepts_exact_limit() {
        let exact = "A".repeat(MAX_BASE64_HINT_LEN);
        let got = normalize_optional_base64(Some(&exact), "base64").expect("exact");
        let expected = format!("data:image/jpeg;base64,{exact}");
        assert_eq!(got.as_deref(), Some(expected.as_str()));
    }
}
