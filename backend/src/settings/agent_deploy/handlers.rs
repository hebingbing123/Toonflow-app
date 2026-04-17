use axum::{
    extract::{Json, State},
    http::HeaderMap,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::storage::{
    insert_config_item, load_agent_deploy_config, save_agent_deploy_config,
    static_agent_deploy_item_by_id, static_agent_deploy_list,
};
use super::types::{
    AgentDeployKeyIgnoredResponse, AgentDeployListBody, AgentDeployListItem,
    AgentDeploySavedResponse, AgentSetKeyBody, DeployAgentModelBody,
};

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
    let pool = state.require_pool()?;
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
    insert_config_item(
        &mut cfg,
        item.key.clone(),
        body.model,
        body.model_name,
        body.vendor_id,
    );
    save_agent_deploy_config(pool, uid, &cfg).await?;
    Ok(Json(AgentDeploySavedResponse {
        key: item.key,
        message: "保存成功",
    }))
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
