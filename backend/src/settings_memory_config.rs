//! Legacy **`/api/setting/memoryConfig/getMemory`** / **`sureMemory`**: SQLite **`o_setting`** keys for RAG / summary limits and ONNX paths.
//! Rust keeps the same JSON field names (**camelCase**) in an in-memory store (defaults match **`initDB`** seeds); not persisted to Postgres yet.
//!
//! **`POST …/clear-agent-memories`**: SaaS mapping for legacy **`delAllMemory`** (SQLite wiped the whole **`memories`** table). Rust clears **`app_agent_memory`**
//! for **`JWT sub` + `projectId` + `agentType` + optional `episodesId`** only — same rows as **`POST /api/v1/agents/memory/clear`** with **`clearType: all`**.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::get,
    Router,
};
use serde::{Deserialize, Serialize};

use crate::agent_memory::{self, ClearMemoryResponse};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::state::{AppState, MemoryConfig};

#[derive(Debug, Serialize)]
struct MemoryConfigSavedResponse {
    /// Legacy **`sureMemory`** success message string.
    message: &'static str,
}

async fn get_memory_config(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MemoryConfig>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let cfg = state.memory_config.read().await;
    Ok(Json(cfg.clone()))
}

async fn post_memory_config(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<MemoryConfig>,
) -> Result<Json<MemoryConfigSavedResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let mut cfg = state.memory_config.write().await;
    *cfg = body;
    Ok(Json(MemoryConfigSavedResponse {
        message: "保存设置成功",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ClearAgentMemoriesSettingsBody {
    project_id: i32,
    agent_type: String,
    #[serde(default)]
    episodes_id: Option<i32>,
}

async fn post_clear_agent_memories_legacy(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ClearAgentMemoriesSettingsBody>,
) -> Result<Json<ClearMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let agent_type = agent_memory::parse_agent_type(&body.agent_type)?;
    agent_memory::ensure_project_owned(pool, uid, body.project_id).await?;
    observe::memory_http(uid, body.project_id, "clear");
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    agent_memory::delete_all_agent_memory_rows(
        &mut tx,
        uid,
        body.project_id,
        agent_type,
        body.episodes_id,
    )
    .await?;
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(ClearMemoryResponse { ok: true }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/memory-config",
            get(get_memory_config).post(post_memory_config),
        )
        .route(
            "/api/v1/settings/memory-config/clear-agent-memories",
            axum::routing::post(post_clear_agent_memories_legacy),
        )
}
