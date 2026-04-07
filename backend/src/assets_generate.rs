//! Legacy **`/api/assetsGenerate/*`**: request bodies match old **`validateFields`** shapes.
//! **`POST …/generate`** / **`POST …/polish-prompt`** enqueue **`app_generation_job`** (**`asset.generate.image`** / **`asset.polish.prompt`**); workers fail fast until pipelines exist. Batch routes stay **501**.

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
    enqueue_generation_job, JobRow, JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_PROMPT,
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

#[allow(dead_code)]
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

#[allow(dead_code)]
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

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchPolishItem {
    assets_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    name: String,
    describe: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchPolishAssetsPromptBody {
    project_id: i32,
    #[serde(default)]
    concurrent_count: Option<i32>,
    items: Vec<BatchPolishItem>,
}

fn not_implemented() -> ApiError {
    ApiError::NotImplemented("batch asset generate and batch polish are not implemented".into())
}

fn asset_type_str(k: &AssetGenKind) -> &'static str {
    match k {
        AssetGenKind::Role => "role",
        AssetGenKind::Scene => "scene",
        AssetGenKind::Tool => "tool",
        AssetGenKind::Storyboard => "storyboard",
    }
}

fn trim_non_empty(s: String, field: &'static str) -> Result<String, ApiError> {
    let t = s.trim();
    if t.is_empty() {
        return Err(ApiError::BadRequest(format!("{field} must be non-empty")));
    }
    Ok(t.to_owned())
}

const MAX_MODEL_LEN: usize = 512;
const MAX_RESOLUTION_LEN: usize = 128;
const MAX_NAME_LEN: usize = 512;
const MAX_PROMPT_LEN: usize = 48_000;
const MAX_BASE64_HINT_LEN: usize = 24_000_000;
const MAX_ASSET_TYPE_LEN: usize = 64;
const MAX_DESCRIBE_LEN: usize = 48_000;

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
    if let Some(ref b64) = body.base64 {
        if b64.len() > MAX_BASE64_HINT_LEN {
            return Err(ApiError::BadRequest(format!(
                "base64 must be at most {MAX_BASE64_HINT_LEN} chars"
            )));
        }
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let _project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;

    let asset_type = asset_type_str(&body.asset_type);
    let payload = json!({
        "source": "assets-generate.generate",
        "project_legacy_id": body.project_id,
        "asset_legacy_id": body.id,
        "model": model,
        "resolution": resolution,
        "asset_type": asset_type,
        "name": name,
        "prompt": prompt,
        "has_base64": body.base64.is_some(),
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
        "project_legacy_id": body.project_id,
        "asset_legacy_id": body.assets_id,
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
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_batch_polish_assets_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchPolishAssetsPromptBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
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
}
