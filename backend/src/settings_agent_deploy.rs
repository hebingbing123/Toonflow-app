//! Legacy **`/api/setting/agentDeploy/*`**: SQLite **`o_agentDeploy`** + vendor join; local key writes.
//! SaaS: **POST …/list** returns the same **default rows** as **`initDB`** (no DB); **deploy-model** / **set-key** respond **501** (no persistence / no API keys over HTTP).

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::Response,
    routing::post,
    Router,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct AgentDeployListBody {}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AgentDeployListItem {
    id: i32,
    model: String,
    key: String,
    model_name: String,
    vendor_id: Option<String>,
    desc: String,
    name: String,
    disabled: bool,
    /// Legacy join **`o_vendorConfig.icon`**; stub empty.
    icon: String,
}

fn static_agent_deploy_list() -> Vec<AgentDeployListItem> {
    vec![
        AgentDeployListItem {
            id: 1,
            model: String::new(),
            key: "scriptAgent".into(),
            model_name: String::new(),
            vendor_id: None,
            name: "剧本Agent".into(),
            desc: "用于读取原文生成故事骨架、改编策略，建议使用具备强大文本理解和生成能力的模型".into(),
            disabled: false,
            icon: String::new(),
        },
        AgentDeployListItem {
            id: 2,
            model: String::new(),
            key: "productionAgent".into(),
            model_name: String::new(),
            vendor_id: None,
            name: "生产Agent".into(),
            desc: "对工作流进行调度和管理，建议使用具备较强的逻辑推理和任务管理能力的模型".into(),
            disabled: false,
            icon: String::new(),
        },
        AgentDeployListItem {
            id: 3,
            model: String::new(),
            key: "universalAi".into(),
            model_name: String::new(),
            vendor_id: None,
            name: "通用AI".into(),
            desc: "用于小说事件提取、资产提示词生成、台词提取等边缘功能，建议使用具备较强文本处理能力的模型".into(),
            disabled: false,
            icon: String::new(),
        },
        AgentDeployListItem {
            id: 4,
            model: String::new(),
            key: "ttsDubbing".into(),
            model_name: String::new(),
            vendor_id: None,
            name: "TTS配音".into(),
            desc: "根据剧本内容生成角色配音，支持多种声音风格和情绪".into(),
            disabled: true,
            icon: String::new(),
        },
    ]
}

async fn post_agent_deploy_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<AgentDeployListBody>,
) -> Result<Json<Vec<AgentDeployListItem>>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(static_agent_deploy_list()))
}

#[allow(dead_code)] // Deserialize-only until agent deploy persistence exists.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DeployAgentModelBody {
    id: i32,
    name: String,
    model: String,
    model_name: String,
    #[serde(default)]
    vendor_id: Option<String>,
    desc: String,
}

async fn post_deploy_agent_model(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeployAgentModelBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(ApiError::NotImplemented(
        "persisting agent deploy rows is not implemented; use server LLM env and Harness".into(),
    ))
}

#[allow(dead_code)] // Deserialize-only; keys are not accepted over HTTP.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AgentSetKeyBody {
    #[serde(default)]
    key: Option<String>,
}

async fn post_agent_set_key(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AgentSetKeyBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(ApiError::NotImplemented(
        "setting vendor API keys over HTTP is not supported; configure OPENAI_API_KEY / LLM keys on the server"
            .into(),
    ))
}

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
    use super::*;

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
}
