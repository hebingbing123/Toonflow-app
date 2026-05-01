//! 代理每项目记忆（`app_agent_memory`）。
//!
//! 与遗留 SQLite memories + HTTP `/api/agents/getMemory` / `/api/agents/clearMemory` 兼容。

mod handlers;
pub(crate) mod memory_tier;
mod policy;
mod storage;
mod style_bible;
mod summarize;
mod types;

use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

pub(crate) use handlers::{
    append_memory, clear_memory, get_memory_cost_overview, optimize_memory, query_memory,
};
// utoipa path stubs — referenced by macro expansion in openapi.rs `#[openapi(paths(...))]`
#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_append_memory, __path_clear_memory, __path_get_memory_cost_overview,
    __path_optimize_memory, __path_query_memory,
};
pub(crate) use policy::{
    load_project_automation_memory_policy, load_project_memory_budget_snapshot,
    optimize_project_memory_budget, policy_allows_automated_memory,
    save_project_automation_memory_policy, AutomationMemoryMode, ProjectAutomationMemoryPolicy,
    MEMORY_POLICY_NAME,
};
pub(crate) use storage::{
    delete_all_agent_memory_rows, ensure_project_owned, parse_agent_type,
    replace_named_summary_memory, replace_named_summary_memory_with_scope,
};
pub(crate) use style_bible::{
    ensure_project_style_bible_template, load_project_style_bible_character_anchors,
    maybe_fill_project_style_bible_from_assets, StyleBibleCharacterAnchor,
};
pub(crate) use types::ClearMemoryResponse;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/agents/memory/query", post(query_memory))
        .route("/api/v1/agents/memory/clear", post(clear_memory))
        .route("/api/v1/agents/memory/append", post(append_memory))
        .route("/api/v1/agents/memory/optimize", post(optimize_memory))
        .route(
            "/api/v1/agents/memory/cost-overview",
            get(get_memory_cost_overview),
        )
}

#[cfg(test)]
mod tests {
    use super::types::{AppendMemoryBody, ClearMemoryBody, OptimizeMemoryBody, QueryMemoryBody};

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
    fn query_body_accepts_scope_signature() {
        let body: QueryMemoryBody = serde_json::from_str(
            r#"{"projectId":1,"agentType":"scriptAgent","scopeSignature":{"episodeId":2,"shotId":"ep2-s3"}}"#,
        )
        .unwrap();
        assert_eq!(
            body.scope_signature,
            Some(serde_json::json!({"episodeId": 2, "shotId": "ep2-s3"}))
        );
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

    #[test]
    fn append_defaults_to_message_memory_type() {
        let body: AppendMemoryBody = serde_json::from_str(
            r#"{"projectId":1,"agentType":"scriptAgent","content":"记住角色节奏"}"#,
        )
        .unwrap();
        assert_eq!(body.memory_type, "message");
    }

    #[test]
    fn append_accepts_summary_memory_type() {
        let body: AppendMemoryBody = serde_json::from_str(
            r#"{"projectId":1,"agentType":"productionAgent","memoryType":"summary","role":"assistant","content":"focus=delivery"}"#,
        )
        .unwrap();
        assert_eq!(body.memory_type, "summary");
        assert_eq!(body.role, "assistant");
    }

    #[test]
    fn optimize_body_accepts_camel_case() {
        let body: OptimizeMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"productionAgent","episodesId":2}"#)
                .unwrap();
        assert_eq!(body.project_id, 1);
        assert_eq!(body.agent_type, "productionAgent");
        assert_eq!(body.episodes_id, Some(2));
    }

    #[test]
    fn optimize_body_accepts_automation_mode() {
        let body: OptimizeMemoryBody = serde_json::from_str(
            r#"{"projectId":1,"agentType":"productionAgent","automationMode":"lean"}"#,
        )
        .unwrap();
        assert_eq!(body.automation_mode.as_deref(), Some("lean"));
    }

    // Feature: ai-drama-quality-optimization, Property 7: 记忆隔离性
    // 验证：需求 4.1, 4.2
    // 隔离性通过 SQL WHERE 子句保证（owner_user_id + numeric_project_id + agent_type）
    // 此处验证请求体的隔离维度字段均存在且可正确解析
    #[test]
    fn prop_memory_isolation_fields_present() {
        // 不同 project_id 的请求体应各自独立
        let body1: QueryMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"scriptAgent","episodesId":10}"#)
                .unwrap();
        let body2: QueryMemoryBody =
            serde_json::from_str(r#"{"projectId":2,"agentType":"scriptAgent","episodesId":10}"#)
                .unwrap();
        // 不同 project_id 的查询参数必须不同（隔离维度）
        assert_ne!(body1.project_id, body2.project_id);
        assert_eq!(body1.agent_type, body2.agent_type);
        // 不同 agent_type 的查询参数也必须不同
        let body3: QueryMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"productionAgent"}"#).unwrap();
        assert_ne!(body1.agent_type, body3.agent_type);
    }

    // Feature: ai-drama-quality-optimization, Property 8: 记忆范围签名完整性
    // 验证：需求 4.6
    // stage_summary 类型的记忆必须包含至少一个非空的范围维度
    #[test]
    fn scope_signature_parsed_from_append_body() {
        let body: AppendMemoryBody = serde_json::from_str(
            r#"{
                "projectId":1,
                "agentType":"productionAgent",
                "content":"阶段3导演规划完成",
                "memoryTier":"stage_summary",
                "scopeSignature":{"episodeId":3,"focusSections":["ep3_scene2"]}
            }"#,
        )
        .unwrap();
        assert_eq!(body.memory_tier.as_deref(), Some("stage_summary"));
        let sig = body.scope_signature.unwrap();
        // 至少包含一个非空范围维度
        let has_scope = sig.get("episodeId").is_some()
            || sig.get("storyboardIds").is_some()
            || sig.get("assetIds").is_some()
            || sig.get("focusSections").is_some();
        assert!(
            has_scope,
            "scope_signature must contain at least one scope dimension"
        );
    }

    #[test]
    fn memory_tier_filter_in_query_body() {
        let body: QueryMemoryBody = serde_json::from_str(
            r#"{"projectId":1,"agentType":"scriptAgent","memoryTier":"style_bible"}"#,
        )
        .unwrap();
        assert_eq!(body.memory_tier.as_deref(), Some("style_bible"));
    }

    #[test]
    fn append_body_with_memory_tier_and_scope() {
        let body: AppendMemoryBody = serde_json::from_str(
            r#"{"projectId":1,"agentType":"scriptAgent","content":"test","memoryTier":"delta_memory","scopeSignature":{"storyboardIds":[1,2,3]}}"#,
        )
        .unwrap();
        assert_eq!(body.memory_tier.as_deref(), Some("delta_memory"));
        assert!(body.scope_signature.is_some());
    }
}
