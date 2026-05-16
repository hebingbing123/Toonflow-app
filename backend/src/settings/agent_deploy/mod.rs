//! 代理部署模块：遗留 `/api/setting/agentDeploy/*`。
//!
//! SQLite `o_agentDeploy` + 提供商连接；本地密钥写入。
//! SaaS 保留来自 `initDB` 的四个静态行，但将每个用户的模型选择持久化到 `app_user_profile.agent_deploy_config`。
//! 密钥仍不通过 HTTP 传输；`set-key` 是显式的无操作成功，以便客户端可以停止将其视为损坏的端点。

use axum::{routing::post, Router};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_post_agent_deploy_list, __path_post_agent_set_key, __path_post_deploy_agent_model,
};
pub(crate) use handlers::{post_agent_deploy_list, post_agent_set_key, post_deploy_agent_model};
pub(crate) use storage::load_agent_deploy_config;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/agent-deploy/list",
            post(post_agent_deploy_list),
        )
        .route(
            "/api/v1/settings/agent-deploy/deploy-model",
            post(post_deploy_agent_model),
        )
        .route(
            "/api/v1/settings/agent-deploy/set-key",
            post(post_agent_set_key),
        )
}

#[cfg(test)]
mod tests {
    use super::storage::{static_agent_deploy_item_by_id, static_agent_deploy_list};
    use super::types::{
        AgentDeployConfig, AgentDeployConfigItem, AgentDeployListBody, AgentDeployListItem,
        AgentSetKeyBody, DeployAgentModelBody,
    };

    #[test]
    fn agent_deploy_list_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<AgentDeployListBody>(r#"{"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn agent_deploy_list_body_accepts_empty() {
        let b: AgentDeployListBody = serde_json::from_str(r#"{}"#).unwrap();
        let _ = b;
    }

    #[test]
    fn deploy_agent_model_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<DeployAgentModelBody>(
            r#"{"id":1,"name":"Test","model":"m","modelName":"mn","desc":"d","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn deploy_agent_model_body_accepts_valid() {
        let b: DeployAgentModelBody = serde_json::from_str(
            r#"{"id":1,"name":"Script Agent","model":"gpt-4","modelName":"GPT-4","desc":"Test desc"}"#,
        )
        .unwrap();
        assert_eq!(b.id, 1);
        assert_eq!(b.name, "Script Agent");
        assert_eq!(b.model, "gpt-4");
        assert_eq!(b.vendor_id, None);
    }

    #[test]
    fn deploy_agent_model_body_accepts_with_vendor() {
        let b: DeployAgentModelBody = serde_json::from_str(
            r#"{"id":2,"name":"Prod Agent","model":"gpt-4","modelName":"GPT-4","vendorId":"openai","desc":"Production"}"#,
        )
        .unwrap();
        assert_eq!(b.id, 2);
        assert_eq!(b.vendor_id, Some("openai".to_string()));
    }

    #[test]
    fn agent_set_key_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<AgentSetKeyBody>(r#"{"key":"secret","extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn agent_set_key_body_accepts_key() {
        let b: AgentSetKeyBody = serde_json::from_str(r#"{"key":"my-api-key"}"#).unwrap();
        assert_eq!(b.key, Some("my-api-key".to_string()));
    }

    #[test]
    fn agent_set_key_body_accepts_null_key() {
        let b: AgentSetKeyBody = serde_json::from_str(r#"{"key":null}"#).unwrap();
        assert_eq!(b.key, None);
    }

    #[test]
    fn agent_set_key_body_accepts_empty() {
        let b: AgentSetKeyBody = serde_json::from_str(r#"{}"#).unwrap();
        assert_eq!(b.key, None);
    }

    #[test]
    fn static_agent_deploy_list_has_4_items() {
        let list = static_agent_deploy_list();
        assert_eq!(list.len(), 4);
    }

    #[test]
    fn static_agent_deploy_list_has_expected_keys() {
        let list = static_agent_deploy_list();
        let keys: Vec<&str> = list.iter().map(|i| i.key.as_str()).collect();
        assert!(keys.contains(&"scriptAgent"));
        assert!(keys.contains(&"productionAgent"));
        assert!(keys.contains(&"universalAi"));
        assert!(keys.contains(&"ttsDubbing"));
    }

    #[test]
    fn static_agent_deploy_list_tts_is_disabled() {
        let list = static_agent_deploy_list();
        let tts = list.iter().find(|i| i.key == "ttsDubbing").unwrap();
        assert!(tts.disabled);
    }

    #[test]
    fn static_agent_deploy_item_by_id_matches_key() {
        let item = static_agent_deploy_item_by_id(1).expect("row 1");
        assert_eq!(item.key, "scriptAgent");
    }

    #[test]
    fn agent_deploy_list_item_serialize() {
        let item = AgentDeployListItem {
            id: 1,
            model: "gpt-4".to_string(),
            key: "scriptAgent".to_string(),
            model_name: "GPT-4".to_string(),
            vendor_id: Some("openai".to_string()),
            desc: "Test".to_string(),
            name: "Script Agent".to_string(),
            disabled: false,
            icon: "icon.png".to_string(),
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"id\":1"));
        assert!(json.contains("\"key\":\"scriptAgent\""));
        assert!(json.contains("\"name\":\"Script Agent\""));
        assert!(json.contains("\"disabled\":false"));
    }

    #[test]
    fn agent_deploy_config_roundtrip_serialize() {
        let mut cfg = AgentDeployConfig::default();
        cfg.rows.insert(
            "scriptAgent".into(),
            AgentDeployConfigItem {
                model: "gpt-4.1".into(),
                model_name: "GPT-4.1".into(),
                vendor_id: Some("openai".into()),
            },
        );
        let v = serde_json::to_value(&cfg).unwrap();
        assert_eq!(v["rows"]["scriptAgent"]["model"], "gpt-4.1");
        assert_eq!(v["rows"]["scriptAgent"]["vendorId"], "openai");
    }
}
