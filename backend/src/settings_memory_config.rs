//! Legacy **`/api/setting/memoryConfig/getMemory`** / **`sureMemory`**: SQLite **`o_setting`** keys for RAG / summary limits and ONNX paths.
//! Rust keeps the same JSON field names (**camelCase**) in an in-memory store (defaults match **`initDB`** seeds); not persisted to Postgres yet.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::get,
    Router,
};
use serde::Serialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
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

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/settings/memory-config",
        get(get_memory_config).post(post_memory_config),
    )
}
