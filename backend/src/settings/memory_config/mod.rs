//! 内存配置模块：遗留 `/api/setting/memoryConfig/getMemory` / `sureMemory`。
//!
//! SQLite `o_setting` 键，用于 RAG / 摘要限制和 ONNX 路径。
//! Rust 将每个用户配置持久化到 `app_user_profile.memory_config`（JSONB），服务器默认值作为回退。
//!
//! `POST …/clear-agent-memories`：遗留 `delAllMemory` 的 SaaS 映射（SQLite 擦除整个 `memories` 表）。
//! Rust 仅清除 `JWT sub` + `projectId` + `agentType` + 可选 `episodesId` 的 `app_agent_memory` —
//! 与 `POST /api/v1/agents/memory/clear` 且 `clearType: all` 的相同行。

use axum::{routing::get, Router};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_get_memory_config, __path_post_clear_agent_memories_type_field_alias,
    __path_post_memory_config,
};
pub(crate) use handlers::{
    get_memory_config, post_clear_agent_memories_type_field_alias, post_memory_config,
};

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
    use super::types::{ClearAgentMemoriesSettingsBody, MemoryConfigSavedResponse};

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
        assert_eq!(b.project_id, Some(1));
        assert!(b.project_uuid.is_none());
        assert_eq!(b.agent_type, "script");
        assert_eq!(b.episodes_id, None);
    }

    #[test]
    fn clear_agent_memories_body_accepts_with_episodes() {
        let b: ClearAgentMemoriesSettingsBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"script","episodesId":5}"#).unwrap();
        assert_eq!(b.project_id, Some(1));
        assert_eq!(b.agent_type, "script");
        assert_eq!(b.episodes_id, Some(5));
    }

    #[test]
    fn clear_agent_memories_body_accepts_project_uuid() {
        use uuid::Uuid;
        let u = Uuid::from_u128(0xabc);
        let b: ClearAgentMemoriesSettingsBody = serde_json::from_str(&format!(
            r#"{{"projectUuid":"{u}","agentType":"scriptAgent"}}"#
        ))
        .unwrap();
        assert_eq!(b.project_uuid, Some(u));
        assert_eq!(b.project_id, None);
    }

    #[test]
    fn memory_config_saved_response_has_expected_message() {
        let resp = MemoryConfigSavedResponse {
            message: "保存设置成功",
        };
        assert_eq!(resp.message, "保存设置成功");
    }
}
