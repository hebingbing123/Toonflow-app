use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::json;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_ASSET_POLISH_PROMPT};
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
