use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::harness::observe;
use crate::production::optimize_scoped_video_memory;
use crate::state::AppState;

use super::super::types::{AgentMemoryResponseScope, OptimizeMemoryBody, OptimizeMemoryResponse};
use super::super::{
    optimize_project_memory_budget, save_project_automation_memory_policy,
    storage::{parse_agent_type, resolve_agent_memory_project_numeric_id},
    AutomationMemoryMode, ProjectAutomationMemoryPolicy,
};

#[utoipa::path(
    post,
    path = "/api/v1/agents/memory/optimize",
    operation_id = "optimizeAgentMemoryV1",
    tag = "agents",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn optimize_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<OptimizeMemoryBody>,
) -> Result<Json<OptimizeMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let agent_type = parse_agent_type(&body.agent_type)?;
    if body.project_uuid.is_none() && body.project_id.is_none() {
        return Err(bad_request_i18n(
            "Provide projectUuid (preferred) or legacy numeric projectId",
            "请提供 projectUuid（推荐）或旧版数值 projectId",
        ));
    }
    let pool = state.require_pool()?;

    let numeric_project_id =
        resolve_agent_memory_project_numeric_id(pool, uid, body.project_uuid, body.project_id)
            .await?;
    observe::memory_http(uid, numeric_project_id, "optimize");

    let automation_mode = if let Some(raw_mode) = body.automation_mode.as_deref() {
        let mode = AutomationMemoryMode::from_str(raw_mode).ok_or_else(|| {
            bad_request_i18n(
                "automationMode must be one of: off, lean, standard",
                "automationMode 必须是以下之一：off、lean、standard",
            )
        })?;
        save_project_automation_memory_policy(
            pool,
            uid,
            numeric_project_id,
            agent_type,
            &ProjectAutomationMemoryPolicy { mode },
        )
        .await?;
        mode
    } else {
        super::super::load_project_automation_memory_policy(
            pool,
            uid,
            numeric_project_id,
            agent_type,
        )
        .await?
        .mode
    };

    let budget_result =
        optimize_project_memory_budget(pool, uid, numeric_project_id, body.episodes_id, agent_type)
            .await?;
    let scoped_video_result = if agent_type == "productionAgent" {
        if let Some(script_numeric_id) = body.episodes_id {
            Some(
                optimize_scoped_video_memory(pool, uid, numeric_project_id, script_numeric_id)
                    .await?,
            )
        } else {
            None
        }
    } else {
        None
    };
    Ok(Json(OptimizeMemoryResponse {
        scope: AgentMemoryResponseScope::User,
        automation_mode: automation_mode.as_str().to_string(),
        removed_rows: budget_result.removed_rows
            + scoped_video_result
                .as_ref()
                .map(|result| result.removed_rows)
                .unwrap_or(0),
        removed_chars: budget_result.removed_chars
            + scoped_video_result
                .as_ref()
                .map(|result| result.removed_chars)
                .unwrap_or(0),
        removed_visual_rows: scoped_video_result
            .as_ref()
            .map(|result| result.removed_visual_rows)
            .unwrap_or(0),
        removed_duplicate_rows: budget_result.removed_duplicate_rows
            + scoped_video_result
                .as_ref()
                .map(|result| result.removed_duplicate_rows)
                .unwrap_or(0),
        removed_low_value_rows: budget_result.removed_low_value_rows,
        refreshed_script_summary: scoped_video_result
            .as_ref()
            .map(|result| result.refreshed_script_summary)
            .unwrap_or(false),
        refreshed_project_summary: scoped_video_result
            .as_ref()
            .map(|result| result.refreshed_project_summary)
            .unwrap_or(false),
    }))
}
