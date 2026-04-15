//! 内存配置模块：遗留 `/api/setting/memoryConfig/getMemory` / `sureMemory`。
//!
//! SQLite `o_setting` 键，用于 RAG / 摘要限制和 ONNX 路径。
//! Rust 将每个用户配置持久化到 `app_user_profile.memory_config`（JSONB），服务器默认值作为回退。
//!
//! `POST …/clear-agent-memories`：遗留 `delAllMemory` 的 SaaS 映射（SQLite 擦除整个 `memories` 表）。
//! Rust 仅清除 `JWT sub` + `projectId` + `agentType` + 可选 `episodesId` 的 `app_agent_memory` —
//! 与 `POST /api/v1/agents/memory/clear` 且 `clearType: all` 的相同行。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::get,
    Router,
};
use serde::{Deserialize, Serialize};
use sqlx::types::Json as SqlxJson;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::settings::agent_memory::{self, ClearMemoryResponse};
use crate::state::{AppState, MemoryConfig};

#[derive(Debug, Serialize)]
pub(crate) struct MemoryConfigSavedResponse {
    /// Electron-era **`sureMemory`** success message string.
    message: &'static str,
}

/// Load per-user memory config from `app_user_profile.memory_config`, or fall back to server defaults.
async fn load_memory_config(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    defaults: MemoryConfig,
) -> Result<MemoryConfig, ApiError> {
    let row: Option<(Option<SqlxJson<MemoryConfig>>,)> =
        sqlx::query_as(r#"SELECT memory_config FROM app_user_profile WHERE user_id = $1"#)
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
        INSERT INTO app_user_profile (user_id, memory_config, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE SET memory_config = EXCLUDED.memory_config, updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(cfg_json)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

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

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct ClearAgentMemoriesSettingsBody {
    project_id: i32,
    agent_type: String,
    #[serde(default)]
    episodes_id: Option<i32>,
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
    let pool = state.require_pool()?;
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
            axum::routing::post(post_clear_agent_memories_type_field_alias),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clear_agent_memories_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<ClearAgentMemoriesSettingsBody>(
            r#"{"projectId":1,"agentType":"script","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn clear_agent_memories_body_accepts_valid() {
        let b: ClearAgentMemoriesSettingsBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"script"}"#).unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.agent_type, "script");
        assert_eq!(b.episodes_id, None);
    }

    #[test]
    fn clear_agent_memories_body_accepts_with_episodes() {
        let b: ClearAgentMemoriesSettingsBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"script","episodesId":5}"#).unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.agent_type, "script");
        assert_eq!(b.episodes_id, Some(5));
    }

    #[test]
    fn memory_config_saved_response_has_expected_message() {
        let resp = MemoryConfigSavedResponse {
            message: "保存设置成功",
        };
        assert_eq!(resp.message, "保存设置成功");
    }
}
