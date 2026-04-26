//! 代理每项目记忆（`app_agent_memory`）。
//!
//! 与遗留 SQLite memories + HTTP `/api/agents/getMemory` / `/api/agents/clearMemory` 兼容。

mod handlers;
mod storage;
mod summarize;
mod types;

use axum::{routing::post, Router};

use crate::state::AppState;

pub(crate) use handlers::{
    __path_append_memory, __path_clear_memory, __path_query_memory, append_memory, clear_memory,
    query_memory,
};
pub(crate) use storage::{delete_all_agent_memory_rows, ensure_project_owned, parse_agent_type};
pub(crate) use types::ClearMemoryResponse;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/agents/memory/query", post(query_memory))
        .route("/api/v1/agents/memory/clear", post(clear_memory))
        .route("/api/v1/agents/memory/append", post(append_memory))
}

#[cfg(test)]
mod tests {
    use super::types::{ClearMemoryBody, QueryMemoryBody};

    #[test]
    fn query_body_accepts_camel_case() {
        let b: QueryMemoryBody = serde_json::from_str(
            r#"{"projectId":1,"agentType":"scriptAgent","episodesId":2,"memoryType":"summary"}"#,
        )
        .unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.agent_type, "scriptAgent");
        assert_eq!(b.episodes_id, Some(2));
        assert_eq!(b.memory_type, "summary");
    }

    #[test]
    fn query_defaults_to_message_memory_type() {
        let b: QueryMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"scriptAgent"}"#).unwrap();
        assert_eq!(b.memory_type, "message");
    }

    #[test]
    fn clear_defaults_to_all() {
        let b: ClearMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"productionAgent"}"#).unwrap();
        assert_eq!(b.clear_type, "all");
    }

    #[test]
    fn clear_accepts_type_field_alias() {
        let b: ClearMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"scriptAgent","type":"message"}"#)
                .unwrap();
        assert_eq!(b.clear_type, "message");
    }
}
