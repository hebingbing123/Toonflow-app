use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::json;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{
    enqueue_generation_job, JobRow, JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_POLISH_BATCH,
};
use crate::state::AppState;

use super::super::common::{
    asset_type_str, ensure_asset_numerics_exist_in_owned_project,
    ensure_batch_asset_items_linked_to_script, normalize_optional_base64,
    resolve_owned_project_uuid, trim_non_empty, trim_non_empty_str, MAX_ASSET_TYPE_LEN,
    MAX_BATCH_ITEMS, MAX_CONCURRENT_COUNT, MAX_DESCRIBE_LEN, MAX_MODEL_LEN, MAX_NAME_LEN,
    MAX_PROMPT_LEN, MAX_RESOLUTION_LEN,
};
use super::super::types::{BatchGenerateImageAssetsBody, BatchPolishAssetsPromptBody};

pub(crate) async fn post_batch_generate_image_assets(
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

    let pool = state.require_pool()?;

    let project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;

    if let Some(script_numeric_id) = body.script_id {
        if script_numeric_id <= 0 {
            return Err(ApiError::BadRequest(
                "scriptId must be positive when provided".into(),
            ));
        }
        let asset_ids: Vec<i32> = body.items.iter().map(|it| it.id).collect();
        ensure_batch_asset_items_linked_to_script(
            pool,
            uid,
            body.project_id,
            script_numeric_id,
            &asset_ids,
        )
        .await?;
    } else {
        let asset_ids: Vec<i32> = body.items.iter().map(|it| it.id).collect();
        ensure_asset_numerics_exist_in_owned_project(pool, uid, project_uuid, &asset_ids).await?;
    }

    let mut payload = json!({
        "source": "assets-generate.batch-generate",
        "project_numeric_id": body.project_id,
        "model": model,
        "resolution": resolution,
        "concurrent_count": body.concurrent_count,
        "items": items_json,
    });
    if let Some(sid) = body.script_id {
        payload["script_id"] = json!(sid);
    }

    let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_BATCH, payload).await?;
    Ok(JsonResponse(row))
}

pub(crate) async fn post_batch_polish_assets_prompt(
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

    let pool = state.require_pool()?;

    let project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;
    let polish_ids: Vec<i32> = body.items.iter().map(|it| it.assets_id).collect();
    ensure_asset_numerics_exist_in_owned_project(pool, uid, project_uuid, &polish_ids).await?;

    let payload = json!({
        "source": "assets-generate.batch-polish",
        "project_numeric_id": body.project_id,
        "concurrent_count": body.concurrent_count,
        "items": items_json,
    });

    let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_POLISH_BATCH, payload).await?;
    Ok(JsonResponse(row))
}
