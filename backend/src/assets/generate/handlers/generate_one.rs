use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::json;

use crate::auth::require_user_uuid;
use crate::error::{validate_max_length, validate_positive, ApiError};
use crate::jobs::{
    enqueue_generation_job, payload_project::ASSETS_GENERATE_PAYLOAD_SCHEMA_VERSION_V2, JobRow,
    JOB_KIND_ASSET_GENERATE_IMAGE,
};
use crate::state::AppState;

use super::super::common::{
    asset_type_str, ensure_asset_numerics_exist_in_owned_project, normalize_optional_base64,
    resolve_owned_project_uuid, trim_non_empty, MAX_MODEL_LEN, MAX_NAME_LEN, MAX_PROMPT_LEN,
    MAX_RESOLUTION_LEN,
};
use super::super::types::GenerateAssetsBody;

pub(crate) async fn post_generate_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateAssetsBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(body.project_id, "projectId")?;
    validate_positive(body.id, "id (asset numeric id)")?;
    let model = trim_non_empty(body.model, "model")?;
    let resolution = trim_non_empty(body.resolution, "resolution")?;
    let name = trim_non_empty(body.name, "name")?;
    let prompt = trim_non_empty(body.prompt, "prompt")?;
    validate_max_length(&model, MAX_MODEL_LEN, "model")?;
    validate_max_length(&resolution, MAX_RESOLUTION_LEN, "resolution")?;
    validate_max_length(&name, MAX_NAME_LEN, "name")?;
    validate_max_length(&prompt, MAX_PROMPT_LEN, "prompt")?;
    let image_base64 = normalize_optional_base64(body.base64.as_deref(), "base64")?;

    let pool = state.require_pool()?;

    let project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;
    ensure_asset_numerics_exist_in_owned_project(
        pool,
        uid,
        project_uuid,
        std::slice::from_ref(&body.id),
    )
    .await?;

    let asset_type = asset_type_str(&body.asset_type);
    let payload = json!({
        "payload_schema_version": ASSETS_GENERATE_PAYLOAD_SCHEMA_VERSION_V2,
        "project_uuid": project_uuid,
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

    let row = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_ASSET_GENERATE_IMAGE,
        payload,
        Some(&headers),
        &state.billing_config,
    )
    .await?;
    Ok(JsonResponse(row))
}
