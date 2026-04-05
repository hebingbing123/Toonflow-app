//! Legacy **`/api/scriptAgent/*`**: SQLite **`o_agentWorkData`** + **`o_script`** sync.
//! SaaS: request bodies match old **`validateFields`** shapes; handlers return **501** until Postgres persistence exists (live flows use Harness WS).

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::Response,
    routing::post,
    Router,
};
use serde::Deserialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
enum ScriptAgentKind {
    #[serde(rename = "scriptAgent")]
    ScriptAgent,
}

#[allow(dead_code)] // Deserialize-only until `app_script_agent_plan` (or equivalent) exists.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetScriptAgentPlanBody {
    project_id: i32,
    agent_type: ScriptAgentKind,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SetPlanScriptRow {
    name: String,
    content: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SetScriptAgentPlanData {
    story_skeleton: String,
    adaptation_strategy: String,
    #[serde(default)]
    script: Vec<SetPlanScriptRow>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SetScriptAgentPlanBody {
    project_id: i32,
    agent_type: ScriptAgentKind,
    data: SetScriptAgentPlanData,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateScriptRow {
    id: i32,
    content: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateScriptAgentDataPayload {
    story_skeleton: String,
    adaptation_strategy: String,
    script: Vec<UpdateScriptRow>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateScriptAgentDataBody {
    id: i32,
    data: UpdateScriptAgentDataPayload,
}

fn not_implemented() -> ApiError {
    ApiError::NotImplemented(
        "script agent plan persistence is not implemented; use Harness WS for live agent flows"
            .into(),
    )
}

async fn post_get_plan_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetScriptAgentPlanBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_set_plan_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SetScriptAgentPlanBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_update_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateScriptAgentDataBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/script-agent/get-plan-data",
            post(post_get_plan_data),
        )
        .route(
            "/api/v1/script-agent/set-plan-data",
            post(post_set_plan_data),
        )
        .route("/api/v1/script-agent/update-data", post(post_update_data))
}
