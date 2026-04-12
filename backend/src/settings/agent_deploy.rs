//! 代理部署模块：遗留 `/api/setting/agentDeploy/*`。
//!
//! SQLite `o_agentDeploy` + 提供商连接；本地密钥写入。
//! SaaS 保留来自 `initDB` 的四个静态行，但将每个用户的模型选择持久化到 `app_user_profile.agent_deploy_config`。
//! 密钥仍不通过 HTTP 传输；`set-key` 是显式的无操作成功，以便客户端可以停止将其视为损坏的端点。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Router,
};
use serde::{Deserialize, Serialize};
use sqlx::types::Json as SqlxJson;
use std::collections::HashMap;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct AgentDeployListBody {}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentDeployListItem {
    id: i32,
    model: String,
    key: String,
    model_name: String,
    vendor_id: Option<String>,
    desc: String,
    name: String,
    disabled: bool,
    /// SQLite join **`o_vendorConfig.icon`**; stub empty.
    icon: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct AgentDeployConfigItem {
    model: String,
    model_name: String,
    #[serde(default)]
    vendor_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct AgentDeployConfig {
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    rows: HashMap<String, AgentDeployConfigItem>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentDeploySavedResponse {
    key: String,
    message: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentDeployKeyIgnoredResponse {
    message: &'static str,
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

fn static_agent_deploy_item_by_id(id: i32) -> Option<AgentDeployListItem> {
    static_agent_deploy_list()
        .into_iter()
        .find(|item| item.id == id)
}

async fn load_agent_deploy_config(
    pool: &sqlx::PgPool,
    uid: Uuid,
) -> Result<AgentDeployConfig, ApiError> {
    let row: Option<SqlxJson<AgentDeployConfig>> = sqlx::query_scalar(
        r#"
        SELECT agent_deploy_config FROM app_user_profile WHERE user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row.map(|j| j.0).unwrap_or_default())
}

async fn save_agent_deploy_config(
    pool: &sqlx::PgPool,
    uid: Uuid,
    cfg: &AgentDeployConfig,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, agent_deploy_config, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET agent_deploy_config = EXCLUDED.agent_deploy_config,
            updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(SqlxJson(cfg))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/agent-deploy/list",
    operation_id = "postSettingsAgentDeployListV1",
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
pub(crate) async fn post_agent_deploy_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<AgentDeployListBody>,
) -> Result<Json<Vec<AgentDeployListItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let mut rows = static_agent_deploy_list();
    if let Some(pool) = state.pool.as_ref() {
        let cfg = load_agent_deploy_config(pool, uid).await?;
        for row in &mut rows {
            if let Some(saved) = cfg.rows.get(&row.key) {
                row.model = saved.model.clone();
                row.model_name = saved.model_name.clone();
                row.vendor_id = saved.vendor_id.clone();
            }
        }
    }
    Ok(Json(rows))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct DeployAgentModelBody {
    id: i32,
    name: String,
    model: String,
    model_name: String,
    #[serde(default)]
    vendor_id: Option<String>,
    desc: String,
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/agent-deploy/deploy-model",
    operation_id = "postSettingsAgentDeployModelV1",
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
pub(crate) async fn post_deploy_agent_model(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeployAgentModelBody>,
) -> Result<Json<AgentDeploySavedResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let item = static_agent_deploy_item_by_id(body.id).ok_or_else(|| {
        ApiError::BadRequest(format!(
            "agent deploy row {} is not a built-in option",
            body.id
        ))
    })?;
    if body.name.trim().is_empty() || body.desc.trim().is_empty() {
        return Err(ApiError::BadRequest(
            "name and desc must be non-empty".into(),
        ));
    }

    let mut cfg = load_agent_deploy_config(pool, uid).await?;
    cfg.rows.insert(
        item.key.clone(),
        AgentDeployConfigItem {
            model: body.model,
            model_name: body.model_name,
            vendor_id: body.vendor_id,
        },
    );
    save_agent_deploy_config(pool, uid, &cfg).await?;
    Ok(Json(AgentDeploySavedResponse {
        key: item.key,
        message: "保存成功",
    }))
}

#[allow(dead_code)] // Deserialize-only; keys are not accepted over HTTP.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct AgentSetKeyBody {
    #[serde(default)]
    key: Option<String>,
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/agent-deploy/set-key",
    operation_id = "postSettingsAgentDeploySetKeyV1",
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
pub(crate) async fn post_agent_set_key(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AgentSetKeyBody>,
) -> Result<Json<AgentDeployKeyIgnoredResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Ok(Json(AgentDeployKeyIgnoredResponse {
        message: "未通过 HTTP 保存密钥；请在服务端环境变量或密钥管理中配置",
    }))
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
