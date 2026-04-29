use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::production::workbench::video_prompt_memory::optimize_scoped_video_memory;
use crate::state::AppState;

use super::super::storage::{ensure_project_owned, parse_agent_type};
use super::super::types::{OptimizeMemoryBody, OptimizeMemoryResponse};

#[utoipa::path(
    post,
    path = "/api/v1/agents/memory/optimize",
    operation_id = "optimizeAgentMemoryV1",
    tag = "agents",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn optimize_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<OptimizeMemoryBody>,
) -> Result<Json<OptimizeMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let agent_type = parse_agent_type(&body.agent_type)?;
    let script_numeric_id = body.episodes_id.ok_or_else(|| {
        ApiError::BadRequest("episodesId is required for scoped video memory optimization".into())
    })?;
    if agent_type != "productionAgent" {
        return Err(ApiError::BadRequest(
            "optimize currently only supports productionAgent video memory".into(),
        ));
    }
    let pool = state.require_pool()?;

    ensure_project_owned(pool, uid, body.project_id).await?;
    observe::memory_http(uid, body.project_id, "optimize");

    let result =
        optimize_scoped_video_memory(pool, uid, body.project_id, script_numeric_id).await?;
    Ok(Json(OptimizeMemoryResponse {
        removed_rows: result.removed_rows,
        removed_chars: result.removed_chars,
        removed_visual_rows: result.removed_visual_rows,
        removed_duplicate_rows: result.removed_duplicate_rows,
        refreshed_script_summary: result.refreshed_script_summary,
        refreshed_project_summary: result.refreshed_project_summary,
    }))
}
