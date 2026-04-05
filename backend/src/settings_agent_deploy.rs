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
