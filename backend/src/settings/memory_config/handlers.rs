use axum::extract::{Json, State};
use axum::http::HeaderMap;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::settings::agent_memory::{self, ClearMemoryResponse};
use crate::state::{AppState, MemoryConfig};

use super::storage::{load_memory_config, save_memory_config};
use super::types::{ClearAgentMemoriesSettingsBody, MemoryConfigSavedResponse};

#[utoipa::path(
    get,
    path = "/api/v1/settings/memory-config",
    operation_id = "getMemoryConfigV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = crate::state::MemoryConfig),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_memory_config(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MemoryConfig>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let defaults = state.memory_config.read().await.clone();
    let cfg = load_memory_config(pool, uid, defaults).await?;
    Ok(Json(cfg))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/memory-config",
    operation_id = "postMemoryConfigV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_memory_config(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<MemoryConfig>,
) -> Result<Json<MemoryConfigSavedResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    save_memory_config(pool, uid, &body).await?;
    Ok(Json(MemoryConfigSavedResponse {
        message: "保存设置成功",
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/memory-config/clear-agent-memories",
    operation_id = "postSettingsClearAgentMemoriesV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_clear_agent_memories_type_field_alias(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ClearAgentMemoriesSettingsBody>,
) -> Result<Json<ClearMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let agent_type = agent_memory::parse_agent_type(&body.agent_type)?;
    if body.project_uuid.is_none() && body.project_id.is_none() {
        return Err(ApiError::BadRequest(
            "Provide projectUuid (preferred) or legacy numeric projectId".into(),
        ));
    }
    let pool = state.require_pool()?;
    let numeric_project_id = agent_memory::resolve_agent_memory_project_numeric_id(
        pool,
        uid,
        body.project_uuid,
        body.project_id,
    )
    .await?;
    observe::memory_http(uid, numeric_project_id, "clear");
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    agent_memory::delete_all_agent_memory_rows(
        &mut tx,
        uid,
        numeric_project_id,
        agent_type,
        body.episodes_id,
    )
    .await?;
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(ClearMemoryResponse { ok: true }))
}
