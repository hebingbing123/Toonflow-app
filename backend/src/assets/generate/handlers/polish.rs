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
    JOB_KIND_ASSET_POLISH_PROMPT,
};
use crate::state::AppState;

use super::super::common::{
    ensure_asset_numerics_exist_in_owned_project, resolve_owned_project_uuid, trim_non_empty,
    MAX_ASSET_TYPE_LEN, MAX_DESCRIBE_LEN, MAX_NAME_LEN,
};
use super::super::types::PolishAssetsPromptBody;

pub(crate) async fn post_polish_assets_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PolishAssetsPromptBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(body.project_id, "projectId")?;
    validate_positive(body.assets_id, "assetsId")?;
    let asset_type = trim_non_empty(body.asset_type, "type")?;
    let name = trim_non_empty(body.name, "name")?;
    let describe = trim_non_empty(body.describe, "describe")?;
    validate_max_length(&asset_type, MAX_ASSET_TYPE_LEN, "type")?;
    validate_max_length(&name, MAX_NAME_LEN, "name")?;
    validate_max_length(&describe, MAX_DESCRIBE_LEN, "describe")?;

    let pool = state.require_pool()?;

    let project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;
    ensure_asset_numerics_exist_in_owned_project(
        pool,
        uid,
        project_uuid,
        std::slice::from_ref(&body.assets_id),
    )
    .await?;

    let payload = json!({
        "payload_schema_version": ASSETS_GENERATE_PAYLOAD_SCHEMA_VERSION_V2,
        "project_uuid": project_uuid,
        "source": "assets-generate.polish-prompt",
        "project_numeric_id": body.project_id,
        "asset_numeric_id": body.assets_id,
        "asset_type": asset_type,
        "name": name,
        "describe": describe,
    });

    let row = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_ASSET_POLISH_PROMPT,
        payload,
        Some(&headers),
        &state.billing_config,
    )
    .await?;
    Ok(JsonResponse(row))
}
