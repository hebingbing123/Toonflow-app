//! Legacy **`/api/setting/memoryConfig/getMemory`** / **`sureMemory`**: SQLite **`o_setting`** keys for RAG / summary limits and ONNX paths.
//! Rust persists per-user config in **`app_user_profile.memory_config`** (JSONB) with server defaults as fallback.
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
use sqlx::types::Json as SqlxJson;

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

/// Load per-user memory config from `app_user_profile.memory_config`, or fall back to server defaults.
async fn load_memory_config(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    defaults: MemoryConfig,
) -> Result<MemoryConfig, ApiError> {
    let row: Option<(Option<SqlxJson<MemoryConfig>>,)> =
        sqlx::query_as(r#"SELECT memory_config FROM app_user_profile WHERE id = $1"#)
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row.and_then(|r| r.0).map(|j| j.0).unwrap_or(defaults))
}

/// Persist memory config to `app_user_profile.memory_config` (upsert row if missing).
async fn save_memory_config(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    cfg: &MemoryConfig,
) -> Result<(), ApiError> {
    let cfg_json = SqlxJson(cfg.clone());
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (id, memory_config, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (id) DO UPDATE SET memory_config = EXCLUDED.memory_config, updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(cfg_json)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

async fn get_memory_config(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MemoryConfig>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let defaults = state.memory_config.read().await.clone();
    let cfg = load_memory_config(pool, uid, defaults).await?;
    Ok(Json(cfg))
}

async fn post_memory_config(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<MemoryConfig>,
) -> Result<Json<MemoryConfigSavedResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    save_memory_config(pool, uid, &body).await?;
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
